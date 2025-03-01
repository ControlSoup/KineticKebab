const std = @import("std");
const sim = @import("../sim.zig");

test "Motion3DOF"{
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
    \\            "object": "Motion3DOF",
    \\            "name": "TestSimpleOnly",
    \\            "pos.x": 0.0,
    \\            "pos.y": 0.0,
    \\            "theta": 0.0,
    \\            "rotational_inertia": 1.0,
    \\            "mass": 1.0,
    \\            "connections_in": ["TestSimple"]
    \\        },
    \\        {
    \\            "object": "SimpleForce3DOF",
    \\            "name": "TestSimple",
    \\            "force.x": 1.0,
    \\            "force.y": 1.0,
    \\            "moment": 1.0
    \\        },
    \\        {
    \\            "object": "Motion3DOF",
    \\            "name": "TestBodySimpleOnly",
    \\            "pos.x": 0.0,
    \\            "pos.y": 0.0,
    \\            "theta": 1.5707963267948966,
    \\            "rotational_inertia": 1.0,
    \\            "mass": 1.0,
    \\            "connections_in": ["TestSimple2", "TestBodySimple"]
    \\        },
    \\        {
    \\            "object": "SimpleForce3DOF",
    \\            "name": "TestSimple2",
    \\            "force.x": 0.0,
    \\            "force.y": -1.0,
    \\            "moment": -1.0 
    \\        },
    \\        {
    \\            "object": "BodySimpleForce3DOF",
    \\            "name": "TestBodySimple",
    \\            "loc_cg.i": 0.0,
    \\            "loc_cg.j": 0.5,
    \\            "force.i": 2.0,
    \\            "force.j": 0.0
    \\        }
    \\    ]
    \\}
    ;

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const model = try sim.parse.json_sim(allocator, json[0..]);
    const t = 1.0;
    try model.step_duration(t);
    

    // Test Simple Force
    try std.testing.expectApproxEqRel(
        t,
        try model.get_value_by_name("sim.time [s]"),
        1e-6,
    );
    try std.testing.expectApproxEqRel(
        1.0,
        try model.get_value_by_name("TestSimpleOnly.net_force.x [N]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        1.0,
        try model.get_value_by_name("TestSimpleOnly.net_force.y [N]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        1.0,
        try model.get_value_by_name("TestSimpleOnly.net_moment [N*m]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        std.math.pow(f64, t, 2) / 2,
        try model.get_value_by_name("TestSimpleOnly.pos.x [m]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        std.math.pow(f64, t, 2) / 2,
        try model.get_value_by_name("TestSimpleOnly.pos.y [m]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        std.math.pow(f64, t, 2) / 2,
        try model.get_value_by_name("TestSimpleOnly.theta [rad]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        t,
        try model.get_value_by_name("sim.time [s]"),
        1e-6,
    );
    
    // Test Body
    try std.testing.expectApproxEqAbs(
        0.0,
        try model.get_value_by_name("TestBodySimpleOnly.net_force.x [N]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        1.0,
        try model.get_value_by_name("TestBodySimpleOnly.net_force.y [N]"),
        1e-4,
    );
    try std.testing.expectApproxEqAbs(
        0.0,
        try model.get_value_by_name("TestBodySimpleOnly.net_moment [N*m]"),
        1e-4,
    );
    try std.testing.expectApproxEqAbs(
        0.0,
        try model.get_value_by_name("TestBodySimpleOnly.pos.x [m]"),
        1e-4,
    );
    try std.testing.expectApproxEqRel(
        std.math.pi / 2.0,
        try model.get_value_by_name("TestBodySimpleOnly.theta [rad]"),
        1e-4,
    );

    try model.set_value_by_name("TestBodySimpleOnly.pos.x [m]", 0.0);
    try model.step_duration(t);
    try std.testing.expectApproxEqAbs(
        0.0,
        try model.get_value_by_name("TestBodySimpleOnly.pos.x [m]"),
        1e-4,
    );

    try model.end();

}