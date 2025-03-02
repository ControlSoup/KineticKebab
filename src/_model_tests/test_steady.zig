const std = @import("std");
const sim = @import("../sim.zig");

test "Steady"{
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
    \\        "integration_method": "Rk4", 
    \\        "max_iter": 250
    \\    },
    \\    "SimObjects":[
    \\        {
    \\            "object": "VoidVolume",
    \\            "name": "Upstream",
    \\            "press": 200.0,
    \\            "temp": 300.0,
    \\            "fluid": "Nitrogen",
    \\            "connections_out": ["Orifice1"]
    \\        },
    \\        {
    \\            "object": "Orifice",
    \\            "name": "Orifice1",
    \\            "cda": 1.0,
    \\            "mdot_method": "Debug"
    \\        },
    \\        {
    \\            "object": "SteadyVolume",
    \\            "name": "Inter1",
    \\            "press": 25.0,
    \\            "temp": 300.0,
    \\            "fluid": "Nitrogen",
    \\            "connections_in": ["Orifice1"],
    \\            "connections_out": ["Orifice2"]
    \\        },
    \\        {
    \\            "object": "Orifice",
    \\            "name": "Orifice2",
    \\            "cda": 1.0,
    \\            "mdot_method": "Debug"
    \\        },
    \\        {
    \\            "object": "VoidVolume",
    \\            "name": "Downstream",
    \\            "press": 1e-8,
    \\            "temp": 300.0,
    \\            "fluid": "Nitrogen",
    \\            "connections_in": ["Orifice2"]
    \\        }
    \\    ]
    \\}
    ;

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const model = try sim.parse.json_sim(allocator, json[0..]);

    try model.steady.__print("STEADY PRE SOLVE");
    try model.solve_steady();
    try model.steady.__print("STEADY POST SOLVE");
    try model.end();

}