const std = @import("std");
const sim = @import("../sim.zig");
const volumes = @import("volumes.zig");

pub const Restriction = union(enum){
    const Self = @This();
    
    Orifice: *Orifice,

    pub fn get_mdot(self: *const Self) !f64{
        switch (self.*){
            inline else => |r| return r.get_mdot(),
        }
    }

    pub fn add_connection_in(
        self: *const Self, 
        volume_obj: sim.volumes.Volume
    ) !void{
        switch (self.*) {
            inline else => |f| {
                if (f.connection_in) |_| {
                    std.log.err("ERROR| Object [{s}] is already connected to [{s}]", .{ f.name, (f.connection_in orelse unreachable).name()});
                    return sim.errors.AlreadyConnected;
                } else {
                    f.*.connection_in = volume_obj;
                }
            }
        }
    }

    pub fn add_connection_out(
        self: *const Self, 
        volume_obj: sim.volumes.Volume
    ) !void{
        switch (self.*) {
            inline else => |f| {
                if (f.connection_out) |_| {
                    std.log.err("ERROR| Object[{s}] is already connected to [{s}]", .{ f.name, (f.connection_out orelse unreachable).name()});
                    return sim.errors.AlreadyConnected;
                } else {
                       f.*.connection_out = volume_obj; 
                }
            }
        }
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn name(self: *const Self) []const u8{
        return switch (self.*){
            inline else => |impl| impl.name,
        };
    }

    pub fn save_values(self: *const Self, save_array: []f64) void{
        switch (self.*){
            inline else => |impl| impl.save_values(save_array),
        }
    }

    pub fn get_header(self: *const Self) []const []const u8{
        return switch (self.*){
            .Orifice => return Orifice.header[0..],
        };
    }

    pub fn save_len(self: *const Self) usize{
        return switch (self.*){
            .Orifice => return Orifice.header.len,
        };
    }
};

pub const MdotMethod = enum{
    const Self = @This();
    IdealCompressible, 

    pub fn from_str(str: []const u8, ) !Self{
        if (std.mem.eql(u8, str, "IdealCompressible")) {
            return .IdealCompressible;
        }else{
            return sim.errors.InvalidInput;
        }
    }
};


pub const Orifice = struct{
    const Self = @This();
    pub const header = [_][]const u8{"cda [m^2]", "mdot [kg/s]", "dp [Pa]", "is_choked [-]"};

    name: []const u8,
    cda: f64,
    mdot_method: MdotMethod,

    mdot: f64 = 0.0,
    dp: f64 = 0.0,
    is_choked: bool = false,
    connection_in: ?volumes.Volume = null,
    connection_out: ?volumes.Volume = null,

    pub fn init(name: []const u8, cda: f64, mdot_method: MdotMethod) Self{
        return Orifice{.name = name, .cda = cda, .mdot_method = mdot_method};
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8, cda: f64, mdot_method: MdotMethod) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = init(name, cda, mdot_method); 
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        return create(
            allocator, 
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "cda", contents),
            try MdotMethod.from_str(
                try sim.parse.string_field(allocator, Self, "mdot_method",  contents)
            )
        );
    }

    pub fn get_mdot(self: *Self) !f64{

        if (self.connection_in == null){
            std.log.err("ERROR| Object[{s}] is missing a connection_in", .{self.name});
            return sim.errors.AlreadyConnected; 
        }

        var state_in = (self.connection_in orelse unreachable).get_intrinsic();

        if (self.connection_out == null){
            std.log.err("ERROR| Object[{s}] is missing a connection_out", .{self.name});
            return sim.errors.AlreadyConnected; 
        }

        var state_out = (self.connection_in orelse unreachable).get_intrinsic();

        self.dp = state_in.press - state_out.press;

        // For the purposes of the calc is dp < 0 flow is reversed
        if (self.dp < 0.0){
            const temp = state_in;
            state_in = state_out;
            state_out = temp;
        }

        self.is_choked = ideal_is_choked(state_in.press, state_out.press, state_in.gamma);

        return switch (self.mdot_method) {
            .IdealCompressible => {
                if (self.is_choked) return ideal_choked_mdot(self.cda, state_in.density, state_in.press, state_in.gamma);
                if (!self.is_choked) return ideal_unchoked_mdot(self.cda, state_in.density, state_in.press, state_out.press, state_in.gamma);
            }
        };
    }

    pub fn save_values(self: *const Self, save_array: []f64) void{
        save_array[0] = self.cda;
        save_array[1] = self.mdot;
        save_array[3] = self.dp;
        save_array[2] = if (self.is_choked) 1.0 else 0.0;
    }

    // =========================================================================
    //  Sim Object Methods
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{.Restriction = Restriction{.Orifice = self}};
    }


};

// =============================================================================
// Orifice plate equations https://en.wikipedia.org/wiki/Orifice_plate 
// =============================================================================

pub fn ideal_is_choked(us_stag_press: f64, ds_stag_press: f64, gamma: f64) bool {
    return ds_stag_press < ((2.0 / gamma + 1.0) ** (gamma / gamma - 1.0)) * us_stag_press;
}

pub fn ideal_unchoked_mdot(cda: f64, us_density: f64, us_press: f64, ds_press: f64, gamma: f64) f64{
    const a = 2 * us_density * us_press;
    const b = gamma / (gamma - 1.0);
    const c = (ds_press / us_press)**(2.0/gamma) - (ds_press/us_press)**((gamma + 1.0) / gamma);
    return cda * @sqrt(a * b * c);
}

pub fn ideal_choked_mdot(cda: f64, us_density: f64, us_press: f64, gamma: f64) f64{
    const a = gamma * us_density * us_press;
    const b = (2.0 / gamma + 1.0)**((gamma + 1)/(gamma - 1));
    return cda * @sqrt(a*b);
}