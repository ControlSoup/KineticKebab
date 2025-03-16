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
    \\        "max_iter": 50
    \\    },
    \\    "SimObjects":[
    \\        {
    \\            "object": "VoidVolume",
    \\            "name": "Upstream",
    \\            "press": 200000.0,
    \\            "temp": 300.0,
    \\            "fluid": "Nitrogen",
    \\            "connections_out": ["Orifice1"]
    \\        },
    \\        {
    \\            "object": "Orifice",
    \\            "name": "Orifice1",
    \\            "cda": 0.0001,
    \\            "mdot_method": "IdealIsentropic"
    \\        },
    \\        {
    \\            "object": "UpwindedSteadyVolume",
    \\            "name": "Inter1",
    \\            "press": 50.0,
    \\            "temp": 300.0,
    \\            "fluid": "Nitrogen",
    \\            "connections_in": ["Orifice1"],
    \\            "connections_out": ["Orifice2"]
    \\        },
    \\        {
    \\            "object": "Orifice",
    \\            "name": "Orifice2",
    \\            "cda": 0.0001,
    \\            "mdot_method": "IdealIsentropic"
    \\        },
    \\        {
    \\            "object": "UpwindedSteadyVolume",
    \\            "name": "Inter2",
    \\            "press": 25.0,
    \\            "temp": 300.0,
    \\            "fluid": "Nitrogen",
    \\            "connections_in": ["Orifice2"],
    \\            "connections_out": ["Orifice3"]
    \\        },
    \\        {
    \\            "object": "Orifice",
    \\            "name": "Orifice3",
    \\            "cda": 0.0001,
    \\            "mdot_method": "IdealIsentropic"
    \\        },
    \\        {
    \\            "object": "VoidVolume",
    \\            "name": "Downstream",
    \\            "press": 1e-8,
    \\            "temp": 300.0,
    \\            "fluid": "Nitrogen",
    \\            "connections_in": ["Orifice3"]
    \\        }
    \\    ]
    \\}
    ;

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const model = try sim.parse.json_sim(allocator, json[0..]);

    try model.solve_steady();
    model._print_info();
    try model.end();

}