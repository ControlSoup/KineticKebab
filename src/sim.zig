const std = @import("std");
pub const math = @import("math/math.zig");
pub const solvers = @import("solvers/solvers.zig");
pub const motions = @import("physics/motions/motions.zig");
pub const forces = @import("physics/forces/forces.zig");
pub const intrinsic = @import("fluids/intrinsic.zig");
pub const volumes = @import("fluids/volumes.zig");
pub const restrictions = @import("fluids/restrictions.zig");
pub const parse = @import("config/create_from_json.zig");
pub const recorder = @import("recorder.zig");

pub const errors = parse.errors || error{
    SimObjectDuplicate,
    SimObjectDoesNotExist,
    InputLessThanZero,
    InvalidInput,
    AlreadyConnected,
    MissingConnection 
};

pub const SimObject = union(enum) {
    const Self = @This();

    Restriction: restrictions.Restriction,
    Force1DOF: forces.d1.Force,
    Force2DOF: forces.d2.Force,
    Integration: solvers.Integration,
    SimInfo: *Sim,

    pub fn name(self: *const Self) []const u8 {
        return switch (self.*) {
            .SimInfo => Sim.sim_name,
            inline else => |impl| return impl.name()
        };
    }

    pub fn get_header(self: *const Self) []const []const u8 {
        return switch (self.*) {
            .SimInfo => Sim.sim_header[0..],
            inline else => |impl| return impl.get_header(),
        };
    }

    pub fn save_len(self: *const Self) usize {
        return switch (self.*) {
            .SimInfo => Sim.sim_header.len,
            inline else => |impl| return impl.save_len()
        };
    }

    pub fn save_values(self: *const Self, save_array: []f64) void {
        return switch (self.*) {
            .SimInfo => |impl| {
                save_array[0] = @as(f64, @floatFromInt(impl.steps));
                save_array[1] = impl.dt;
                save_array[2] = impl.time;
            },
            inline else => |impl| impl.save_values(save_array),
        };
    }

    pub fn update(self: *const Self) !void {
        return switch (self.*) {
            .Integration => |impl| impl.update(),
            inline else => return,
        };
    }

    pub fn next(self: *const Self, dt: f64) !void {
        try switch (self.*) {
            .Integration => |impl| impl.rk4(dt),
            inline else => return,
        };
    }

};

pub const Sim = struct {
    const Self = @This();
    const sim_header = [3][]const u8{"steps [-]", "dt [s]", "time [s]"};
    const sim_name = "sim";

    allocator: std.mem.Allocator,
    dt: f64,
    time: f64 = 0,
    steps: usize = 0,
    sim_objs: std.ArrayList(SimObject),
    state_names: std.ArrayList([]const u8),
    state_vals: std.ArrayList(f64),
    storage: ?*recorder.SimRecorder = null,

    pub fn init(allocator: std.mem.Allocator, dt: f64) !Self {

        if (dt <= 0.0) {
            std.log.err("ERROR| dt input must be >= 0", .{});
            return errors.InputLessThanZero;
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
        ptr.* = try init(allocator, dt);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self {
        const new = try create(
            allocator,
            try parse.field(allocator, f64, Self, "dt", contents)
        );
        return new;
    }

    pub fn add_obj(self: *Self, obj: SimObject) !void {

        try self._name_exists(obj.name());

        try self.sim_objs.append(obj);
        for (obj.get_header()) |header| {

            const name: []u8 = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ obj.name(), header });

            try self.state_names.append(name);
            try self.state_vals.append(-404.0);
        }
        obj.save_values(
            self.state_vals.items[(self.state_vals.items.len - obj.save_len())..]
        );
    }

    pub fn create_obj(self: *Self, obj: SimObject) !void {
        const ptr = try self.allocator.create(SimObject);

        // Enforce copy
        const new_obj = obj;
        ptr.* = new_obj;
        try self.add_obj(ptr.*);
    }

    pub fn step(self: *Self) !void {

        var buff_loc: usize = 0;
        for (self.sim_objs.items) |obj| {
            // Go to the next step
            try obj.next(self.dt);
            try obj.update();

            const len: usize = obj.save_len();
            const save_buffer = self.state_vals.items[buff_loc .. buff_loc + len];

            // Ensures I don't need to check every method for length....less verbose more clunky
            try std.testing.expect(save_buffer.len == obj.save_len());
            obj.save_values(save_buffer);

            buff_loc += len;
        }

        if (self.storage != null){
            try self.storage.?.write_row(self.state_vals.items);
        }

        self.time += self.dt;
        self.steps += 1;

    }

    pub fn step_duration(self: *Self, duration: f64) !void{

        if (0.0 > duration){
            std.log.err("ERROR| step_duration must be > 0, got [{d}]", .{duration});
            return errors.InputLessThanZero;
        }

        const steps: usize = @intFromFloat(duration / self.dt);
        for (0..steps)|_|{
            try self.step();
        }

    }

    pub fn get_save_index(self: *Self, name: [] const u8) !usize{
    
        for (self.state_names.items, 0..) |obj, i|{
            if (std.mem.eql(u8, obj, name)) return i;
        }

        std.log.err("ERROR| Could not find index with object.save named [{s}]", .{name});
        return errors.SimObjectDoesNotExist;
    }

    pub fn get_save_value_by_name(self: *Self, name: []const u8) !f64{
        const index = try self.get_save_index(name);
        return self.state_vals.items[index];
    }

    pub fn get_sim_object_by_name(self: *Self, name: []const u8) !SimObject{

        for (self.sim_objs.items) |obj|{
            if (std.mem.eql(u8, obj.name(), name)) return obj;
        }

        std.log.err("ERROR| Could not find object named [{s}]", .{name});
        return errors.SimObjectDoesNotExist;
    }

    pub fn create_recorder(self: *Self, file_path: []const u8, pool_time: f64) !void{
        const pool_len = @as(usize, @intFromFloat(pool_time / self.dt));
        self.storage = try recorder.SimRecorder.create(self.allocator, file_path, self.state_names.items, pool_len);
    }

    pub fn create_recorder_from_json(self: *Self, contents: std.json.Value) !void{
        try create_recorder(
            self, 
            try parse.string_field(self.allocator, Self, "path", contents), 
            try parse.field(self.allocator, f64, Self, "time_window", contents),
        );
    }

    pub fn as_sim_object(self: *Self) SimObject{
        return SimObject{.SimInfo =  self};
    }

    pub fn _print_info(self: *Self) void {
        std.log.err("\n\nTime [s]: {d:0.5}", .{self.time});
        std.log.err("Steps [-]: {d}", .{self.steps});
        for (self.state_names.items, self.state_vals.items) |name, val| {
            std.log.err("{s}: {d:0.4}", .{ name, val });
        }
    }

    pub fn _name_exists(self: *Self, name1: []const u8) !void{
        for (self.state_names.items) |name2|{
            if (std.mem.eql(u8, name1, name2)) {
                std.log.err("ERROR| Object Name [{s}] already exists, please remove duplicate", .{name1});
                return errors.SimObjectDuplicate;
            }
        }            
    }
};

test {
    _ = @import("_model_tests/tests.zig");
    std.testing.refAllDecls(@This());
}