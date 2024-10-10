const std = @import("std");
const json = std.json;
const sim = @import("../sim/sim.zig");

const MAX_NAME_LEN = 40;

pub fn json_sim(allocator: std.mem.Allocator, json_string: []const u8) !*sim.Sim{

    const parsed: json.Parsed(json.Value) = try json.parseFromSlice(json.Value, allocator, json_string,.{});
    defer parsed.deinit();

    // Create a new sim
    const sim_options: json.Value =_group_exists(parsed, "SimOptions");
    const new_sim_ptr: *sim.Sim = try sim.Sim.from_json(allocator, sim_options);

    var all_connections = std.ArrayList([2][]const u8).init(allocator); 

    // Add objects
    const sim_objs: json.Value = _group_exists(parsed, "SimObjects");
    for (sim_objs.object.keys()) |obj_name|{

        const contents = sim_objs.object.get(obj_name) orelse unreachable;

        // Init specific objects, as a sim object interface
        if (std.mem.eql(u8, obj_name, "Motion1DOF")){
            const new_obj_ptr = try sim.motion.Motion1DOF.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());

        } 
        else if (std.mem.eql(u8, obj_name, "SimpleForce")){

            const new_obj_ptr = try sim.forces.Simple.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());

        }
        else if (std.mem.eql(u8, obj_name, "SpringForce")){

            const new_obj_ptr = try sim.forces.Spring.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());

        }else{
            std.debug.panic("ERROR| Object [{s}] was unable to be created", .{obj_name});
        }

        // Attempt to grab connections
        const connection_json = contents.object.get("connections") orelse break;
        const connections = std.json.parseFromValue([][]const u8, allocator, connection_json, .{}) catch |err|{
            std.debug.panic("ERROR| Unable to parse connection list in object [{s}] \n{!}", .{obj_name,err});
        };

        // Add any connections for future attachment
        for (connections.value) |connection|{
            const latest_added_obj = new_sim_ptr.sim_objs.items[new_sim_ptr.sim_objs.items.len - 1].name();
            try all_connections.append([2][]const u8{latest_added_obj, connection});
        } 

    }
    for (new_sim_ptr.sim_objs.items) |objs|{
        std.log.info("{s}", .{objs.name()});
    }

    // Perform all connections
    for (all_connections.items) |connection_event|{
        const connectee: sim.SimObject = new_sim_ptr._get_sim_object_by_name(connection_event[0]);
        const connector = switch(new_sim_ptr._get_sim_object_by_name(connection_event[1])){
            .Simple => |impl| impl.as_force(),
            .Spring => |impl| impl.as_force(),
            else => std.debug.panic("ERROR| Invalid connector {s}", .{connection_event[1]})
        };



        switch (connectee){
            .Integration => |integration| {
                try switch(integration){
                    .Motion1DOF => |sub_simpl| sub_simpl.add_connection(connector)
                };
            },
            else => std.debug.panic("ERROR| Invalid connectee {s}", .{connection_event[0]})
        }

    }

    // Give the world the sim
    std.log.info("{any}", .{all_connections});
    return new_sim_ptr;
}

pub fn _group_exists(parsed: json.Parsed(json.Value), key: []const u8) json.Value{
    return parsed.value.object.get(key) orelse std.debug.panic("ERROR| Json does not contain [{s}] please add it", .{key});
}

pub fn field(allocator: std.mem.Allocator, comptime T: type, obj_name: []const u8, key: []const u8, contents: std.json.Value) T{
    const parsed = std.json.parseFromValue(
        T, 
        allocator, 
        contents.object.get(key) orelse std.debug.panic("ERROR| Attempting to init [{s}] but [{s}] field is missing", .{obj_name, key}
        ), .{}
    ) catch |err|{
        std.debug.panic("ERROR| Could not parse field [{s}.{s}] check field matches type [{any}] \n {!}", .{obj_name, key, T, err});
    };
    defer parsed.deinit();

    const value = parsed.value;
    return value;
}

pub fn string_field(allocator: std.mem.Allocator, obj_name: []const u8, key: []const u8, contents: std.json.Value) []const u8{
    const parsed = std.json.parseFromValue(
        []const u8, 
        allocator, 
        contents.object.get(key) orelse std.debug.panic("ERROR| Attempting to init [{s}] but [{s}] field is missing", .{obj_name, key}
        ), .{}
    ) catch |err|{
        std.debug.panic("ERROR| Could not parse field [{s}.{s}] check field matches type [[]const u8] \n {!}", .{obj_name, key, err});
    };
    defer parsed.deinit();

    return allocator.dupe(u8, parsed.value) catch |err| std.debug.panic("ERROR| {!}", .{err});
}