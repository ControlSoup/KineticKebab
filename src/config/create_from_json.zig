const std = @import("std");
const json = std.json;
const sim = @import("../sim.zig");

pub const errors = error{
    JsonMissingGroup,
    JsonObjectFieldMissing,
    JsonObjectFieldInvalidType,
    JsonObjectCreationError,
    JsonConnectionListParseError,
    JsonConnectionTypeInvalid,
    JsonFailedConnection,
};

pub const ConnectionType = enum{
    In,
    Out,
};

pub const Connection = struct{
    plug: []const u8,
    socket: []const u8,
    connection_type: ConnectionType,

    pub fn new(plug: []const u8, socket: []const u8, connection_type: ConnectionType) Connection{
        return Connection{.plug = plug, .socket = socket, .connection_type = connection_type};
    } 
};

pub fn json_sim(allocator: std.mem.Allocator, json_string: []const u8) !*sim.Sim{

    const parsed: json.Parsed(json.Value) = try json.parseFromSlice(json.Value, allocator, json_string,.{});
    defer parsed.deinit();

    // Create a new sim
    const sim_options: json.Value = try group_exists(parsed, "SimOptions");
    const new_sim_ptr: *sim.Sim = try sim.Sim.from_json(allocator, sim_options);

    // See if recorder options are inlcuded
    const recorder_options :?json.Value = optional_group_exists(parsed, "RecorderOptions");

    // Create a queue for connections 
    var all_connections = std.ArrayList(Connection).init(allocator); 

    // Add objects
    const sim_objs: json.Value = try group_exists(parsed, "SimObjects");
    for (sim_objs.array.items) |contents| {


        const obj_name = try string_field(allocator, json.Value, "object", contents);

        // Init specific objects, as a sim object interface
        if (std.mem.eql(u8, obj_name, @typeName(sim.motions.d1.Motion))){
            const new_obj_ptr = try sim.motions.d1.Motion.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        } 
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.d1.Simple))){
            const new_obj_ptr = try sim.forces.d1.Simple.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.d1.Spring))){
            const new_obj_ptr = try sim.forces.d1.Spring.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        } 
        else if (std.mem.eql(u8, obj_name, @typeName(sim.volumes.Void))){
            const new_obj_ptr = try sim.volumes.Void.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.restrictions.Orifice))){
            const new_obj_ptr = try sim.restrictions.Orifice.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.motions.d2.Motion))){
            const new_obj_ptr = try sim.motions.d2.Motion.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.d2.Simple))){
            const new_obj_ptr = try sim.forces.d2.Simple.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.d2.BodySimple))){
            const new_obj_ptr = try sim.forces.d2.BodySimple.from_json(allocator, contents);
            try new_sim_ptr.create_obj(new_obj_ptr.as_sim_object());
        }
        else{
            errdefer std.log.err("ERROR| Object [{s}] was unable to be created", .{obj_name});
            return errors.JsonMissingGroup;
        }

        // Attempt to grab connections

        errdefer std.log.err("ERROR| Unable to parse connection for object [{s}]", .{obj_name});

        if (contents.object.get("connections_in")) |connection_json| {
            const connections = std.json.parseFromValue([][]const u8, allocator, connection_json, .{}) catch {
                return errors.JsonConnectionListParseError;
            };

            for (connections.value) |connection|{
                const latest_added_obj = new_sim_ptr.sim_objs.items[new_sim_ptr.sim_objs.items.len - 1].name();
                try all_connections.append(Connection.new(connection, latest_added_obj, .In));
            }
        } 
        else if (contents.object.get("connections_out")) |connection_json| {
            const connections = std.json.parseFromValue([][]const u8, allocator, connection_json, .{}) catch {
                return errors.JsonConnectionListParseError;
            };

            for (connections.value) |connection|{
                const latest_added_obj = new_sim_ptr.sim_objs.items[new_sim_ptr.sim_objs.items.len - 1].name();
                try all_connections.append(Connection.new(connection, latest_added_obj, .Out));
            }

        }
    }

    // Add simulation info
    try new_sim_ptr.add_obj(new_sim_ptr.as_sim_object());

    // Perform all connections
    for (all_connections.items) |connection_event|{
        const plug: sim.SimObject = try new_sim_ptr.get_sim_object_by_name(connection_event.plug);
        const socket: sim.SimObject = try new_sim_ptr.get_sim_object_by_name(connection_event.socket);
        const connection_type = connection_event.connection_type;

        // Most objects go from plug -> socket
        try switch (socket){
            .Integration => |integration| switch (integration){
                .Motion1DOF => |impl| impl.add_connection(plug),
                .Motion2DOF => |impl| impl.add_connection(plug),
                .Volume => |impl| switch(connection_type){
                    .In => try impl.add_connection_in(plug),
                    .Out => try impl.add_connection_out(plug),
                } 
            },
            inline else => {
                std.log.err("ERROR| Failed to connect [{s}] to [{s}]", .{plug.name(), socket.name()});
                return errors.JsonFailedConnection;
            }
        };

    }

    if (recorder_options != null){
        try new_sim_ptr.create_recorder_from_json(recorder_options.?);
    }

    for (new_sim_ptr.sim_objs.items) |obj| try obj.update();

    // Give the world the sim
    return new_sim_ptr;
}

pub fn group_exists(parsed: json.Parsed(json.Value), key: []const u8) !json.Value{
    return parsed.value.object.get(key) orelse {
        errdefer std.log.err("ERROR| Json does not contain [{s}] please add it", .{key});
        return errors.JsonMissingGroup;
    };
}

pub fn optional_group_exists(parsed: json.Parsed(json.Value), key: []const u8) ?json.Value{
    return parsed.value.object.get(key) orelse return null;
}

pub fn field(allocator: std.mem.Allocator, comptime T: type, comptime S: type, key: []const u8, contents: std.json.Value) !T{

    const object = contents.object.get(key) orelse {
        std.log.err("ERROR| Attempting to init [{s}] but [{s}] field is missing", .{@typeName(S), key});
        return errors.JsonObjectFieldMissing;
    };

    const parsed = std.json.parseFromValue(T, allocator, object, .{}) catch {
        std.log.err("ERROR| Could not parse field [{s}.{s}] check field matches type [{any}]", .{@typeName(S), key, T});
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    const value = parsed.value;
    return value;
}

pub fn optional_field(allocator: std.mem.Allocator, comptime T: type, comptime S: type, key: []const u8, contents: std.json.Value) !?T{

    const object = contents.object.get(key) orelse return null;

    const parsed = std.json.parseFromValue(T, allocator, object, .{}) catch {
        std.log.err("ERROR| Could not parse field [{s}.{s}] check field matches type [{any}]", .{@typeName(S), key, T});
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    const value = parsed.value;
    return value;
}

pub fn string_field(allocator: std.mem.Allocator, comptime S: type, key: []const u8, contents: std.json.Value) ![]const u8{

    const object = contents.object.get(key) orelse {
        std.log.err("ERROR| Attempting to init [{s}] but [{s}] field is missing", .{@typeName(S), key});
        return errors.JsonObjectFieldMissing;
    };

    const parsed = std.json.parseFromValue([]const u8, allocator, object,.{}) catch {
        std.log.err("ERROR| Could not parse field [{s}.{s}] check field matches type [{any}]", .{@typeName(S), key, []const u8});
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    return  try allocator.dupe(u8, parsed.value);
}
