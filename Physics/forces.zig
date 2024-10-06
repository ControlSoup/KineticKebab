const std = @import("std");
const sim = @import("../Sim/sim.zig");
const motion = @import("motion.zig");
const MAX_STATE_LEN = @import("../Solvers/solvers.zig").MAX_STATE_LEN;

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

    pub fn init_connection(self: *const Force, connection: *motion.Motion1DOF) void {
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

    save_len: usize = 3,
    name: []const u8,
    spring_constant: f64,
    preload: f64,
    force: f64 = 0,
    position_ptr: ?*motion.Motion1DOF = null,

    pub fn init(name: []const u8, preload: f64, spring_constant: f64) Self {
        return Spring{ .name = name, .preload = preload, .spring_constat = spring_constant };
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

    pub fn get_header(self: *Self) []const []const u8 {
        _ = self;
        const save = [_][]const u8{ "spring_constant [N/m]", "preload [m]", "force [N]" };
        return save[0..];
    }

    pub fn save_values(self: *Self, save_array: []f64) void {
        if (save_array.len != self.save_len) {
            std.debug.panic("ERROR| Save slice length [{d}] != [{d}] for object [{s}]", .{ save_array.len, self.save_len, self.name });
        }
        save_array[0] = self.spring_constant;
        save_array[1] = self.preload;
        save_array[2] = self.force;
    }
};

pub const Simple = struct {
    const Self = @This();

    save_len: usize = 1,
    name: []const u8,
    force: f64,

    // =========================================================================
    // Force Methods
    // =========================================================================

    pub fn as_force(self: *Self) Force {
        return Force{ .Simple = self };
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn get_header(self: *Self) []const []const u8 {
        _ = self;
        const save = [_][]const u8{"force [N]"};
        return save[0..];
    }

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .Simple = self };
    }

    pub fn save_values(self: *Self, save_array: []f64) void {
        if (save_array.len != self.save_len) {
            std.debug.panic("ERROR| Save slice length [{d}] != [{d}] for object [{s}]", .{ save_array.len, self.save_len, self.name });
        }
        save_array[0] = self.force;
    }
};
