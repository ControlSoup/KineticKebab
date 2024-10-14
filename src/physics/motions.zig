const std = @import("std");
const sim = @import("../sim.zig");

const MAX_STATE_LEN = sim.solvers.MAX_STATE_LEN;

pub const Motion1DOF = struct {
    const Self = @This();
    const ConnectionType = sim.forces.Force;
    pub const header: [5][]const u8 = [5][]const u8{ "pos [m]", "vel [m/s]", "accel [m/s^2]", "net_force [N]", "mass [kg]" };

    name: []const u8,
    max_pos: f64,
    min_pos: f64,
    pos: f64,
    vel: f64 = 0.0,
    accel: f64 = 0.0,
    net_force: f64 = 0.0,
    mass: f64,
    connections: std.ArrayList(sim.forces.Force),

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8, 
        max_pos: f64, 
        min_pos: f64,
        pos: f64,
        mass: f64
    ) !Self{

        if (max_pos < min_pos) {
            std.log.err("ERROR| Object [{s}] max position [{d:0.4}] is less then min position [{d:0.4}]", .{name, max_pos, min_pos});
            return sim.errors.InvalidInput;
        }
        if (min_pos == max_pos) {
            std.log.err("ERROR| Object [{s}]  position [{d:0.4}] is equal to the min position [{d:0.4}]", .{name, max_pos, min_pos});
            return sim.errors.InvalidInput;
        }

        return Self{
            .name = name, 
            .max_pos = max_pos, 
            .min_pos = min_pos, 
            .pos = pos, 
            .mass = mass,
            .connections = std.ArrayList(sim.forces.Force).init(allocator)
        };
    }

    pub fn create(
        allocator: std.mem.Allocator, 
        name: []const u8, 
        max_pos: f64, 
        min_pos: f64,
        pos: f64,
        mass: f64
    ) !*Motion1DOF {
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, name, max_pos, min_pos, pos, mass);
        return ptr;
    }

    pub fn from_json(
        allocator: std.mem.Allocator,
        contents: std.json.Value
    ) !*Motion1DOF{
        return try create(
            allocator, 
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "max_pos", contents),
            try sim.parse.field(allocator, f64, Self, "min_pos", contents),
            try sim.parse.field(allocator, f64, Self, "pos", contents),
            try sim.parse.field(allocator, f64, Self, "mass", contents),
        );
    }

    pub fn add_connection(self: *Self, sim_obj: sim.SimObject) !void {
        try self.connections.append(sim_obj.Force);
        try sim_obj.Force.add_connections(self);
        try self.update();
    }

    // =========================================================================
    // SimObject Methods
    // =========================================================================

    pub fn deinit(self: *Self) void {
        self.connections.deinit();
    }

    /// Creates a sim object interface, that holds a pointer to this object as integratable
    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Integration = sim.solvers.Integration{ .Motion1DOF = self } };
    }

    /// Computes the net force and resulting acceleration based on mass
    pub fn update(self: *Self) !void {

        // Update net force
        self.net_force = 0;
        for (self.connections.items) |force| {
            self.net_force += try force.get_force();
        }

        // Get accel from force and mass
        self.accel = self.net_force / self.mass;

        if (self.pos >= self.max_pos){
            self.pos = self.max_pos;
        }
        if (self.pos <= self.min_pos){
            self.pos = self.min_pos;
        }
    }

    pub fn save_values(self: *Self, save_array: []f64) void {
        save_array[0] = self.pos;
        save_array[1] = self.vel;
        save_array[2] = self.accel;
        save_array[3] = self.net_force;
        save_array[4] = self.mass;
    }

    // =========================================================================
    // Integration Methods
    // =========================================================================

    pub fn set_state(self: *Self, integrated_state: [MAX_STATE_LEN]f64) void {
        self.vel = integrated_state[1];
        self.pos = integrated_state[2];
    }

    pub fn get_state(self: *Self) [MAX_STATE_LEN]f64 {
        return [3]f64{ self.accel, self.vel, self.pos };
    }

    pub fn get_dstate(self: *Self, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        _ = self;
        return [3]f64{ 0.0, state[0], state[1] };
    }
};