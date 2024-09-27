const std = @import("std");
const motion = @import("../Physics/Motion.zig");

// Helper

fn add_slice(slice: []f64, num: f64) []f64 {
    var new_slice = slice;
    for (slice, 0..) |val, i| {
        new_slice[i] = val + num;
    }
    return new_slice;
}

fn perform_k2n3_op(intial_state: []const f64, k_prev: []f64, dt: f64) []f64 {
    var kn = intial_state; // copy intial_state values for shape

    for (intial_state, k_prev, 0..) |state_val, k_val, i| {
        kn[i] = state_val + (k_val * dt / 2.0);
    }
    return kn;
}

fn perform_final_k_op(intial_state: []f64, k1: []f64, k2: []f64, k3: []f64, k4: f64, dt: f64) []f64 {
    var result = intial_state; // copy intial_state values for shape
    for (intial_state, k1, k2, k3, k4, 0..) |state_val, k1_val, k2_val, k3_val, k4_val, i| {
        result[i] = state_val + ((k1_val + (k2_val * 2.0) + (k3_val * 2.0) + k4_val) * dt / 6.0);
    }
    return result;
}

pub const Integration = union(enum) {
    Motion1DOF: motion.Motion1DOF,

    pub fn get_state(self: Integration) []f64 {
        switch (self) {
            .Motion1DOF => |m| {
                return m.get_state();
            },
        }
    }

    pub fn get_dstate(self: Integration, state: []f64) []f64 {
        switch (self) {
            .Motion1DOF => |m| {
                return m.get_dstate(state);
            },
        }
    }

    pub fn rk4(self: Integration, dt: f64) []f64 {
        var intial_state = self.get_state();
        var k1 = self.get_dstate(intial_state[0..]);
        var k2 = self.get_dstate(perform_k2n3_op(intial_state[0..], k1[0..], dt));
        var k3 = self.get_dstate(perform_k2n3_op(intial_state[0..], k2[0..], dt));
        const k4 = self.get_dstate(add_slice(intial_state[0..], k3[0..]));

        return perform_final_k_op(intial_state, k1, k2, k3, k4, dt);
    }
};
