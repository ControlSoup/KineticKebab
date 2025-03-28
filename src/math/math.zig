const std = @import("std");
pub const Vec2 = @import("d2.zig").Vec2;
pub const ArrayMatrix = @import("array_matrix.zig");
pub const ArrayMatrixf64 = ArrayMatrix.ArrayMatrixf64;

pub fn f64_pow2(x: f64) f64 {
    return std.math.pow(f64, x, 2.0);
}

pub fn slice_product_constant(comptime T: type, slice: []T, constant: T) void {
    for (slice, 0..) |_, i| {
        slice[i] = slice[i] * constant;
    }
}

pub fn slice_norm(comptime T: type, slice: []T) T {
    var norm: f64 = 0.0;
    for (slice) |val| {
        norm += std.math.pow(f64, val, 2);
    }
    return std.math.sqrt(norm);
}

pub fn relative_err(comptime T: type, a: T, b: T) T {
    return @abs(a - b) / @max(@max(a, b), 1e-10);
}

pub fn simple_lerp(x: f64, x1: f64, x2: f64, y1: f64, y2: f64) f64 {
    return y1 + (x - x1) * (y2 - y1) / (x2 - x1);
}

pub fn index_geql(comptime T: type, arr: []T, val: T) !usize {
    for (arr, 0..) |curr, i| if (curr >= val) return i;

    std.log.err("Unable to find val >= {s} in array");
    return error.IndexDoesNotExist;
}

pub fn index_leql(comptime T: type, arr: []T, val: T) !usize {
    for (arr, 0..) |curr, i| if (curr <= val) return i;

    std.log.err("Unable to find val <= {s} in array");
    return error.IndexDoesNotExist;
}

/// Performs multilinear polynomial fit
/// Source: https://en.wikipedia.org/wiki/Bilinear_interpolation
pub fn multilinear_poly(
    //
    comptime T: type, 
    x: T, 
    y: T, 
    x1: T, 
    x2: T, 
    y1: T, 
    y2: T,
    f11: T,
    f12: T,
    f21: T,
    f22: T
) T{

    const w11 = (x2 - x) * (y2 - y) / ((x2 - x1) * (y2 - y1));
    const w12 = (x2 - x) * (y - y1) / ((x2 - x1) * (y2 - y1));
    const w21 = (x - x1) * (y2 - y) / ((x2 - x1) * (y2 - y1));
    const w22 = (x - x1) * (y - y1) / ((x2 - x1) * (y2 - y1));

    return f11 * w11 + f12 * w12 + f21 * w21 + f22 * w22;
}