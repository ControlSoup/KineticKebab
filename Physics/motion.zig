const std = @import("std");
const forces = @import("forces.zig");
const sim = @import("../Sim/sim.zig");
const solver = @import("../Solvers/solvers.zig");
const MAX_STATE_LEN = solver.MAX_STATE_LEN;

pub const Motion1DOF = struct {
    const Self = @This();

    save_len: usize = 5,
    name: []const u8,
    max_pos: f64,
    min_pos: f64,
    pos: f64 = 0.0,
    vel: f64 = 0.0,
    accel: f64 = 0.0,
    net_force: f64 = 0.0,
    mass: f64 = 1.0,
    connections: std.ArrayList(forces.Force),

    pub fn init_basic(allocator: std.mem.Allocator, name: []const u8, max_pos: f64, min_pos: f64) Motion1DOF {
        return Motion1DOF{ .name = name, .max_pos = max_pos, .min_pos = min_pos, .connections = std.ArrayList(forces.Force).init(allocator) };
    }

    pub fn add_connection(self: *Self, force: forces.Force) !void {
        try self.connections.append(force);
        force.init_connection(self);
        self.update();
    }

    // =========================================================================
    // SimObject Methods
    // =========================================================================

    pub fn deinit(self: *Self) void {
        self.connections.deinit();
    }

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Integration = solver.Integration{ .Motion1DOF = self } };
    }

    pub fn update(self: *Self) void {

        // Update net force
        self.net_force = 0;
        for (self.connections.items) |force| {
            self.net_force += force.get_force();
        }

        // Get accel from force and mass
        self.accel = self.net_force / self.mass;

        if (self.pos > self.max_pos){
            self.pos = self.max_pos;
        }
        if (self.pos < self.min_pos){
            self.pos = self.min_pos;
        }
    }

    pub fn get_header(self: *Self) []const []const u8 {
        _ = self;
        const save = [_][]const u8{ "pos [m]", "vel [m/s]", "accel [m/s^2]", "net_force [N]", "mass [kg]" };
        return save[0..];
    }

    pub fn save_values(self: *Self, save_array: []f64) void {
        if (save_array.len != self.save_len) {
            std.debug.panic("ERROR| Save slice length [{d}] != [{d}] for object [{s}]", .{ save_array.len, self.save_len, self.name });
        }

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
        if (integrated_state.len != 3) {
            std.debug.panic("ERROR| Attempting to set mismatched state length to [{s}]", .{self.*.name});
        }
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

test "Test 1DOF Motion" {
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }
    const alloc = gpa.allocator();

    var test_obj = Motion1DOF.init_basic(alloc, "0", 1.0, 0.0);

    // Simple Test
    var simple_force_0 = forces.Simple{ .name = "0", .force = 1.0 };
    var simple_force_1 = forces.Simple{ .name = "1", .force = 1.0 };
    var simple_force_2 = forces.Simple{ .name = "2", .force = 1.0 };
    var simple_force_3 = forces.Simple{ .name = "3", .force = 1.0 };
    var simple_force_4 = forces.Simple{ .name = "4", .force = 1.0 };
    var simple_force_5 = forces.Simple{ .name = "5", .force = 1.0 };

    try test_obj.add_connection(simple_force_0.as_force());
    try test_obj.add_connection(simple_force_1.as_force());
    try test_obj.add_connection(simple_force_2.as_force());
    try test_obj.add_connection(simple_force_3.as_force());
    try test_obj.add_connection(simple_force_4.as_force());
    try test_obj.add_connection(simple_force_5.as_force());

    // Check intial expectations
    try std.testing.expect(test_obj.net_force == 6.0);
    try std.testing.expect(test_obj.pos == 0);

    test_obj.deinit();
}
