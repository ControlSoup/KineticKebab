const std = @import("std");
const json = std.json;
const sim = @import("../sim/sim.zig");

pub fn json_sim(allocator: std.mem.Allocator, json_string: []const u8) !*sim.Sim{

    const parsed: json.Parsed(json.Value) = try json.parseFromSlice(json.Value, allocator, json_string,.{});
    defer parsed.deinit();

    // Create a new sim
    const sim_options: json.Value =_group_exists(parsed, "SimOptions");
    const new_sim_ptr: *sim.Sim = try sim.Sim.from_json(allocator, sim_options);

    // Add objects
    const sim_objs: json.Value = _group_exists(parsed, "SimObjects");
    for (sim_objs.object.keys()) |obj_name|{

        // Motion1DOF creation
        if (std.mem.eql(u8, obj_name, "Motion1DOF")){
            const new_obj_ptr = try sim.motion.Motion1DOF.from_json(allocator, sim_objs.object.get(obj_name) orelse unreachable);
            new_sim_ptr.*.add_obj(new_obj_ptr);
        }

    }

    // Give the world the sim
    return new_sim_ptr;
}

pub fn _group_exists(parsed: json.Parsed(json.Value), key: []const u8) json.Value{
    return parsed.value.object.get(key) orelse std.debug.panic("ERROR| Json does not contain [{s}] please add it", .{key});
}

pub fn parse_field(allocator: std.mem.Allocator, comptime T: type, obj_name: []const u8, key: []const u8, contents: std.json.Value) T{
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