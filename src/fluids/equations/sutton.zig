const std = @import("std");
const sim = @import("../../sim.zig");


pub fn nozzle_mdot(throat_area: f64, chamber_press: f64, gamma: f64, sos: f64) f64 {
    const root = std.math.sqrt(std.math.pow(f64, (2.0 / (gamma + 1.0)), ((gamma + 1.0) / (gamma - 1.0))));
    return throat_area * chamber_press * gamma * (root / sos);
}

pub fn nozzle_force(mdot: f64, exit_velocity: f64, exit_press: f64, atm_press: f64) f64{
    return mdot * exit_velocity + ((exit_press - atm_press) * atm_press);
}

pub fn nozzle_static_press(total_press: f64, mach: f64, gamma: f64) f64{   
    return total_press / std.math.pow(f64, 1.0 + ((gamma - 1.0) * std.math.pow(f64, mach, 2.0) / 2.0), (gamma / (gamma - 1)));
}

pub fn nozzle_total_press(static_press: f64, mach: f64, gamma: f64) f64{   
    return static_press * std.math.pow(f64, 1.0 + ((gamma - 1.0) * std.math.pow(f64, mach, 2.0) / 2.0), (gamma / (gamma - 1)));
}

pub fn nozzle_static_temp(total_temp: f64, mach: f64, gamma: f64) f64{
    return total_temp / (1.0 + ((gamma - 1.0) * std.math.pow(f64, mach, 2.0)) / 2.0);
}

pub fn nozzle_total_temp(static_temp: f64, mach: f64, gamma: f64) f64{
    return static_temp * (1.0 + ((gamma - 1.0) * std.math.pow(f64, mach, 2.0)) / 2.0);
}

pub fn nozzle_exit_velocity(p1: f64, p2: f64, v1: f64, gamma: f64, sos: f64) f64{
    const a = gamma / (gamma - 1.0);
    const b = 1.0 - std.math.pow(f64, p2 / p1, (gamma - 1.0) / gamma);
    return std.math.sqrt(a * b *  std.math.pow(f64, sos, 2.0) + v1);
}

pub fn nozzle_mach_from_choked_throat(throat_area: f64, ay: f64, gamma: f64, is_supersonic: bool, x_tol: f64, max_iter: usize) !f64{

    if (throat_area == ay) return 1.0;

    // Wrapper because zig does not allow local functions
    const area_error = struct{ 
        fn area_error(my: f64, args: anytype) f64{
            const numer = 1 + ((args.k - 1.0) / 2.0) * std.math.pow(f64, my, 2.0);
            const denom = (args.k + 1.0) / 2.0;
            const power = (args.k + 1.0) / (2.0 * args.k - 2.0);
            const r = (std.math.pow(f64, numer / denom, power) / my) - args.area_ratio; 
            return r;
        }
    }.area_error;

    const args = .{.area_ratio = ay / throat_area, .k = gamma};
    if (is_supersonic){
        return sim.math.root_solvers.bisection(area_error, args, 1.0 + 1e-10, 30, x_tol, max_iter);
    } else{
        return sim.math.root_solvers.bisection(area_error, args, 1e-10, 1.0, x_tol, max_iter);
    }
}

test "Sutton"{
    
    const super_res = try nozzle_mach_from_choked_throat(1.0, 3.0, 1.4, true, 1e-5, 50);
    const sub_res = try nozzle_mach_from_choked_throat(1.0, 3.0, 1.4, false, 1e-5, 50);

    try std.testing.expectApproxEqAbs(2.6374158493108215, super_res, 1e-4);
    try std.testing.expectApproxEqAbs(0.197448780026986, sub_res, 1e-4);


    const total = nozzle_total_press(0.1013, 2.52, 1.3);

    try std.testing.expectApproxEqAbs(1.84, total, 1e-2);
}