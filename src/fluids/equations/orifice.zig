const std = @import("std");

// =============================================================================
// Orifice plate equations:
// - https://en.wikipedia.org/wiki/Orifice_plate 
// - https://en.wikipedia.org/wiki/Choked_flow 
// =============================================================================


// =============================================================================
// Ideal
// =============================================================================

pub fn ideal_is_choked(us_stag_press: f64, ds_stag_press: f64, gamma: f64) bool {
    if (us_stag_press / ds_stag_press > 4) return true
    else{
        return ds_stag_press < std.math.pow(f64, 2.0 / (gamma + 1.0), gamma / (gamma - 1.0)) * us_stag_press;
    }
}

pub fn ideal_unchoked_mdot(cda: f64, us_density: f64, us_press: f64, ds_press: f64, gamma: f64) f64{
    const a: f64 = 2.0 * us_density * us_press;
    const b: f64 = gamma / (gamma - 1.0);
    const c: f64 = std.math.pow(f64, ds_press / us_press, 2.0 / gamma);
    const d: f64 = std.math.pow(f64, ds_press / us_press, (gamma + 1.0) / gamma);
    return cda * std.math.sqrt(a * b * (c-d));
}

pub fn ideal_choked_mdot(cda: f64, us_density: f64, us_press: f64, gamma: f64) f64{
    const a: f64 = gamma * us_density * us_press;
    const b: f64 = std.math.pow(f64, 2.0 / (gamma + 1.0),(gamma + 1)/(gamma - 1));
    return cda * std.math.sqrt(a*b);
}

test "ideal_mdots"{
    // Choked flow inputs
    const p1 = 100;
    const p2_choked = 10;
    const gamma = 2;
    const d1 = 3;
    const cda = 10;

    try std.testing.expect(ideal_is_choked(p1, p2_choked, gamma));
    try std.testing.expectApproxEqRel(133.333, ideal_choked_mdot(cda, d1, p1, gamma), 1e-4);

    // Unchoked
    const p2_unchoked = 90;

    try std.testing.expect(!ideal_is_choked(p1, p2_unchoked, gamma));
    try std.testing.expectApproxEqRel(74.4459791, ideal_unchoked_mdot(cda, d1, p1, p2_unchoked, gamma), 1e-4);

}

// =============================================================================
// Incompressible
// =============================================================================

pub fn incompresible_mdot(cda: f64, us_density: f64, us_press: f64, ds_press: f64) f64{
    return cda * std.math.sqrt(2.0 * us_density * (us_density - ds_press));
}