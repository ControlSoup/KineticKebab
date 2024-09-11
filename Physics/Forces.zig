const std = @import("std");
pub const Motion1DOF = @import("Motion.zig").Motion1DOF;

pub const Force = union(enum) {
    Simple: Simple,
    Spring: Spring,

    pub fn get_force(self: Force) f64 {
        switch (self) {
            .Simple => |f| return f.force,
            .Spring => |f| return f.spring_force(),
        }
    }

    pub fn init_connection(self: *Force, connection: *Motion1DOF) void {
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
    name: []const u8,
    spring_constant: f64,
    preload: f64,
    position_ptr: ?*Motion1DOF = null,

    pub fn spring_force(self: Spring) f64 {
        if (self.position_ptr) |ptr| {
            return -self.spring_constant * (ptr.*.pos + self.preload);
        } else {
            std.debug.panic("ERROR| Object[{s}] is missing a connection", .{self.name});
        }
    }
};

pub const Simple = struct { name: []const u8, force: f64 };
