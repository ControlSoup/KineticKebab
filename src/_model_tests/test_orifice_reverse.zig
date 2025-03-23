const std = @import("std");
const sim = @import("../sim.zig");

test "TransientOrificeFlow" {
    // =========================================================================
    // Allocation
    // =========================================================================
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    // =========================================================================
    // Json
    // =========================================================================
    var json =
        \\{
        \\    "SimOptions":{
        \\        "dt": 1e-3, 
        \\        "integration_method": "Rk4" 
        \\    },
        \\    "SimObjects":[
        \\        {
        \\            "object": "VoidVolume",
        \\            "name": "UpstreamTest",
        \\            "press": 150000,
        \\            "temp": 277,
        \\            "fluid": "Nitrogen",
        \\            "connections_out": ["TestUnchokedOrifice"]
        \\        },
        \\        {
        \\            "object": "Orifice",
        \\            "name": "TestUnchokedOrifice",
        \\            "cda": 1.0,
        \\            "mdot_method": "IdealIsentropic"
        \\        },
        \\        {
        \\            "object": "VoidVolume",
        \\            "name": "DownstreamTest",
        \\            "press": 200000,
        \\            "temp": 277,
        \\            "fluid": "Nitrogen",
        \\            "connections_in": ["TestUnchokedOrifice"]
        \\        }
        \\    ]
        \\}
    ;

    // =========================================================================
    // Sim
    // =========================================================================
    const model = try sim.parse.json_sim(allocator, json[0..]);
    try model.step_duration(1.0);

    const uch_orifice: sim.SimObject = try model.get_sim_object_by_name("TestUnchokedOrifice");
    _ = uch_orifice;

    const us: sim.SimObject = try model.get_sim_object_by_name("UpstreamTest");
    const us_state = us.VoidVolume.as_volume().get_intrinsic();

    const ds: sim.SimObject = try model.get_sim_object_by_name("DownstreamTest");
    _ = ds.VoidVolume.as_volume().get_intrinsic();

    const uch_ds: sim.SimObject = try model.get_sim_object_by_name("DownstreamTest");
    const uch_ds_state = uch_ds.VoidVolume.as_volume().get_intrinsic();

    const uch_mdot = -sim.fluids_equations.orifice.ideal_unchoked_mdot(try model.get_value_by_name("TestUnchokedOrifice.cda [m^2]"), uch_ds_state.density, uch_ds_state.press, us_state.press, uch_ds_state.gamma);
    const actual_unch_mdot = try model.get_value_by_name("TestUnchokedOrifice.mdot [kg/s]");

    try std.testing.expect(try model.get_value_by_name("TestUnchokedOrifice.is_choked [-]") == 0.0);
    try std.testing.expect(actual_unch_mdot < 0.0);
    try std.testing.expectApproxEqRel(uch_mdot, actual_unch_mdot, 1e-4);

    try model.end();
}
