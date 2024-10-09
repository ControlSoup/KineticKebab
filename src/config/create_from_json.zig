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

    // Add objects
    const sim_objs: json.Value = _group_exists(parsed, "SimObjects");
    for (sim_objs.object.keys()) |obj_name|{

        // Init specific objects, as a sim object interface
        if (std.mem.eql(u8, obj_name, "Motion1DOF")){
            const new_obj_ptr = try sim.motion.Motion1DOF.from_json(allocator, sim_objs.object.get(obj_name) orelse unreachable);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
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

pub fn parse_string_field(allocator: std.mem.Allocator, obj_name: []const u8, key: []const u8, contents: std.json.Value) []const u8{
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