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

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        press: f64,
        temp: f64,
        fluid: sim.intrinsic.FluidLookup,
        max_press: f64,
        max_press_step: f64,
        min_press: f64,
        min_press_step: f64,
        mdot_tol: f64,
    ) Self {
        if (press < 0.0) {
            std.log.err("Obect [{s}] press [{d}] is less minimum pressure [{d}]", .{ name, press, 0.0 });
            return sim.errors.InvalidInput;
        }

        if (temp < 0.0) {
            std.log.err("Obect [{s}] temp [{d}] is less min temp [{d}]", .{ name, temp, 0.0 });
            return sim.errors.InvalidInput;
        }

        if (min_press > max_press) {
            std.log.err("Obect [{s}] min press [{d}] is greater max press [{d}]", .{ name, min_press, max_press });
            return sim.errors.InvalidInput;
        }

        if (min_press_step > max_press_step) {
            std.log.err("Obect [{s}] min press frac [{d}] is greater max press [{d}]", .{ name, min_press_step, max_press_step });
            return sim.errors.InvalidInput;
        }

        if (max_press < min_press) {
            std.log.err("Obect [{s}] max press [{d}] is less than min press [{d}]", .{ name, max_press, min_press });
            return sim.errors.InvalidInput;
        }

        if (max_press_step < min_press_step) {
            std.log.err("Obect [{s}] max press step frac [{d}] is less than min press step frac [{d}]", .{ name, max_press_step, min_press_step });
            return sim.errors.InvalidInput;
        }

        if (mdot_tol < 0.0) {
            std.log.err("Obect [{s}] mdot tolerance[{d}] is less [{d}]", .{ name, mdot_tol, 0.0 });
            return sim.errors.InvalidInput;
        }
        return Self{
            .name = name,
            .intrinsic = sim.intrinsic.FluidState.init(fluid, press, temp),
            
        };
    }

    pub fn create(
        allocator: std.mem.Allocator,
        name: []const u8,
        press: f64,
        temp: f64,
        fluid: sim.intrinsic.FluidLookup,
        max_press: f64,
        max_press_step: f64,
        min_press: f64,
        min_press_step: f64,
        mdot_tol: f64,
    ) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = try init(
            allocator,
            name,
            press,
            temp,
            fluid,
            max_press,
            max_press_step,
            min_press,
            min_press_step,
            mdot_tol,
        );
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self {
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "press", contents),
            try sim.parse.field(allocator, f64, Self, "temp", contents),
            try sim.intrinsic.FluidLookup.from_str(try sim.parse.string_field(allocator, Self, "fluid", contents)),

            // 20ksi is unlikley lol (at least in my personal life)
            try sim.parse.optional_field(allocator, f64, Self, "max_press", contents) orelse 1.37895e+8,
            try sim.parse.optional_field(allocator, f64, Self, "max_press_step", contents) orelse 689476,

            try sim.parse.optional_field(allocator, f64, Self, "min_press", contents) orelse 0.1,
            try sim.parse.optional_field(allocator, f64, Self, "min_press_step", contents) orelse 1e-8,

            try sim.parse.optional_field(allocator, f64, Self, "mdot_tol", contents) orelse 1e-6,
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

    pub fn get_residuals(self: *Self, guesses: []f64) ![]f64 {
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

    pub fn get_intial_guess(self: *Self) []f64 {
        self.residuals[0] = self.intrinsic.press;
        return self.residuals[0..];
    }
};
