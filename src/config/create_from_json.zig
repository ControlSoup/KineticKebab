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

pub const ConnectionType = enum {
    In,
    Out,
};

pub const Connection = struct {
    plug: []const u8,
    socket: []const u8,
    connection_type: ConnectionType,

    pub fn new(plug: []const u8, socket: []const u8, connection_type: ConnectionType) Connection {
        return Connection{ .plug = plug, .socket = socket, .connection_type = connection_type };
    }
};

const type_map = std.StringHashMap(sim.SimObject).ini;

pub fn json_sim(allocator: std.mem.Allocator, json_string: []const u8) !*sim.Sim {
    const parsed: json.Parsed(json.Value) = try json.parseFromSlice(json.Value, allocator, json_string, .{});
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

        // Conver Simobject enum to a string for lookup
        const str_enum = std.meta.stringToEnum(std.meta.Tag(sim.SimObject), obj_name) orelse {
            errdefer std.log.err("Object [{s}] was unable to be created, is it a valid SimObject?", .{obj_name});
            return errors.JsonMissingGroup;
        };

        // Init specific objects, as a sim object interface
        switch (str_enum) {
            .Motion => {
                const new_obj_ptr = try sim.motions.d1.Motion.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
                try new_sim_ptr.add_integratable(new_obj_ptr.as_integratable());
                try new_sim_ptr.add_updateable(new_obj_ptr.as_updateable());
            },
            .SimpleForce => {
                const new_obj_ptr = try sim.forces.d1.Simple.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            },
            .SpringForce => {
                const new_obj_ptr = try sim.forces.d1.Spring.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            },
            .VoidVolume => {
                const new_obj_ptr = try sim.volumes.VoidVolume.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
                try new_sim_ptr.add_updateable(new_obj_ptr.as_updateable());
            },
            .StaticVolume => {
                const new_obj_ptr = try sim.volumes.StaticVolume.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
                try new_sim_ptr.add_integratable(new_obj_ptr.as_integratable());
                try new_sim_ptr.add_updateable(new_obj_ptr.as_updateable());
            },
            .UpwindedSteadyVolume => {
                const new_obj_ptr = try sim.volumes.UpwindedSteadyVolume.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
                try new_sim_ptr.add_steadyable(new_obj_ptr.as_steadyable());
            },
            .Orifice => {
                const new_obj_ptr = try sim.restrictions.Orifice.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            },
            .ConstantMdot => {
                const new_obj_ptr = try sim.restrictions.ConstantMdot.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            },
            .Motion3DOF => {
                const new_obj_ptr = try sim.motions.d3.Motion.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
                try new_sim_ptr.add_integratable(new_obj_ptr.as_integratable());
                try new_sim_ptr.add_updateable(new_obj_ptr.as_updateable());
            },
            .SimpleForce3DOF => {
                const new_obj_ptr = try sim.forces.d3.Simple.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            },
            .BodySimpleForce3DOF => {
                const new_obj_ptr = try sim.forces.d3.BodySimple.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
            },
            .Rooter => {
                const new_obj_ptr = try sim.meta.Rooter.from_json(allocator, contents);
                try new_sim_ptr.add_sim_obj(new_obj_ptr.as_sim_object());
                try new_sim_ptr.add_steadyable(new_obj_ptr.as_steadyable());
            },
            .SimInfo, .Integrator => {
                std.log.err("Cannot intialize {s}...silly goose its not a object", .{obj_name});
                return errors.JsonObjectCreationError;
            },
        }

        // Attempt to grab connections
        errdefer std.log.err("Unable to parse connection for object [{s}]", .{obj_name});

        if (contents.object.get("connections_in")) |connection_json| {
            const connections = std.json.parseFromValue([][]const u8, allocator, connection_json, .{}) catch {
                return errors.JsonConnectionListParseError;
            };
            for (connections.value) |connection| {
                try all_connections.append(Connection.new(connection, new_sim_ptr.sim_objs.getLast().name(), .In));
            }
        }
        if (contents.object.get("connections_out")) |connection_json| {
            const connections = std.json.parseFromValue([][]const u8, allocator, connection_json, .{}) catch {
                return errors.JsonConnectionListParseError;
            };

            for (connections.value) |connection| {
                try all_connections.append(Connection.new(connection, new_sim_ptr.sim_objs.getLast().name(), .Out));
            }
        }
    }

    // Add simulation info
    try new_sim_ptr.add_sim_obj(new_sim_ptr.as_sim_object());

    // Perform all connections
    for (all_connections.items) |connection_event| {
        const plug: sim.SimObject = try new_sim_ptr.get_sim_object_by_name(connection_event.plug);
        const socket: sim.SimObject = try new_sim_ptr.get_sim_object_by_name(connection_event.socket);
        const connection_type = connection_event.connection_type;

        // Most objects go from plug -> socket
        try switch (socket) {
            .StaticVolume => |impl| switch (connection_type) {
                .In => try impl.as_volume().add_connection_in(plug),
                .Out => try impl.as_volume().add_connection_out(plug),
            },
            .UpwindedSteadyVolume => |impl| switch (connection_type) {
                .In => try impl.as_volume().add_connection_in(plug),
                .Out => try impl.as_volume().add_connection_out(plug),
            },
            .VoidVolume => |v| switch (connection_type) {
                .In => try v.as_volume().add_connection_in(plug),
                .Out => try v.as_volume().add_connection_out(plug),
            },
            .Motion => |impl| impl.add_connection(plug),
            .Motion3DOF => |impl| impl.add_connection(plug),
            inline else => {
                std.log.err("Failed to connect [{s}] to [{s}]", .{ plug.name(), socket.name() });
                return errors.JsonFailedConnection;
            },
        };
    }

    for (new_sim_ptr.updatables.items) |obj| try obj.update();

    // Give the world the sim
    return new_sim_ptr;
}

