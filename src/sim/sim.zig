const std = @import("std");
pub const motion = @import("../physics/motion.zig");
pub const forces = @import("../physics/forces.zig");
pub const solvers = @import("../solvers/solvers.zig");
const parse = @import("../config/create_from_json.zig");

pub const SimObject = union(enum) {
    const Self = @This();
    Simple: *forces.Simple,
    Spring: *forces.Spring,
    Integration: solvers.Integration,

    pub fn name(self: *const Self) []const u8 {
        return switch (self.*) {
            .Integration => |impl| return impl.name(),
            inline else => |impl| return impl.name,
        };
    }

    pub fn get_header(self: *const Self) []const []const u8 {
        return switch (self.*) {
            .Simple => return forces.Simple.header[0..],
            .Spring => return forces.Spring.header[0..],
            .Integration => |impl| return impl.get_header(),
        };
    }

    pub fn save_values(self: *const Self, save_array: []f64) void {
        return switch (self.*) {
            inline else => |impl| impl.save_values(save_array),
        };
    }

    pub fn save_len(self: *const Self) usize {
        return switch (self.*) {
            .Simple => return forces.Simple.header.len,
            .Spring => return forces.Spring.header.len,
            .Integration => |impl| return impl.save_len()
        };
    }

    pub fn update(self: *const Self) void {
        return switch (self.*) {
            // Compute values don't require an update function
            .Simple => return,
            .Spring => return,
            inline else => |impl| return impl.update(),
        };
    }

    pub fn next(self: *const Self, dt: f64) void {
        switch (self.*) {
            // Compute values don't require an next function
            .Simple => return,
            .Spring => return,
            .Integration => |impl| {
                impl.rk4(dt);
            },
        }
    }

};

pub const Sim = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    dt: f64,
    time: f64 = 0,
    steps: usize = 0,
    sim_objs: std.ArrayList(SimObject),
    state_names: std.ArrayList([]const u8),
    state_vals: std.ArrayList(f64),

    pub fn init(allocator: std.mem.Allocator, dt: f64) Self {

        if (dt <= 0.0) {
            std.debug.panic("ERROR| dt input must be >= 0", .{});
        }

        return Self{ 
            .allocator = allocator, 
            .dt = dt, 
            .sim_objs = std.ArrayList(SimObject).init(allocator), 
            .state_vals = std.ArrayList(f64).init(allocator), 
            .state_names = std.ArrayList([]const u8).init(allocator) 
        };
    }

    pub fn create(allocator: std.mem.Allocator, dt: f64) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = init(allocator, dt);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self {
        const new = try create(
            allocator,
            parse.field(allocator, f64, "SimOptions", "dt", contents)
        );
        return new;
    }

    pub fn add_obj(self: *Self, obj: SimObject) !void {

        if (self._name_exists(obj.name())){
            std.debug.panic("ERROR| Object Name [{s}] already exists, please remove duplicate", .{obj.name()});
        }

        try self.sim_objs.append(obj);
        for (obj.get_header()) |header| {

            const name: []u8 = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ obj.name(), header });

            try self.state_names.append(name);
            try self.state_vals.append(-404.0);
        }

        obj.save_values(
            self.state_vals.items[(self.state_vals.items.len) - obj.save_len()..]
        );

    }

    pub fn create_obj(self: *Self, obj: SimObject) !void {
        const ptr = try self.allocator.create(SimObject);

        // Enforce copy
        const new_obj = obj;
        ptr.* = new_obj;
        try self.add_obj(ptr.*);
    }

    pub fn step(self: *Self) void {

        var buff_loc: usize = 0;
        for (self.sim_objs.items) |obj| {
            // Go to the next step
            obj.next(self.dt);
            obj.update();

            const len: usize = obj.save_len();

            obj.save_values(self.state_vals.items[buff_loc .. buff_loc + len]);

            buff_loc += len;
        }

        self.time += self.dt;
        self.steps += 1;
    }

    pub fn step_duration(self: *Self, duration: f64) !void{

        if (0.0 > duration){
            std.debug.panic("ERROR| step_duration must be > 0, got [{d}]", .{duration});
        }

        const steps: usize = @intFromFloat(duration / self.dt);
        for (0..steps)|_|{
            self.step();
        }

    }

    pub fn _get_sim_object_by_name(self: *Self, name: []const u8) SimObject{
        for (self.sim_objs.items) |obj|{
            if (std.mem.eql(u8, obj.name(), name)) return obj;
        }
        std.debug.panic("ERROR| Could not find object named [{s}]", .{name});
    }


    pub fn _print_info(self: *Self) void {
        if (self.state_names.items.len != self.state_vals.items.len) {
            std.debug.panic("ERROR| State names of length [{d}] does not match value length [{d}]", .{ self.state_names.items.len, self.state_vals.items.len });
        }
        std.log.info("\n\n", .{});
        std.log.info("Time [s]: {d:0.5}", .{self.time});
        std.log.info("Steps [-]: {d}", .{self.steps});
        for (self.state_names.items, self.state_vals.items) |name, val| {
            std.log.info("{s}: {d:0.4}", .{ name, val });
        }
        std.log.info("\n\n", .{});
    }

    pub fn _name_exists(self: *Self, name1: []const u8) bool{
        for (self.state_names.items) |name2|{
            if (std.mem.eql(u8, name1, name2)) {
                return true;
            }
                
        }

        return false;
    }
};
