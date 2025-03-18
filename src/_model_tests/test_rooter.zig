
const std = @import("std");
const sim = @import("../sim.zig");

test "Motion"{
    // ========================================================================= 
    // Allocation
    // ========================================================================= 
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

    // ========================================================================= 
    // Json
    // ========================================================================= 
const json = 
\\{
\\    "SimOptions":{
\\        "integration_method": "Rk4", 
\\        "max_iter": 50
\\    },
\\    "SimObjects":[
\\        {
\\            "object": "VoidVolume",
\\            "name": "Upstream",
\\            "press": 5e6,
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
\\            "object": "Rooter",
\\            "name": "Rooty",
\\            "connection_getter": "Orifice1",
\\            "connection_setter": "Orifice1",
\\            "set_field": "cda",
\\            "set_val": 0.0001,
\\            "get_field": "mdot",
\\            "target_val": "1.0", 
\\            "max": "100.0", 
\\            "min": "1e-8", 
\\            "max_step": 0.1,
\\            "min_step": 1e-8
\\        },
\\        {
\\            "object": "VoidVolume",
\\            "name": "Downstream",
\\            "press": 1e6,
\\            "temp": 300.0,
\\            "fluid": "Nitrogen",
\\            "connections_in": ["Orifice1"]
\\        }
\\    ]
\\}
;

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const model = try sim.parse.json_sim(allocator, json[0..]);
    try model.solve_steady();
    try model.end();
}