pub fn group_exists(parsed: json.Parsed(json.Value), key: []const u8) !json.Value {
    return parsed.value.object.get(key) orelse {
        errdefer std.log.err("Json does not contain [{s}] please add it", .{key});
        return errors.JsonMissingGroup;
    };
}

pub fn optional_group_exists(parsed: json.Parsed(json.Value), key: []const u8) ?json.Value {
    return parsed.value.object.get(key) orelse return null;
}

pub fn field(allocator: std.mem.Allocator, comptime T: type, comptime S: type, key: []const u8, contents: std.json.Value) !T {
    const object = contents.object.get(key) orelse {
        std.log.err("Attempting to init [{s}] but [{s}] field is missing", .{ @typeName(S), key });
        return errors.JsonObjectFieldMissing;
    };

    const parsed = std.json.parseFromValue(T, allocator, object, .{}) catch {
        std.log.err("Could not parse field [{s}.{s}] check field matches type [{any}]", .{ @typeName(S), key, T });
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    const value = parsed.value;
    return value;
}

pub fn optional_field(allocator: std.mem.Allocator, comptime T: type, comptime S: type, key: []const u8, contents: std.json.Value) !?T {
    const object = contents.object.get(key) orelse return null;

    const parsed = std.json.parseFromValue(T, allocator, object, .{}) catch {
        std.log.err("Could not parse field [{s}.{s}] check field matches type [{any}]", .{ @typeName(S), key, T });
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    const value = parsed.value;
    return value;
}

pub fn string_field(allocator: std.mem.Allocator, comptime S: type, key: []const u8, contents: std.json.Value) ![]const u8 {
    const object = contents.object.get(key) orelse {
        std.log.err("Attempting to init [{s}] but [{s}] field is missing", .{ @typeName(S), key });
        return errors.JsonObjectFieldMissing;
    };

    const parsed = std.json.parseFromValue([]const u8, allocator, object, .{}) catch {
        std.log.err("Could not parse field [{s}.{s}] check field matches type [{any}]", .{ @typeName(S), key, []const u8 });
        return errors.JsonObjectFieldInvalidType;
    };

    defer parsed.deinit();

    return try allocator.dupe(u8, parsed.value);
}
