const std = @import("std");
const json = std.json;
const sim = @import("../sim/sim.zig");

pub const errors = error{
    JsonMissingGroup,
    JsonObjectFieldMissing,
    JsonObjectFieldInvalidType,
    JsonObjectCreationError,
    JsonConnectionListParseError,
    JsonFailedConnection,
};

pub fn json_sim(allocator: std.mem.Allocator, json_string: []const u8) !*sim.Sim{

    const parsed: json.Parsed(json.Value) = try json.parseFromSlice(json.Value, allocator, json_string,.{});
    defer parsed.deinit();

    // Create a new sim
    const sim_options: json.Value = try _group_exists(parsed, "SimOptions");
    const new_sim_ptr: *sim.Sim = try sim.Sim.from_json(allocator, sim_options);

    // Create a queue for connections 
    var all_connections = std.ArrayList([2][]const u8).init(allocator); 

    // Add objects
    const sim_objs: json.Value = try _group_exists(parsed, "SimObjects");
    for (sim_objs.array.items) |contents|{


        const obj_name = try string_field(allocator, "JSON", "object", contents);

        // Init specific objects, as a sim object interface
        if (std.mem.eql(u8, obj_name, @typeName(sim.motion.Motion1DOF))){
            const new_obj_ptr = try sim.motion.Motion1DOF.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());

        } 
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.Simple))){
            const new_obj_ptr = try sim.forces.Simple.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.Spring))){
            const new_obj_ptr = try sim.forces.Spring.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        }else{
            errdefer std.log.err("ERROR| Object [{s}] was unable to be created", .{obj_name});
            return errors.JsonMissingGroup;
        }

        // Attempt to grab connections
        const connection_json = contents.object.get("connections") orelse continue;
        const connections = std.json.parseFromValue([][]const u8, allocator, connection_json, .{}) catch {
            std.debug.panic("ERROR| Unable to parse connection list in object [{s}], ensure its a list of object names", .{obj_name});
            return errors.JsonConnectionListParseError;
        };

        // Add any connections for future attachment
        for (connections.value) |connection|{
            const latest_added_obj = new_sim_ptr.sim_objs.items[new_sim_ptr.sim_objs.items.len - 1].name();
            try all_connections.append([2][]const u8{latest_added_obj, connection});
        } 

    }

    // Perform all connections
    for (all_connections.items) |connection_event|{
        const connectee: sim.SimObject = try new_sim_ptr._get_sim_object_by_name(connection_event[0]);
        const connector: sim.SimObject = try new_sim_ptr._get_sim_object_by_name(connection_event[1]);

        // Perform correction connections
        try switch (connectee){
            // Integration Connections
            .Integration => |integration| switch (integration){
                .Motion1DOF => |impl| impl.add_connection(connector)
            },
            
            inline else => {
                std.log.err("ERROR| Failed to connect [{s}] to [{s}]", .{connection_event[0], connection_event[1]});
                return errors.JsonFailedConnection;
            }
        };

    }

    // Give the world the sim
    return new_sim_ptr;
}

pub fn _group_exists(parsed: json.Parsed(json.Value), key: []const u8) !json.Value{
    return parsed.value.object.get(key) orelse {
        errdefer std.log.err("ERROR| Json does not contain [{s}] please add it", .{key});
        return errors.JsonMissingGroup;
    };
}

pub fn field(allocator: std.mem.Allocator, comptime T: type, obj_name: []const u8, key: []const u8, contents: std.json.Value) !T{

    const object = contents.object.get(key) orelse {
        std.log.err("ERROR| Attempting to init [{s}] but [{s}] field is missing", .{obj_name, key});
        return errors.JsonObjectFieldMissing;
    };

    const parsed = std.json.parseFromValue(T, allocator, object, .{}) catch {
        std.log.err("ERROR| Could not parse field [{s}.{s}] check field matches type [{any}]", .{obj_name, key, T});
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    const value = parsed.value;
    return value;
}

pub fn string_field(allocator: std.mem.Allocator, obj_name: []const u8, key: []const u8, contents: std.json.Value) ![]const u8{

    const object = contents.object.get(key) orelse {
        std.log.err("ERROR| Attempting to init [{s}] but [{s}] field is missing", .{obj_name, key});
        return errors.JsonObjectFieldMissing;
    };

    const parsed = std.json.parseFromValue([]const u8, allocator, object,.{}) catch {
        std.log.err("ERROR| Could not parse field [{s}.{s}] check field matches type [{any}]", .{obj_name, key, []const u8});
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    return  try allocator.dupe(u8, parsed.value);
}