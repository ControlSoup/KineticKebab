const std = @import("std");
const sim = @import("../sim.zig");
const volumes = @import("volumes.zig");
const equations = @import("equations/equations.zig");

pub const Restriction = union(enum) {
    const Self = @This();

    Orifice: *Orifice,
    ConstantMdot: *ConstantMdot,

    pub fn get_mhdot(self: *const Self) ![2]f64 {
        try self._check_connections();

        return switch (self.*) {
            inline else => |f| f.get_mhdot(),
        };
    }

    pub fn add_connection_in(self: *const Self, volume_obj: sim.volumes.Volume) !void {
        switch (self.*) {
            inline else => |f| {
                if (f.connection_in) |_| {
                    std.log.err("Object [{s}] is already connected", .{f.name});
                    return sim.errors.AlreadyConnected;
                } else {
                    f.*.connection_in = volume_obj;
                }
            },
        }
    }

    pub fn add_connection_out(self: *const Self, volume_obj: sim.volumes.Volume) !void {
        switch (self.*) {
            inline else => |f| {
                if (f.connection_out) |_| {
                    std.log.err("Object[{s}] is already connected", .{f.name});
                    return sim.errors.AlreadyConnected;
                } else {
                    f.*.connection_out = volume_obj;
                }
            },
        }
    }

    pub fn _check_connections(self: *const Self) !void {
        switch (self.*) {
            inline else => |f| {
                if (f.connection_in == null) {
                    std.log.err("Object[{s}] is missing a connection_in", .{f.name});
                    return sim.errors.AlreadyConnected;
                }

                if (f.connection_out == null) {
                    std.log.err("Object[{s}] is missing a connection_out", .{f.name});
                    return sim.errors.AlreadyConnected;
                }
            },
        }
    }
};

pub const MdotMethod = enum {
    const Self = @This();
    IdealIsentropic,
    Incompressible,
    Debug,

    pub fn from_str(
        lookup_str: []const u8,
    ) !Self {
        return std.meta.stringToEnum(Self, lookup_str) orelse {
            std.log.err("Invalid MdotMethod {s}", .{lookup_str});
            return sim.errors.InvalidInput;
        };
    }
};

pub const Orifice = struct {
    const Self = @This();
    pub const header = [_][]const u8{ "cda [m^2]", "mdot [kg/s]", "hdot [J/(kg*s)]", "dp [Pa]", "is_choked [-]" };

    name: []const u8,
    cda: f64,
    mdot_method: MdotMethod,

    mdot: f64 = 0.0,
    hdot: f64 = 0.0,
    dp: f64 = 0.0,
    is_choked: bool = false,
    connection_in: ?volumes.Volume = null,
    connection_out: ?volumes.Volume = null,

    pub fn init(name: []const u8, cda: f64, mdot_method: MdotMethod) Self {
        return Orifice{ .name = name, .cda = cda, .mdot_method = mdot_method };
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8, cda: f64, mdot_method: MdotMethod) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = init(name, cda, mdot_method);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self {
        return create(allocator, try sim.parse.string_field(allocator, Self, "name", contents), try sim.parse.field(allocator, f64, Self, "cda", contents), try MdotMethod.from_str(try sim.parse.string_field(allocator, Self, "mdot_method", contents)));
    }

    // =========================================================================
    //  Intefaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Orifice = self };
    }

    pub fn as_restriction(self: *Self) Restriction {
        return Restriction{ .Orifice = self };
    }

    // =========================================================================
    //  Restriction Methods
    // =========================================================================

    pub fn get_mhdot(self: *Self) ![2]f64 {
        var state_in = self.connection_in.?.get_intrinsic();
        var state_out = self.connection_out.?.get_intrinsic();

        self.dp = state_in.press - state_out.press;

        // If your less than 0.1 Pa common man... its not flowing
        if (@abs(self.dp) <= 0.1) {
            self.mdot = 0.0;
            self.hdot = 0.0;
            return [2]f64{ self.mdot, self.hdot };
        }

        // For the purposes of the calc is dp < 0 flow is reversed
        if (self.dp < 0.0) {
            const temp = state_in;
            state_in = state_out;
            state_out = temp;
        }

        switch (self.mdot_method) {
            .IdealIsentropic => {
                self.is_choked = equations.orifice.ideal_is_choked(state_in.press, state_out.press, state_in.gamma);
                if (self.is_choked) {
                    self.mdot = equations.orifice.ideal_choked_mdot(self.cda, state_in.density, state_in.press, state_in.gamma);
                } else {
                    self.mdot = equations.orifice.ideal_unchoked_mdot(self.cda, state_in.density, state_in.press, state_out.press, state_in.gamma);
                }
            },
            .Incompressible => {
                self.is_choked = false;
                self.mdot = equations.orifice.incompresible_mdot(self.cda, state_in.density, state_in.press, state_out.press);
            },
            .Debug => {
                self.is_choked = false;
                self.mdot = self.dp * self.cda;
            },
        }

        if (self.dp < 0.0) self.mdot *= -1;

        self.hdot = state_in.sp_enthalpy * self.mdot;

        return [2]f64{ self.mdot, self.hdot };
    }

    // =========================================================================
    //  Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        save_array[0] = self.cda;
        save_array[1] = self.mdot;
        save_array[2] = self.hdot;
        save_array[3] = self.dp;
        save_array[4] = if (self.is_choked) 1.0 else 0.0;
    }

    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.cda = save_array[0];
    }
};

pub const ConstantMdot = struct {
    const Self = @This();
    pub const header = [_][]const u8{ "mdot [kg/s]", "hdot [J/(kg*s)]", "dp [Pa]", "is_choked [-]" };

    name: []const u8,
    mdot: f64,

    hdot: f64 = 0.0,
    dp: f64 = 0.0,
    is_choked: bool = false,
    connection_in: ?volumes.Volume = null,
    connection_out: ?volumes.Volume = null,

    pub fn init(name: []const u8, mdot: f64) Self {
        return Self{
            .name = name,
            .mdot = mdot,
        };
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8, mdot: f64) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = init(name, mdot);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self {
        return create(allocator, try sim.parse.string_field(allocator, Self, "name", contents), try sim.parse.field(allocator, f64, Self, "mdot", contents));
    }

    // =========================================================================
    //  Interfaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .ConstantMdot = self };
    }

    pub fn as_restriction(self: *Self) sim.restrictions.Restriction {
        return Restriction{ .ConstantMdot = self };
    }

    // =========================================================================
    //  Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        save_array[0] = self.mdot;
        save_array[1] = self.hdot;
        save_array[2] = self.dp;
        save_array[3] = if (self.is_choked) 1.0 else 0.0;
    }

    pub fn set_vals(self: *const Self, save_array: []f64) void {
        save_array[0] = self.mdot;
    }

    // =========================================================================
    // Restriction Methods
    // =========================================================================

    pub fn get_mhdot(self: *Self) ![2]f64 {
        const state_in = self.connection_in.?.get_intrinsic();
        const state_out = self.connection_out.?.get_intrinsic();

        self.dp = state_in.press - state_out.press;

        self.hdot = self.connection_in.?.get_intrinsic().sp_enthalpy * self.mdot;

        return [2]f64{ self.mdot, self.hdot };
    }
};
