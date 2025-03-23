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
        \\            "press": 200000,
        \\            "temp": 277,
        \\            "fluid": "Nitrogen",
        \\            "connections_out": ["TestUnchokedOrifice", "TestChokedOrifice"]
        \\        },
        \\        {
        \\            "object": "Orifice",
        \\            "name": "TestChokedOrifice",
        \\            "cda": 1.0,
        \\            "mdot_method": "IdealIsentropic"
        \\        },
        \\        {
        \\            "object": "ConstantMdot",
        \\            "name": "TestConstantMdot",
        \\            "mdot": 1.0
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
        \\            "press": 50000,
        \\            "temp": 277,
        \\            "fluid": "Nitrogen",
        \\            "connections_in": ["TestChokedOrifice"]
        \\        },
        \\        {
        \\            "object": "VoidVolume",
        \\            "name": "DownstreamUnchokedTest",
        \\            "press": 190000,
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

    const ch_orifice: sim.SimObject = try model.get_sim_object_by_name("TestChokedOrifice");
    const uch_orifice: sim.SimObject = try model.get_sim_object_by_name("TestUnchokedOrifice");
    _ = ch_orifice;
    _ = uch_orifice;

    const us: sim.SimObject = try model.get_sim_object_by_name("UpstreamTest");
    const us_state = us.VoidVolume.as_volume().get_intrinsic();

    const ds: sim.SimObject = try model.get_sim_object_by_name("DownstreamTest");
    _ = ds.VoidVolume.as_volume().get_intrinsic();

    const uch_ds: sim.SimObject = try model.get_sim_object_by_name("DownstreamUnchokedTest");
    const uch_ds_state = uch_ds.VoidVolume.as_volume().get_intrinsic();

    // Fixed Mdot
    try std.testing.expect(try model.get_value_by_name("TestConstantMdot.mdot [kg/s]") == 1.0);

    // Choked
    const ch_mdot = sim.fluids_equations.orifice.ideal_choked_mdot(try model.get_value_by_name("TestChokedOrifice.cda [m^2]"), us_state.density, us_state.press, us_state.gamma);
    const actual_ch_mdot = try model.get_value_by_name("TestChokedOrifice.mdot [kg/s]");
    try std.testing.expect(try model.get_value_by_name("TestChokedOrifice.is_choked [-]") == 1.0);
    try std.testing.expectApproxEqRel(ch_mdot, actual_ch_mdot, 1e-4);

    // UnChoked
    const uch_mdot = sim.fluids_equations.orifice.ideal_unchoked_mdot(try model.get_value_by_name("TestUnchokedOrifice.cda [m^2]"), us_state.density, us_state.press, uch_ds_state.press, us_state.gamma);
    const actual_unch_mdot = try model.get_value_by_name("TestUnchokedOrifice.mdot [kg/s]");

    try std.testing.expect(try model.get_value_by_name("TestUnchokedOrifice.is_choked [-]") == 0.0);
    try std.testing.expectApproxEqRel(uch_mdot, actual_unch_mdot, 1e-4);

    try model.end();
}
