const std = @import("std");
const sim = @import("../sim.zig");

// Maximum number of state variables an object can have (used to prevent allocations for integration)
pub const MAX_STATE_LEN = 9;

pub const Integration = union(enum) {
    const Self = @This();

    Motion2DOF: *sim.motions.d2.Motion,
    Motion1DOF: *sim.motions.d1.Motion,
    Volume: sim.volumes.Volume,

    pub fn name(self: *const Self) []const u8 {
        return switch (self.*) {
            .Volume => |impl| impl.name(),
            inline else => |m| m.name,
        };
    }

    pub fn get_state(self: *const Self) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            inline else => |m| m.get_state(),
        };
    }

    pub fn get_dstate(self: *const Self, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            inline else => |m| m.get_dstate(state),
        };
    }

    pub fn set_state(self: *const Self, state: [MAX_STATE_LEN]f64) void {
        return switch (self.*) {
            inline else => |m| m.set_state(state),
        };
    }

    pub fn rk4(self: *const Self, dt: f64) !void {

        _ = switch (self.*){
            .Volume => |impl| switch(impl){.Void => return},
            else => null, 
        };

        const intial_state = self.get_state();

        const k1 = self.get_dstate(intial_state);

        var k2 = [1]f64{1e9}**MAX_STATE_LEN; 
        for (intial_state, 0..) |state,i|{
            k2[i] = state + (k1[i] * dt / 2.0);  
        }
        k2 = self.get_dstate(k2);
        
        var k3 = [1]f64{1e9}**MAX_STATE_LEN; 
        for (intial_state, 0..) |state,i|{
            k3[i] = state + (k2[i] * dt / 2.0);  
        }
        k3 = self.get_dstate(k3);

        var k4 = [1]f64{1e9}**MAX_STATE_LEN; 
        for (intial_state, 0..) |state,i|{
            k4[i] = state + (k3[i] * dt);  
        }
        k4 = self.get_dstate(k4);

        var result = [1]f64{1e9}**MAX_STATE_LEN; 
        for (intial_state, 0..) |state, i|{
            result[i] = state + ((dt / 6.0) * (k1[i] + (k2[i] * 2.0) + (k3[i] * 2.0) + k4[i])); 
        }

        self.set_state(result); 
    }

    pub fn euler(self: *const Self, dt: f64) !void {
        var intial_state = self.get_state();

        try std.testing.expect(intial_state.len < MAX_STATE_LEN);

        const dstate = self.get_dstate(intial_state);

        try std.testing.expect(dstate.len == intial_state.len);

        for (intial_state, 0..) |val, i| {
            intial_state[i] = val + (dstate[i] * dt);
        }

        self.set_state(intial_state);
    }

    // =========================================================================
    // SimObject
    // =========================================================================

    pub fn get_header(self: *const Self) []const []const u8 {
        return switch (self.*) {
            .Motion1DOF => return sim.motions.d1.Motion.header[0..],
            .Motion2DOF => return sim.motions.d2.Motion.header[0..],
            .Volume => |impl| return impl.get_header()
        };
    }

    pub fn save_values(self: *const Self, save_array: []f64) void {
        return switch (self.*) {
            inline else => |impl| return impl.save_values(save_array),
        };
    }

    pub fn save_len(self: *const Self) usize {
        return switch (self.*) {
            .Motion1DOF => return sim.motions.d1.Motion.header.len,
            .Motion2DOF => return sim.motions.d2.Motion.header.len,
            .Volume => |impl| return impl.save_len()
        };
    }

    pub fn update(self: *const Self) !void {
        switch (self.*) {
            inline else => |impl| try impl.update(),
        }
    }
};
