const std = @import("std");
const sim = @import("../sim.zig");

pub const root_errors = error{
    InvalidInput,
    ConvergenceError
};

/// Simple bisection solver for single argument functions 
pub fn bisection(solve_fn: *const fn(f64, anytype) f64, args: anytype, a0: f64, b0: f64, xtol: f64, max_iter: usize) !f64{

    var a = a0;
    var b = b0;


    // Check root is bounded
    if (std.math.sign(solve_fn(a0, args)) == std.math.sign(solve_fn(b0, args))){
        std.log.err("Bisection must bound the root 0 between b1 and b2, got a: [{}] b: [{}] from a0 [{}], b0 [{}]", .{solve_fn(a0, args), solve_fn(b0, args), a0, b0});
        return root_errors.InvalidInput;
    }


    for (0..max_iter - 1) |_|{

        // Iterate remaining
        const c = (a + b) / 2.0;
        const fn_c = solve_fn(c, args);

        if (@abs(fn_c) < xtol){
            return c;
        }

        // Get new guess
        if (std.math.sign(fn_c) == std.math.sign(solve_fn(a, args))) a = c else b = c;

    }

    std.log.err("Bisection unable to converge (reached max_iter)", .{});
    return root_errors.ConvergenceError;
}


fn test_solve(x: f64, _: anytype) f64{

    return std.math.pow(f64, x, 3) - 4.0;
} 

test "Bisection" {
    const test_res = try bisection(test_solve, .{}, 0.0, 2.0, 1e-6, 50);
    try std.testing.expectApproxEqAbs(test_res, 1.587401, 1e-6);
}