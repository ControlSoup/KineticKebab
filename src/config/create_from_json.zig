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
    Ullage
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
    const config: json.Value = try group_exists(parsed, "SimOptions");
    const new_sim_ptr = try sim.Sim.from_json(allocator, config);
    try new_sim_ptr.add_sim_obj(new_sim_ptr.integrator.as_sim_object());


    // Create a queue for connections 
    var all_connections = std.ArrayList(Connection).init(allocator); 

    // Add objects
    const sim_objs: json.Value = try group_exists(parsed, "SimObjects");
    for (sim_objs.array.items) |contents| {


        const obj_name = try string_field(allocator, json.Value, "object", contents);

        // Init specific objects, as a sim object interface
        if (std.mem.eql(u8, obj_name, @typeName(sim.motions.d1.Motion))){
            const new_obj_ptr = try sim.motions.d1.Motion.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            try new_sim_ptr.add_integratable(new_obj_ptr.as_integratable());
            try new_sim_ptr.add_updateable(new_obj_ptr.as_updateable());
        } 
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.d1.Simple))){
            const new_obj_ptr = try sim.forces.d1.Simple.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.d1.Spring))){
            const new_obj_ptr = try sim.forces.d1.Spring.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
        } 
        else if (std.mem.eql(u8, obj_name, @typeName(sim.volumes.Void))){
            const new_obj_ptr = try sim.volumes.Void.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            try new_sim_ptr.add_updateable(new_obj_ptr.as_updateable());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.volumes.Static))){
            const new_obj_ptr = try sim.volumes.Static.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            try new_sim_ptr.add_integratable(new_obj_ptr.as_integratable());
            try new_sim_ptr.add_updateable(new_obj_ptr.as_updateable());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.volumes.RuntankUllage))){
            const new_obj_ptr = try sim.volumes.RuntankUllage.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            try new_sim_ptr.add_integratable(new_obj_ptr.as_integratable());
            // Updates are taken care of in the working fluid connection
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.volumes.RuntankWorkingFluid))){
            const new_obj_ptr = try sim.volumes.RuntankWorkingFluid.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            try new_sim_ptr.add_integratable(new_obj_ptr.as_integratable());
            try new_sim_ptr.add_updateable(new_obj_ptr.as_updateable());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.restrictions.Orifice))){
            const new_obj_ptr = try sim.restrictions.Orifice.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.restrictions.ConstantMdot))){
            const new_obj_ptr = try sim.restrictions.ConstantMdot.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.motions.d3.Motion))){
            const new_obj_ptr = try sim.motions.d3.Motion.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            try new_sim_ptr.add_integratable(new_obj_ptr.as_integratable());
            try new_sim_ptr.add_updateable(new_obj_ptr.as_updateable());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.d3.Simple))){
            const new_obj_ptr = try sim.forces.d3.Simple.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
        }
        else if (std.mem.eql(u8, obj_name, @typeName(sim.forces.d3.BodySimple))){
            const new_obj_ptr = try sim.forces.d3.BodySimple.from_json(allocator, contents);
            try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
        }
        else{
            errdefer std.log.err("Object [{s}] was unable to be created", .{obj_name});
            return errors.JsonMissingGroup;
        }

        // Attempt to grab connections
        const lastest_object = new_sim_ptr.sim_objs.items[new_sim_ptr.sim_objs.items.len - 1];
        errdefer std.log.err("Unable to parse connection for object [{s}]", .{lastest_object.name()});

        if (contents.object.get("connections_in")) |connection_json| {
            const connections = std.json.parseFromValue([][]const u8, allocator, connection_json, .{}) catch {
                return errors.JsonConnectionListParseError;
            };

            for (connections.value) |connection|{
                try all_connections.append(Connection.new(connection, lastest_object.name(), .In));
            }
        } 
        if (contents.object.get("connections_out")) |connection_json| {
            const connections = std.json.parseFromValue([][]const u8, allocator, connection_json, .{}) catch {
                return errors.JsonConnectionListParseError;
            };

            for (connections.value) |connection|{
                try all_connections.append(Connection.new(connection, lastest_object.name(), .Out));
            }

        }
        if (contents.object.get("ullage_connection")) |connection_json| {
            const connections = std.json.parseFromValue([][]const u8, allocator, connection_json, .{}) catch {
                return errors.JsonConnectionListParseError;
            };

            for (connections.value) |connection|{
                try all_connections.append(Connection.new(connection, lastest_object.name(), .Ullage));
            }
        } 
    }

    // Add simulation info
    try new_sim_ptr.add_sim_obj(new_sim_ptr.as_sim_object());

    // Perform all connections
    for (all_connections.items) |connection_event|{
        const plug: sim.SimObject = try new_sim_ptr.get_sim_object_by_name(connection_event.plug);
        const socket: sim.SimObject = try new_sim_ptr.get_sim_object_by_name(connection_event.socket);
        const connection_type = connection_event.connection_type;

        errdefer std.log.err("Failed to connect [{s}] to [{s}]", .{socket.name(), plug.name()});

        // Most objects go from plug -> socket
        try switch (socket){
            .Static => |impl| switch(connection_type){
                .In => try impl.as_volume().add_connection_in(plug),
                .Out => try impl.as_volume().add_connection_out(plug),
                inline else => return {
                    return errors.JsonConnectionTypeInvalid;
                },
                
            },
            .Void => |v| switch(connection_type){
                .In => try v.as_volume().add_connection_in(plug),
                .Out => try v.as_volume().add_connection_out(plug),
                inline else => return {
                    return errors.JsonConnectionTypeInvalid;
                },
            },
            .Motion1DOF => |impl| impl.add_connection(plug),
            .Motion3DOF => |impl| impl.add_connection(plug),
            .RuntankWorkingFluid => |v| switch(connection_type) {
                .In => try v.as_volume().add_connection_in(plug),
                .Out => try v.as_volume().add_connection_out(plug),
                .Ullage => try v.connect_ullage(plug.RuntankUllage),
            },
            .RuntankUllage => |v| switch(connection_type){
                .In => try v.as_volume().add_connection_in(plug),
                .Out => try v.as_volume().add_connection_out(plug),
                inline else => return {
                    return errors.JsonConnectionTypeInvalid;
                },

            },
            inline else => return {
                return errors.JsonConnectionTypeInvalid;
            },
            
        };

    }

    for (new_sim_ptr.updatables.items) |obj| try obj.update();

    // Give the world the sim
    return new_sim_ptr;
}

