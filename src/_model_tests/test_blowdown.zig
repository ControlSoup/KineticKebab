
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
    \\        "dt": 0.50 
    \\    },
    \\    "SimObjects":[
    \\        {
    \\            "object": "fluids.volumes.Static",
    \\            "name": "UpstreamTest",
    \\            "press": 200000,
    \\            "temp": 277,
    \\            "volume": 10,
    \\            "fluid": "Nitrogen",
    \\            "connections_out": ["TestOrifice"]
    \\        },
    \\        {
    \\            "object": "fluids.restrictions.Orifice",
    \\            "name": "TestOrifice",
    \\            "cda": 0.075,
    \\            "mdot_method": "IdealCompressible"
    \\        },
    \\        {
    \\            "object": "fluids.volumes.Void",
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

