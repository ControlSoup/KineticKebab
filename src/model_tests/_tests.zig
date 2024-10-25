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
    var file = try std.fs.cwd().openFile("model_tests/fluids_base.json", .{ .mode = .read_only });
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

    const orifice: sim.SimObject = try model._get_sim_object_by_name("TestOrifice");
    const obj2: sim.SimObject = try model._get_sim_object_by_name("DownstreamTest");
    _ = orifice;
    _ = obj2;

    const obj: sim.SimObject = try model._get_sim_object_by_name("UpstreamTest");
    const state = obj.Integration.Volume.get_intrinsic();

    // Choked
    const mdot = sim.restrictions.ideal_choked_mdot(
        try model.get_save_value_by_name("TestChokedOrifice.cda [m^2]"),
        state.density,
        state.press,
        state.gamma
    );

    const actual_mdot = try model.get_save_value_by_name("TestChokedOrifice.mdot [kg/s]");

    try std.testing.expectApproxEqRel(mdot, actual_mdot, 1e-4);
}