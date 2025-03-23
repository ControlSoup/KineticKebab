const std = @import("std");
const sim = @import("../sim.zig");

test "Motion" {
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
        \\        "dt": 0.1,
        \\        "min_dt": 1e-3,
        \\        "max_dt": 1.0,
        \\        "integration_method": "Rk4" 
        \\    },
        \\    "SimObjects":[
        \\        {
        \\            "object": "Motion",
        \\            "name": "TestSimpleOnly",
        \\            "pos": 0.0,
        \\            "mass": 1.0,
        \\            "connections_in": ["TestSimple"]
        \\        },
        \\        {
        \\            "object": "SimpleForce",
        \\            "name": "TestSimple",
        \\            "force": 1.0
        \\        }    
        \\    ]
        \\}
    ;

    // =========================================================================
    // Sim
    // =========================================================================
    const model = try sim.parse.json_sim(allocator, json[0..]);
    const t = 10.0;
    try model.step_duration(t);

    // Test Simpe Force
    try std.testing.expectApproxEqRel(
        t,
        try model.get_value_by_name("sim.time [s]"),
        1e-6,
    );
    try std.testing.expectApproxEqRel(
        try model.get_value_by_name("TestSimpleOnly.net_force [N]"),
        1.0,
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        try model.get_value_by_name("TestSimpleOnly.pos [m]"),
        std.math.pow(f64, t, 2) / 2,
        1e-4,
    );

    try model.end();
}
