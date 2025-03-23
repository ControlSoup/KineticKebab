const std = @import("std");
const sim = @import("../../sim.zig");

const MAX_STATE_LEN = sim.interfaces.MAX_STATE_LEN;

pub const Motion = struct {
    const Self = @This();
    const ConnectionType = sim.forces.d1.Force;
    pub const header: [5][]const u8 = [5][]const u8{ "pos [m]", "vel [m/s]", "accel [m/s^2]", "net_force [N]", "mass [kg]" };

    name: []const u8,
    pos: f64,
    vel: f64 = 0.0,
    accel: f64 = 0.0,
    net_force: f64 = 0.0,
    mass: f64,
    connections: std.ArrayList(sim.forces.d1.Force),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, pos: f64, mass: f64) !Self {
        return Self{ .name = name, .pos = pos, .mass = mass, .connections = std.ArrayList(sim.forces.d1.Force).init(allocator) };
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8, pos: f64, mass: f64) !*Motion {
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, name, pos, mass);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Motion {
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "pos", contents),
            try sim.parse.field(allocator, f64, Self, "mass", contents),
        );
    }

    pub fn add_connection(self: *Self, sim_obj: sim.SimObject) !void {
        try self.connections.append(try sim_obj.as_d1force());
        try (try sim_obj.as_d1force()).add_connection(self);
    }

    // =========================================================================
    // Interfaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Motion = self };
    }

    pub fn as_updateable(self: *Self) sim.interfaces.Updatable {
        return sim.interfaces.Updatable{ .Motion = self };
    }

    pub fn as_integratable(self: *Self) sim.interfaces.Integratable {
        return sim.interfaces.Integratable{ .Motion = self };
    }

    // =========================================================================
    // SimObject Methods
    // =========================================================================

    pub fn save_vals(self: *Self, save_array: []f64) void {
        save_array[0] = self.pos;
        save_array[1] = self.vel;
        save_array[2] = self.accel;
        save_array[3] = self.net_force;
        save_array[4] = self.mass;
    }

    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.pos = save_array[0];
        self.vel = save_array[1];
        self.accel = save_array[2];
        self.net_force = save_array[3];
        self.mass = save_array[4];
    }

    // =========================================================================
    // Updateable Methods
    // =========================================================================

    /// Computes the net force and resulting acceleration based on mass
    pub fn update(self: *Self) !void {

        // Update net force
        self.net_force = 0;
        for (self.connections.items) |force| {
            self.net_force += try force.get_force();
        }

        // Get accel from force and mass
        self.accel = self.net_force / self.mass;
    }

    // =========================================================================
    // Integratable Methods
    // =========================================================================

    pub fn set_state(self: *Self, integrated_state: [MAX_STATE_LEN]f64) void {
        self.vel = integrated_state[1];
        self.pos = integrated_state[2];
    }

    pub fn get_state(self: *Self) [MAX_STATE_LEN]f64 {
        return [3]f64{ self.accel, self.vel, self.pos } ++ ([1]f64{0.0} ** 6);
    }

    pub fn get_dstate(self: *Self, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        _ = self;
        return [3]f64{ 0.0, state[0], state[1] } ++ ([1]f64{0.0} ** 6);
    }
};
