const std = @import("std");
const forces = @import("Forces.zig");
const sim = @import("../Sim/sim.zig");

pub const Motion1DOF = struct {
    const Self = @This();
    name: []const u8,
    max_pos: f64,
    min_pos: f64,
    pos: f64 = 0.0,
    vel: f64 = 0.0,
    accel: f64 = 0.0,
    net_force: f64 = 0.0,
    mass: f64 = 1.0,
    connections: []const forces.Force,

    pub fn new_basic(
        name: []const u8,
        max_pos: f64,
        min_pos: f64,
        connections: []const forces.Force,
    ) Motion1DOF {
        var new_motion = Motion1DOF{ .name = name, .max_pos = max_pos, .min_pos = min_pos, .connections = connections };

        // Init connections to ensure two way
        // Errors with this are handled a the connection level in init_connection
        for (connections) |connection| {
            connection.init_connection(&new_motion);
        }

        // Ensure update is in sync
        new_motion.update();

        return new_motion;
    }

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Motion1DOF = self };
    }

    pub fn update(self: *Self) void {

        // Update net force
        for (self.connections) |force| {
            self.net_force += force.*.get_force();
        }

        // Get accel from force and mass
        self.accel = self.net_force / self.mass;
    }

    pub fn save_values(self: Motion1DOF) []const f64 {
        const slice = [5]f64{ self.pos, self.vel, self.accel, self.net_force, self.mass };
        return slice[0..];
    }

    pub fn set_state(self: *Self, integrated_state: []const f64) void {
        if (integrated_state.len != 3) std.debug.panic("ERROR| Attempting to set mismatched state length to [{s}]", .{self.*.name});
        self.vel = integrated_state[1];
        self.pos = integrated_state[2];
    }

    pub fn get_state(self: Motion1DOF) []const f64 {
        const slice = [3]f64{ 0.0, self.accel, self.vel };
        return slice[0..];
    }

    pub fn get_dstate(state: [3]f64) []const f64 {
        const slice = [3]f64{ 0.0, state[0], state[1] };
        return slice[0..];
    }
};
