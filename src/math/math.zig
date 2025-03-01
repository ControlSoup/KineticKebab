const std = @import("std");
pub const root_solvers = @import("root_solvers.zig");
pub const Vec2 = @import("d2.zig").Vec2;

pub fn f64_pow2(x: f64) f64 {
    return std.math.pow(f64, x, 2.0);
}

pub fn slice_product_constant(comptime T: type, slice: []T, constant: T) void{
    for (slice, 0..) |_, i| slice[i] = slice[i] * constant;
}

pub fn slice_norm(comptime T: type, slice: []T) T{
    var norm: f64 = 0.0;
    for (slice) |val| norm += std.math.pow(f64, val, 2);
    return std.math.sqrt(norm);
}

pub fn relative_err(comptime T: type, a: T, b: T) T{
    return @abs(a - b) / @max(@max(a, b), 1e-10);
}