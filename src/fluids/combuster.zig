const std = @import("std");
const sim = @import("../sim.zig");


pub const UpwindedCombuster = struct {
    const Self = @This();
    pub const header = [_][]const u8{
        //
        "mr [-]",
        "ox_mdot [kg/s]",
        "fu_mdot [kg/s]",
        "mdot_out [kg/s]",
        "net_mdot [kg/s]",
        "gamma [-]",
        "sp_r [-]",
        "press [Pa]",
        "temp [degK]",
    };

    name: []const u8,

    intrinsic: sim.intrinsic.FluidState,

    ox_mdot_in: f64 = std.math.nan(f64),
    fu_mdot_in: f64 = std.math.nan(f64),
    combustion_mdot_out: f64 = std.math.nan(f64),
    net_mdot: f64 = std.math.nan(f64),

    mr: f64 = std.math.nan(f64),

    connections_ox_in: std.ArrayList(sim.restrictions.Restriction),
    connections_fu_in: std.ArrayList(sim.restrictions.Restriction),
    connections_out: std.ArrayList(sim.restrictions.Restriction),

    pub fn init(name: []const u8) Self {
        return Self{
            .name = name,
        };
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = init(name);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self {
        return create(
            //
            allocator, 
            try sim.parse.string_field(allocator, Self, "name", contents), 
            try sim.parse.field(allocator, f64, Self, "mdot", contents)
        );
    }

    // =========================================================================
    //  Interfaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .ConstantMdot = self };
    }

    pub fn as_volume(self: *Self) sim.volumes.Volume {
        return sim.volumes.Volume{ .Combuster = self };
    }

    pub fn as_steadyable(self: *Self) sim.interfaces.Steadyable {
        return sim.interfaces.Steadyable{ .Combuster = self };
    }

    // =========================================================================
    //  Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        save_array[0] = self.mr;
        save_array[1] = self.ox_mdot_in;
        save_array[2] = self.fu_mdot_in;
        save_array[3] = self.combustion_mdot_out;
        save_array[4] = self.net_mdot;
        save_array[5] = self.gamma;
        save_array[6] = self.sp_r;
        save_array[7] = self.intrinsic.press;
        save_array[8] = self.intrinsic.temp;
    }

    pub fn set_vals(self: *const Self, save_array: []f64) void {
        self.mr = save_array[0];
        self.ox_mdot_in = save_array[1];
        self.fu_mdot_in = save_array[2];
        self.combustion_mdot_out = save_array[3];
        self.net_mdot = save_array[4];
        self.gamma = save_array[5];
        self.sp_r = save_array[6];
        self.intrinsic.press = save_array[7];
        self.intrinsic.temp = save_array[8];
    }

    // =========================================================================
    // Restriction Methods
    // =========================================================================

    pub fn update_props(self: *Self, guesses: []f64) !void {
        self.intrinsic.press = guesses[0];

        self.hdot_in = 0.0;
        self.mdot_in = 0.0;
        self.mdot_out = 0.0;

        for (self.connections_ox_in.items) |ox| {
            const mhdot = try ox.get_mhdot();
            if (mhdot[0] >= 0.0) self.ox_mdot_in += mhdot[0];
        }

        for (self.connections_fu_in.items) |ox| {
            const mhdot = try ox.get_mhdot();
            if (mhdot[0] >= 0.0) self.fu_mdot_in += mhdot[0];
        }

        for (self.combustion_mdot_out) |combust| {
            const mhdot = try combust.get_mhdot();
            if (mhdot[0] >= 0.0) self.combustion_mdot_out += mhdot[0];
        }

        // Continuity Equation (ingoring head and velocity)
        self.net_mdot = self.ox_mdot_in + self.fu_mdot_in - self.combustion_mdot_out;

        self.mr = self.ox_mdot_in / self.fu_mdot_in;


        // Update base props and lookup new properties from new temp
        try self.intrinsic.update_cea(self.intrinsic.press, self.mr);
        self.intrinsic.update_from_pt(self.intrinsic.press, self.intrinsic.temp);

        // Update resisduals and return them as a slice for the jacobian
        self.residuals[0] = self.net_mdot;

        return self.residuals[0..];
    }
};
