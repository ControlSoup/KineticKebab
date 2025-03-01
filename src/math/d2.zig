const std = @import("std");
const f64_pow2 = @import("math.zig").f64_pow2;

pub const Vec2 = struct{
    const Self = @This();

    i: f64,
    j: f64,   

    pub fn init(i: f64, j: f64) Self{
        return Vec2{.i = i, .j = j};
    }

    pub fn init_zeros() Self{
        return Vec2{.i = 0.0, .j = 0.0};
    }

    pub fn init_nan() Self{
        return Vec2{.i = std.math.nan(f64), .j = std.math.nan(f64)};
    }

    pub fn from_angle_rad(norm_: f64, angle_rad: f64) Vec2{
        return Vec2.init(
            norm_ * std.math.cos(angle_rad),
            norm_ * std.math.sin(angle_rad)
        );
    }

    // =========================================================================
    // Vec Ops
    // =========================================================================

    pub fn update_from_angle_rad(self: *Self, angle_rad: f64) void{
        self.i = std.math.cos(angle_rad) * self.norm();
        self.j = std.math.sin(angle_rad) * self.norm();
    }

    pub fn norm(self: *Self) f64{
        return @sqrt(f64_pow2(self.i) + f64_pow2(self.j));
    }

    pub fn norm_pow2(self: *Self) f64{
        return f64_pow2(self.norm());
    }

    pub fn as_unit(self: *Self) Self{
        const norm_ = self.norm();
        return Vec2{.i = self.i / norm_, .j = norm_};
    }

    pub fn dot(self: *Self, vec: Vec2) f64{
        return (self.i * vec.i) + (self.j * vec.j);
    } 

    pub fn add(self: *Self, vec: Vec2) Vec2{
        return Vec2{.i = self.i + vec.i, .j = self.j + vec.j};
    }

    pub fn sub(self: *Self, vec: Vec2) Vec2{
        return Vec2{.i = self.i - vec.i, .j = self.j - vec.j};
    }

    pub fn div(self: *Self, vec: Vec2) Vec2{
        return Vec2{.i = self.i / vec.i, .j = self.j / vec.j};
    }

    pub fn mult(self: *Self, vec: Vec2) Vec2{
        return Vec2{.i = self.i * vec.i, .j = self.j * vec.j};
    }

    // =========================================================================
    // Standard Ops
    // =========================================================================
     
    pub fn add_const(self: *Self, x: f64) Vec2{
        return Vec2{.i = self.i + x, .j = self.j + x};
    }

    pub fn sub_const(self: *Self, x: f64) Vec2{
        return Vec2{.i = self.i - x, .j = self.j - x};
    }

    pub fn mult_const(self: *Self, x: f64) Vec2{
        return Vec2{.i = self.i * x, .j = self.j * x};
    }

    pub fn div_const(self: *Self, x: f64) Vec2{
        return Vec2{.i = self.i / x, .j = self.j / x};
    }


};
 
test "dot_product" {
    // Source:
    //    https://en.wikipedia.org/wiki/Dot_product

    // a • b = 0 for orthogonal

    var a = Vec2.init(1.0, 0.0);
    var b = Vec2.init(0.0, 1.0);

    try std.testing.expectApproxEqRel(
        a.dot(b),
        0.0,
        1e-6
    );

    // a • a = ||a||^2
    try std.testing.expectApproxEqRel(
        a.dot(a),
        a.norm_pow2(),
        1e-6
    );

    // Source:
    // https://www.calculatorsoup.com/calculators/algebra/dot-product-calculator.php

    a = Vec2.init(1.0, 2.0);
    b = Vec2.init(6.0, 7.0);
    // a • a = ||a||^2
    try std.testing.expectApproxEqRel(
        a.dot(b),
        20.0,
        1e-6
    );
}

test "unit_circle" {
    var angle: f64 = std.math.pi / 4.0;
    var a = Vec2.from_angle_rad(1.0, angle);

    // Unit circle Q1
    try std.testing.expectApproxEqRel(
        a.norm(),
        1.0,
        1e-6
    );
    try std.testing.expectApproxEqRel(
        a.i,
        @sqrt(2.0) / 2.0,
        1e-6
    );
    try std.testing.expectApproxEqRel(
        a.j,
        @sqrt(2.0) / 2.0,
        1e-6
    );

    angle = 3.0 * std.math.pi / 4.0 ;
    a = Vec2.from_angle_rad(1.0, angle);

    // Unit circle Q2
    try std.testing.expectApproxEqRel(
        a.norm(),
        1.0,
        1e-6
    );
    try std.testing.expectApproxEqRel(
        a.i,
        -@sqrt(2.0) / 2.0,
        1e-6
    );
    try std.testing.expectApproxEqRel(
        a.j,
        @sqrt(2.0) / 2.0,
        1e-6
    );

    angle = -3.0 * std.math.pi / 4.0 ;
    a = Vec2.from_angle_rad(1.0, angle);

    // Unit circle Q3
    try std.testing.expectApproxEqRel(
        a.norm(),
        1.0,
        1e-6
    );
    try std.testing.expectApproxEqRel(
        a.i,
        -@sqrt(2.0) / 2.0,
        1e-6
    );
    try std.testing.expectApproxEqRel(
        a.j,
        -@sqrt(2.0) / 2.0,
        1e-6,
    );

    angle = - std.math.pi / 4.0 ;
    a = Vec2.from_angle_rad(1.0, angle);

    // Unit circle Q4
    try std.testing.expectApproxEqRel(
        a.norm(),
        1.0,
        1e-6
    );
    try std.testing.expectApproxEqRel(
        a.i,
        @sqrt(2.0) / 2.0,
        1e-6
    );
    try std.testing.expectApproxEqRel(
        a.j,
        -@sqrt(2.0) / 2.0,
        1e-6
    );
}