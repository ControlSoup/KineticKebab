const std = @import("std");
const motion = @import("../Physics/motion.zig");

// Maximum number of state variables an object can have (used to prevent allocations for integration)
pub const MAX_STATE_LEN = 3;

pub const Integration = union(enum) {
    // TODO: Use Vectors / simd ops???
    const Self = @This();

    Motion1DOF: *motion.Motion1DOF,

    pub fn name(self: *const Self) []const u8 {
        return switch (self.*) {
            inline else => |m| m.name,
        };
    }

    pub fn get_state(self: *const Self) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            inline else => |m| m.get_state(),
        };
    }

    pub fn get_dstate(self: *const Integration, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            inline else => |m| m.get_dstate(state),
        };
    }

    pub fn set_state(self: *const Self, state: [MAX_STATE_LEN]f64) void {
        return switch (self.*) {
            inline else => |m| m.set_state(state),
        };
    }

    pub fn rk4(self: *const Integration, dt: f64) void {

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

    pub fn euler(self: *const Integration, dt: f64) void {
        var state = self.get_state();

        const dstate = self.get_dstate(state);

        if (state.len > MAX_STATE_LEN) {
            std.debug.panic("ERROR| Object [{s}] has state length [{d}] > max state length [{d}]", .{ self.name(), state.len, MAX_STATE_LEN });
        }

        if (dstate.len != state.len) {
            std.debug.panic("ERROR| Object [{s}] state length [{d}] does not match dstate length [{d}]", .{ self.name(), state.len, dstate.len });
        }

        for (state, 0..) |val, i| {
            state[i] = val + (dstate[i] * dt);
        }

        self.set_state(state);
    }

    // =========================================================================
    // SimObject
    // =========================================================================

    pub fn get_header(self: *const Self) []const []const u8 {
        return switch (self.*) {
            inline else => |impl| return impl.get_header(),
        };
    }

    pub fn save_values(self: *const Self, save_array: []f64) void {
        return switch (self.*) {
            inline else => |impl| return impl.save_values(save_array),
        };
    }

    pub fn save_len(self: *const Self) usize {
        return switch (self.*) {
            inline else => |impl| return impl.save_len,
        };
    }

    pub fn update(self: *const Self) void {
        switch (self.*) {
            inline else => |impl| impl.update(),
        }
    }

    pub fn deinit(self: *const Self) void {
        switch (self.*) {
            inline else => |impl| impl.*.deinit(),
        }
    }
};