pub fn group_exists(parsed: json.Parsed(json.Value), key: []const u8) !json.Value{
    return parsed.value.object.get(key) orelse {
        std.log.err("Json does not contain [{s}] please add it", .{key});
        return errors.JsonMissingGroup;
    };
}

pub fn optional_group_exists(parsed: json.Parsed(json.Value), key: []const u8) ?json.Value{
    return parsed.value.object.get(key) orelse return null;
}

pub fn field(allocator: std.mem.Allocator, comptime T: type, comptime S: type, key: []const u8, contents: std.json.Value) !T{

    const object = contents.object.get(key) orelse {
        std.log.err("Attempting to init [{s}] but [{s}] field is missing", .{@typeName(S), key});
        return errors.JsonObjectFieldMissing;
    };

    const parsed = std.json.parseFromValue(T, allocator, object, .{}) catch {
        std.log.err("Could not parse field [{s}.{s}] check field matches type [{any}]", .{@typeName(S), key, T});
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    const value = parsed.value;
    return value;
}

pub fn optional_field(allocator: std.mem.Allocator, comptime T: type, comptime S: type, key: []const u8, contents: std.json.Value) !?T{

    const object = contents.object.get(key) orelse return null;

    const parsed = std.json.parseFromValue(T, allocator, object, .{}) catch {
        std.log.err("Could not parse field [{s}.{s}] check field matches type [{any}]", .{@typeName(S), key, T});
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    const value = parsed.value;
    return value;
}

pub fn string_field(allocator: std.mem.Allocator, comptime S: type, key: []const u8, contents: std.json.Value) ![]const u8{

    const object = contents.object.get(key) orelse {
        std.log.err("Attempting to init [{s}] but [{s}] field is missing", .{@typeName(S), key});
        return errors.JsonObjectFieldMissing;
    };

    const parsed = std.json.parseFromValue([]const u8, allocator, object,.{}) catch {
        std.log.err("Could not parse field [{s}.{s}] check field matches type [{any}]", .{@typeName(S), key, []const u8});
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    return  try allocator.dupe(u8, parsed.value);
}
