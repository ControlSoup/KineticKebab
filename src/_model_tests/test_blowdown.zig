
const std = @import("std");
const sim = @import("../sim.zig");

test "Blowdown"{
    // ========================================================================= 
    // Allocation
    // ========================================================================= 
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    // ========================================================================= 
    // Json
    // ========================================================================= 
    var json=
    \\{
    \\    "SimOptions":{
    \\        "dt": 0.50,
    \\        "integration_method": "Rk4" 
    \\    },
    \\    "SimObjects":[
    \\        {
    \\            "object": "StaticVolume",
    \\            "name": "UpstreamTest",
    \\            "press": 200000,
    \\            "temp": 277,
    \\            "volume": 10,
    \\            "fluid": "Nitrogen",
    \\            "connections_out": ["TestOrifice"]
    \\        },
    \\        {
    \\            "object": "Orifice",
    \\            "name": "TestOrifice",
    \\            "cda": 0.075,
    \\            "mdot_method": "IdealIsentropic"
    \\        },
    \\        {
    \\            "object": "VoidVolume",
    \\            "name": "DownstreamTest",
    \\            "press": 100000,
    \\            "temp": 277,
    \\            "fluid": "Nitrogen",
    \\            "connections_in": ["TestOrifice"]
    \\        }
    \\    ]
    \\}

    ;

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const model = try sim.parse.json_sim(allocator, json[0..]);

    try model.step_duration(1.0);
    try model.end();

}

