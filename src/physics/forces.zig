const std = @import("std");
const sim = @import("../sim/sim.zig");
const motion = @import("motion.zig");
const parse = @import("../config/create_from_json.zig");
const MAX_STATE_LEN = @import("../solvers/solvers.zig").MAX_STATE_LEN;

pub const Force = union(enum) {
    const Self = @This();
    Simple: *Simple,
    Spring: *Spring,

    pub fn get_force(self: *const Force) !f64 {
        switch (self.*) {
            .Simple => |f| return f.force,
            inline else => |f| return f.get_force(),
        }
    }

    pub fn init_connection(self: *const Self, connection: *motion.Motion1DOF) !void {
        switch (self.*) {
            Force.Simple => |_| return,
            inline else => |f| {
                if (f.position_ptr) |_| {
                    std.log.err("ERROR| Object[{s}] is already connected to [{s}]", .{ f.*.name, connection.name });
                    return sim.errors.AlreadyConnected;
                } else {
                    f.*.position_ptr = connection;
                }
            },
        }
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn name(self: *const Self) []const u8{
        return switch (self.*){
            inline else => |impl| impl.name,
        };
    }

    pub fn get_header(self: *const Self) []const []const u8{
        return switch (self.*){
            .Simple => return Simple.header[0..],
            .Spring => return Spring.header[0..],
        };
    }

    pub fn save_values(self: *const Self, save_array: []f64) void {
        switch (self.*){
            inline else => |impl| impl.save_values(save_array),
        }
    }

    pub fn save_len(self: *const Self) usize{
        return switch (self.*) {
            .Simple => return Simple.header.len,
            .Spring => return Spring.header.len,
        };
    }

};

pub const Spring = struct {
    const Self = @This();
    pub const header: [3][]const u8 = [3][]const u8{ "spring_constant [N/m]", "preload [m]", "force [N]" };

    name: []const u8,
    spring_constant: f64,
    preload: f64,
    force: f64 = 0,
    position_ptr: ?*motion.Motion1DOF = null,

    pub fn init(name: []const u8, preload: f64, spring_constant: f64) Self {
        return Spring{ .name = name, .preload = preload, .spring_constant = spring_constant };
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8, preload: f64, spring_constant: f64) !*Spring {
        const ptr  = try allocator.create(Spring);
        ptr.* =  init(name, preload, spring_constant);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Spring {
        const new = create(
            allocator,
            try parse.string_field(allocator, "SpringForce", "name", contents),
            try parse.field(allocator, f64, "SpringForce", "preload", contents),
            try parse.field(allocator, f64, "SpringForce", "spring_constant", contents),
        );
        return new;
    }

    // =========================================================================
    // Force Methods
    // =========================================================================

    pub fn get_force(self: *Spring) !f64 {
        if (self.position_ptr) |ptr| {
            self.force = -self.spring_constant * (ptr.*.pos + self.preload);
            return self.force;
        } else {
            std.log.err("ERROR| Object[{s}] is missing a connection", .{self.name});
            return sim.errors.AlreadyConnected; 
        }
    }

    pub fn save_values(self: *Self, save_array: []f64) void {
        save_array[0] = self.spring_constant;
        save_array[1] = self.preload;
        save_array[2] = self.force;
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Force = Force{.Spring = self }};
    }

};

pub const Simple = struct {
    const Self = @This();
    pub const header: [1][]const u8 = [1][]const u8{"force [N]"};

    name: []const u8,
    force: f64,

    pub fn init(name:[] const u8, force: f64) Self{
        return Simple{.name = name, .force = force};
    }

    pub fn create(allocator: std.mem.Allocator, name:[] const u8, force: f64) !*Self{
        const ptr = try allocator.create(Simple);
        ptr.* = init(name, force);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        const new = try create(
            allocator,
            try parse.string_field(allocator, "SimpleForce", "name", contents),
            try parse.field(allocator, f64, "SimpleForce", "force", contents)
        );
        std.log.info("{s}", .{new.name});
        return new;
    }

    // =========================================================================
    // Force Methods
    // =========================================================================

    pub fn save_values(self: *Self, save_array: []f64) void {
        save_array[0] = self.force;
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Force = Force{.Simple = self }};
    }


};
