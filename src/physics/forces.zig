const std = @import("std");
const sim = @import("../sim/sim.zig");
const motion = @import("motion.zig");
const parse = @import("../config/create_from_json.zig");
const MAX_STATE_LEN = @import("../solvers/solvers.zig").MAX_STATE_LEN;

pub const Force = union(enum) {
    const Self = @This();
    Simple: *Simple,
    Spring: *Spring,

    pub fn get_force(self: *const Force) f64 {
        switch (self.*) {
            .Simple => |f| return f.force,
            inline else => |f| return f.get_force(),
        }
    }

    pub fn init_connection(self: *const Self, connection: *motion.Motion1DOF) void {
        switch (self.*) {
            Force.Simple => |_| return,
            inline else => |f| {
                if (f.position_ptr) |_| {
                    std.debug.panic("ERROR| Object[{s}] is already connected to [{s}]", .{ f.*.name, connection.name });
                } else {
                    f.*.position_ptr = connection;
                }
            },
        }
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
            parse.string_field(allocator, "SpringForce", "name", contents),
            parse.field(allocator, f64, "SpringForce", "preload", contents),
            parse.field(allocator, f64, "SpringForce", "spring_constant", contents),
        );
        return new;
    }

    // =========================================================================
    // Force Methods
    // =========================================================================

    pub fn as_force(self: *Self) Force {
        return Force{ .Spring = self };
    }

    pub fn get_force(self: *Spring) f64 {
        if (self.position_ptr) |ptr| {
            self.force = -self.spring_constant * (ptr.*.pos + self.preload);
            return self.force;
        } else {
            std.debug.panic("ERROR| Object[{s}] is missing a connection", .{self.name});
        }
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Spring = self };
    }

    pub fn save_values(self: *Self, save_array: []f64) void {
        if (save_array.len != Self.header.len) {
            std.debug.panic("ERROR| Save slice length [{d}] != [{d}] for object [{s}]", .{ save_array.len, Self.header.len, self.name });
        }
        save_array[0] = self.spring_constant;
        save_array[1] = self.preload;
        save_array[2] = self.force;
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
            parse.string_field(allocator, "SimpleForce", "name", contents),
            parse.field(allocator, f64, "SimpleForce", "force", contents)
        );
        return new;
    }

    // =========================================================================
    // Force Methods
    // =========================================================================

    pub fn as_force(self: *Self) Force {
        return Force{ .Simple = self };
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Simple = self };
    }

    pub fn save_values(self: *Self, save_array: []f64) void {
        if (save_array.len != Self.header.len) {
            std.debug.panic("ERROR| Save slice length [{d}] != [{d}] for object [{s}]", .{ save_array.len, Self.header.len, self.name });
        }
        save_array[0] = self.force;
    }

};
