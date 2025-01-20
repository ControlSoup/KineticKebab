const std = @import("std");
const sim = @import("../../sim.zig");
const MAX_STATE_LEN = sim.solvers.MAX_STATE_LEN;

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

    pub fn add_connection(self: *const Self, connection: *sim.motions.d1.Motion) !void {
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
};

pub const Spring = struct {
    const Self = @This();
    pub const header: [3][]const u8 = [3][]const u8{ "spring_constant [N/m]", "preload [m]", "force [N]" };

    name: []const u8,
    spring_constant: f64,
    preload: f64,
    force: f64 = 0,
    position_ptr: ?*sim.motions.d1.Motion = null,

    pub fn init(name: []const u8, preload: f64, spring_constant: f64) Self {
        return Spring{ .name = name, .preload = preload, .spring_constant = spring_constant };
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8, preload: f64, spring_constant: f64) !*Spring {
        const ptr  = try allocator.create(Spring);
        ptr.* =  init(name, preload, spring_constant);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Spring {
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "preload", contents),
            try sim.parse.field(allocator, f64, Self, "spring_constant", contents),
        );
    }

    // =========================================================================
    // Force Methods
    // =========================================================================

    pub fn get_force(self: *Spring) !f64 {

        if (self.position_ptr == null){
            std.log.err("ERROR| Object[{s}] is missing a connection", .{self.name});
            return sim.errors.MissingConnection; 
        }

        self.force = -self.spring_constant * (self.position_ptr.?.*.pos + self.preload);
        return self.force;
    }

    // =========================================================================
    // Interfaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{.Spring1DOF = self };
    }

    pub fn as_force(self: *Self) Force{
        return Force{.Spring = self };
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *Self, save_array: []f64) void {
        save_array[0] = self.spring_constant;
        save_array[1] = self.preload;
        save_array[2] = self.force;
    }
    
    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.spring_constant = save_array[0] ;
        self.preload = save_array[1] ;
        self.force = save_array[2] ;
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

    pub fn create(allocator: std.mem.Allocator, name:[]const u8, force: f64) !*Self{
        const ptr = try allocator.create(Simple);
        ptr.* = init(name, force);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "force", contents)
        );
    }

    // =========================================================================
    // Interfaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{.Simple1DOF = self};
    }

    pub fn as_force(self: *Self) Force{
        return Force{.Simple = self};
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *Self, save_array: []f64) void {
        save_array[0] = self.force;
    }

    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.force = save_array[0] ;
    }
};
