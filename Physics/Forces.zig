const std = @import("std");
const sim = @import("../Sim/sim.zig");
const motion = @import("Motion.zig");

pub const Force = union(enum) {
    const Self = @This();
    Simple: *const Simple,
    Spring: *const Spring,

    pub fn get_force(self: *Force) f64 {
        switch (self.*) {
            .Simple => |f| return f.force,
            .Spring => |f| return f.spring_force(),
        }
    }

    pub fn init_connection(self: *Force, connection: *motion.Motion1DOF) void {
        switch (self.*) {
            Force.Simple => |_| return,
            Force.Spring => |*f| {
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
    name: []const u8,
    spring_constant: f64,
    preload: f64,
    position_ptr: ?*motion.Motion1DOF = null,

    pub fn as_force(self: *Self) Force {
        return Force{ .Spring = self };
    }

    pub fn spring_force(self: Spring) f64 {
        if (self.position_ptr) |ptr| {
            return -self.spring_constant * (ptr.*.pos + self.preload);
        } else {
            std.debug.panic("ERROR| Object[{s}] is missing a connection", .{self.name});
        }
    }
};

pub const Simple = struct {
    const Self = @This();
    name: []const u8,
    force: f64,

    pub fn as_force(self: *Self) Force {
        return Force{ .Simple = self };
    }
};
