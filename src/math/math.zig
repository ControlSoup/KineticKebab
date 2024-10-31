const std = @import("std");
pub const Vec2 = @import("d2.zig").Vec2;

pub fn f64_pow2(x: f64) f64 {
    return std.math.pow(f64, x, 2.0);
}