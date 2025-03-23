const std = @import("std");
const sim = @import("../sim.zig");

pub const Rooter = struct {
    const Self = @This();
    pub const header = [_][]const u8{ "get_val [-]", "set_val [-]", "target_val [-]", "residual [-]" };

    name: []const u8,
    connection_getter: ?*sim.SimObject = null,
    connection_setter: ?*sim.SimObject = null,

    set_field: []const u8,
    set_val: f64,
    get_field: []const u8,
    target_val: f64 = std.math.nan(f64),
    get_val: f64 = std.math.nan(f64),

    perturb: f64,
    maxs: [1]f64,
    mins: [1]f64,
    max_steps: [1]f64,
    min_steps: [1]f64,
    tols: [1]f64,
    residuals: [1]f64 = [1]f64{std.math.nan(f64)},

    pub fn init(name: []const u8, set_field: []const u8, set_val: f64, get_field: []const u8, perturb: f64, max: f64, min: f64, max_step: f64, min_step: f64, tol: f64) Self {
        return Self{
            .name = name,
            .set_field = set_field,
            .set_val = set_val,
            .get_field = get_field,
            .perturb = perturb,
            .maxs = [1]f64{max},
            .mins = [1]f64{min},
            .max_steps = [1]f64{max_step},
            .min_steps = [1]f64{min_step},
            .tols = [1]f64{tol},
        };
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8, set_field: []const u8, set_val: f64, get_field: []const u8, perturb: f64, max: f64, min: f64, max_step: f64, min_step: f64, tol: f64) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = init(name, set_field, set_val, get_field, perturb, max, min, max_step, min_step, tol);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self {
        return create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.string_field(allocator, Self, "set_field", contents),
            try sim.parse.field(allocator, f64, Self, "set_val", contents),
            try sim.parse.string_field(allocator, Self, "get_field", contents),
            try sim.parse.field(allocator, f64, Self, "perturb", contents),
            try sim.parse.field(allocator, f64, Self, "max", contents),
            try sim.parse.field(allocator, f64, Self, "min", contents),
            try sim.parse.field(allocator, f64, Self, "max_step", contents),
            try sim.parse.field(allocator, f64, Self, "min_step", contents),
            try sim.parse.field(allocator, f64, Self, "tol", contents),
        );
    }

    pub fn add_connection_getter(self: *Self, getter: *sim.SimObject) !void {
        if (self.connection_getter) {
            std.log.err("Obj [{s}] already has a connection_getter", .{self.name});
            return sim.errors.AlreadyConnected;
        }
        self.connection_getter = getter;
    }
    pub fn add_connection_setter(self: *Self, setter: *sim.SimObject) !void {
        if (self.connection_setter) {
            std.log.err("Obj [{s}] already has a connection_setter", .{self.name});
            return sim.errors.AlreadyConnected;
        }
        self.connection_setter = setter;
    }

    // =========================================================================
    //  Interfaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Rooter = self };
    }

    pub fn as_steadyable(self: *Self) sim.interfaces.Steadyable {
        return sim.interfaces.Steadyable{ .Rooter = self };
    }

    // =========================================================================
    // Steadyable
    // =========================================================================

    pub fn get_residuals(self: *Self, guesses: []f64) ![]f64 {
        if (self.connection_getter == null) {
            std.log.err("Obj [{s}] does not have a connection_getter", .{self.name});
            return sim.errors.MissingConnection;
        }

        if (self.connection_setter == null) {
            std.log.err("Obj [{s}] does not have a connection_setter", .{self.name});
            return sim.errors.MissingConnection;
        }

        _ = guesses[0];
        // try self.connection_setter.?.set_field(self.set_field, self.set_val);

        self.get_val = try self.connection_getter.?.get_field(self.get_field);

        self.residuals[0] = self.target_val - self.get_val;

        return self.residuals[0];
    }

    pub fn get_intial_guess(self: *Self) []f64 {
        self.residuals[0] = self.set_val;
        return self.residuals[0..];
    }

    // =========================================================================
    //  Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        save_array[0] = self.get_val;
        save_array[1] = self.set_val;
        save_array[2] = self.target_val;
        save_array[3] = self.residuals[0];
    }

    pub fn set_vals(self: *const Self, save_array: []f64) void {
        self.set_val = save_array[1];
        self.target_val = save_array[2];
    }
};
