const std = @import("std");
const motion = @import("../Physics/Motion.zig");
const solvers = @import("../Solvers/Solvers.zig");

pub const SimObject = union(enum) {
    Motion1DOF: *const motion.Motion1DOF,

    fn save_values(self: *SimObject) []const f64 {
        return switch (self.*) {
            inline else => |impl| return impl.save_values(),
        };
    }

    fn update(self: *SimObject) void {
        switch (self.*) {
            inline else => |impl| impl.update(),
        }
    }
};

pub const Sim = struct {
    const Self = @This();
    dt: f64,
    sim_objs: std.ArrayList(*SimObject),
    state_vals: std.ArrayList(f64),

    pub fn init(allocator: std.mem.Allocator, dt: f64) Self {
        return Self{
            .dt = dt,
            .sim_objs = std.ArrayList(*SimObject).init(allocator),
            .state_vals = std.ArrayList(f64).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.sim_objs.deinit();
        self.state_vals.deinit();
    }

    pub fn add_obj(self: *Self, obj: *SimObject) !void {
        try self.sim_objs.append(obj);
        for (obj.save_values()) |vals| {
            std.log.info("{any}", .{vals});
            try self.state_vals.append(vals);
        }
    }
};
