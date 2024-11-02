const std = @import("std");
const sim = @import("../sim.zig");

test "TransientOrificeFlow"{
    // ========================================================================= 
    // Allocation
    // ========================================================================= 
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    // ========================================================================= 
    // File Reading
    // ========================================================================= 
    var file = try std.fs.cwd().openFile("_model_tests/fluids_base.json", .{ .mode = .read_only });
    const file_size = (try file.stat()).size;
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    try file.reader().readNoEof(buffer);
    file.close(); 

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const model = try sim.parse.json_sim(allocator, buffer);
    try model.step_duration(1.0);

    const ch_orifice: sim.SimObject = try model.get_sim_object_by_name("TestChokedOrifice");
    const uch_orifice: sim.SimObject = try model.get_sim_object_by_name("TestUnchokedOrifice");
    _ = ch_orifice;
    _ = uch_orifice;

    const us: sim.SimObject = try model.get_sim_object_by_name("UpstreamTest");
    const us_state = us.Integration.Volume.get_intrinsic();
    
    const ds: sim.SimObject = try model.get_sim_object_by_name("DownstreamTest");
    _ = ds.Integration.Volume.get_intrinsic();
    
    const uch_ds: sim.SimObject = try model.get_sim_object_by_name("DownstreamUnchokedTest");
    const uch_ds_state = uch_ds.Integration.Volume.get_intrinsic();

    // Choked
    const ch_mdot = sim.restrictions.ideal_choked_mdot(
        try model.get_save_value_by_name("TestChokedOrifice.cda [m^2]"),
        us_state.density,
        us_state.press,
        us_state.gamma
    );
    const actual_ch_mdot = try model.get_save_value_by_name("TestChokedOrifice.mdot [kg/s]");
    try std.testing.expect(try model.get_save_value_by_name("TestChokedOrifice.is_choked [-]") == 1.0);
    try std.testing.expectApproxEqRel(ch_mdot, actual_ch_mdot, 1e-4);

    // UnChoked
    const uch_mdot = sim.restrictions.ideal_unchoked_mdot(
        try model.get_save_value_by_name("TestUnchokedOrifice.cda [m^2]"),
        us_state.density,
        us_state.press,
        uch_ds_state.press,
        us_state.gamma
    );
    const actual_unch_mdot = try model.get_save_value_by_name("TestUnchokedOrifice.mdot [kg/s]");

    try std.testing.expect(try model.get_save_value_by_name("TestUnchokedOrifice.is_choked [-]") == 0.0);
    try std.testing.expectApproxEqRel(uch_mdot, actual_unch_mdot, 1e-4);
}

test "Motion1DOF"{
    // ========================================================================= 
    // Allocation
    // ========================================================================= 
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    // ========================================================================= 
    // File Reading
    // ========================================================================= 
    var file = try std.fs.cwd().openFile("_model_tests/motion_base.json", .{ .mode = .read_only });
    const file_size = (try file.stat()).size;
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    try file.reader().readNoEof(buffer);
    file.close(); 

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const model = try sim.parse.json_sim(allocator, buffer);
    const t = 1.0;
    try model.step_duration(t);

    // Test Simpe Force
    try std.testing.expectApproxEqRel(
        try model.get_save_value_by_name("TestSimpleOnly.net_force [N]"),
        1.0,
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        try model.get_save_value_by_name("TestSimpleOnly.pos [m]"),
        std.math.pow(f64, t, 2) / 2,
        1e-4,
    );

    // // Test Simple Spring
    // try std.testing.expectApproxEqRel(
    //     try model.get_save_value_by_name("TestSpringOnly.net_force [N]"),
    //     1.0,
    //     1e-4,
    // );
    // try std.testing.expectApproxEqRel(
    //     try model.get_save_value_by_name("TestSpringOnly.pos [m]"),
    //     -1,
    //     1e-4,
    // );

}

test "Motion2DOF"{
    // ========================================================================= 
    // Allocation
    // ========================================================================= 
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    // ========================================================================= 
    // File Reading
    // ========================================================================= 
    var file = try std.fs.cwd().openFile("_model_tests/motion2d_base.json", .{ .mode = .read_only });
    const file_size = (try file.stat()).size;
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    try file.reader().readNoEof(buffer);
    file.close(); 

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const model = try sim.parse.json_sim(allocator, buffer);
    const t = 1.0;
    try model.step_duration(t);
    

    // Test Simple Force
    try std.testing.expectApproxEqRel(
        1.0,
        try model.get_save_value_by_name("TestSimpleOnly.net_force.x [N]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        1.0,
        try model.get_save_value_by_name("TestSimpleOnly.net_force.y [N]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        1.0,
        try model.get_save_value_by_name("TestSimpleOnly.net_moment [N*m]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        std.math.pow(f64, t, 2) / 2,
        try model.get_save_value_by_name("TestSimpleOnly.pos.x [m]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        std.math.pow(f64, t, 2) / 2,
        try model.get_save_value_by_name("TestSimpleOnly.pos.y [m]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        std.math.pow(f64, t, 2) / 2,
        try model.get_save_value_by_name("TestSimpleOnly.theta [rad]"),
        1e-4,
    );
    
    // Test Body
    try std.testing.expectApproxEqAbs(
        0.0,
        try model.get_save_value_by_name("TestBodySimpleOnly.net_force.x [N]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        1.0,
        try model.get_save_value_by_name("TestBodySimpleOnly.net_force.y [N]"),
        1e-4,
    );
    try std.testing.expectApproxEqAbs(
        0.0,
        try model.get_save_value_by_name("TestBodySimpleOnly.net_moment [N*m]"),
        1e-4,
    );
    try std.testing.expectApproxEqAbs(
        0.0,
        try model.get_save_value_by_name("TestBodySimpleOnly.pos.x [m]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        std.math.pow(f64, t, 2.0) / 2.0,
        try model.get_save_value_by_name("TestBodySimpleOnly.pos.y [m]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        std.math.pi / 2.0,
        try model.get_save_value_by_name("TestBodySimpleOnly.theta [rad]"),
        1e-4,
    );

    try model.end();

}
