const std = @import("std");
const c = @cImport({
    @cInclude("./CoolPropLib.h");
});

// =============================================================================
// Coolprop Wrapper Functions
// For testing you require the static library libCoolProp.so.6 in /usr/lib64 and/or lib 
// =============================================================================

pub fn get_property(
    output: []const u8, 
    name1: []const u8, 
    prop1: f64, 
    name2: []const u8, 
    prop2: f64, 
    fluid: []const u8
) f64{
    return c.PropsSI(
        output.ptr, 
        name1.ptr, 
        prop1, 
        name2.ptr, 
        prop2, 
        fluid.ptr
    );
}

test "coolprop_wrapper"{
    const d = get_property("D", "P", 100000, "T", 300, "NITROGEN");
    const a = get_property("A", "P", 100000, "T", 300, "NITROGEN");
    const s = get_property("S", "P", 100000, "T", 300, "NITROGEN");
    const u = get_property("U", "P", 100000, "T", 300, "NITROGEN");

    try std.testing.expectApproxEqRel(d, 1.1232785597941712, 1e-6);
    try std.testing.expectApproxEqRel(a, 353.1590876144119, 1e-6);
    try std.testing.expectApproxEqRel(s, 6845.65027950997, 1e-6);
    try std.testing.expectApproxEqRel(u, 222171.25777887437, 1e-6);
}