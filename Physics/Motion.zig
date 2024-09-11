const std = @import("std");
const forces = @import("Forces.zig");

pub const Motion1DOF = struct {
    name: []const u8,
    max_pos: f64,
    min_pos: f64,
    pos: f64 = 0.0,
    vel: f64 = 0.0,
    accel: f64 = 0.0,
    net_force: f64 = 0.0,
    mass: f64 = 1.0,
    connections: []const *forces.Force,

    pub fn new_basic(
        name: []const u8,
        max_pos: f64,
        min_pos: f64,
        connections: []const *forces.Force,
    ) Motion1DOF {
        var new_motion = Motion1DOF{ .name = name, .max_pos = max_pos, .min_pos = min_pos, .connections = connections };

        // Init connections to ensure two way
        // Errors with this are handled a the connection level in init_connection
        for (connections) |connection| {
            connection.*.init_connection(&new_motion);
        }

        return new_motion;
    }

    pub fn update(self: *Motion1DOF) void {

        // Update net force
        for (self.connections) |force| {
            self.net_force += force.*.get_force();
        }

        // Get accel from force and mass
        self.accel = self.net_force / self.mass;
    }

    pub fn get_dstate(self: Motion1DOF) [3]f64 {
        return [3]f64{ 0.0, self.accel, self.vel };
    }

    pub fn integrate_state(self: *Motion1DOF, integrated_state: [3]f64) [3]f64 {
        self.vel = integrated_state[1];
        self.pos = integrated_state[2];
    }
};
