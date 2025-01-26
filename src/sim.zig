const std = @import("std");
pub const parse = @import("config/create_from_json.zig");

// Helpers
pub const math = @import("math/math.zig");
pub const coolprop = @import("3rdparty/coolprop.zig");
pub const intrinsic = @import("fluids/intrinsic.zig");
pub const recorder = @import("recorder.zig");

// Objects
pub const forces = @import("physics/forces/forces.zig");
pub const motions = @import("physics/motions/motions.zig");
pub const volumes = @import("fluids/volumes.zig");
pub const restrictions = @import("fluids/restrictions.zig");

// Interfaces
pub const interfaces = @import("interfaces/interfaces.zig");

pub const errors = parse.errors || error{
    SimObjectDuplicate,
    SimObjectDoesNotExist,
    InputLessThanZero,
    InvalidInput,
    AlreadyConnected,
    MissingConnection,
    MismatchedLength,
    CannotSet,
    InvalidInterface
};

pub const SimObject = union(enum) {
    const Self = @This();

    // Fluids
    ConstantMdot: *restrictions.ConstantMdot,
    Orifice: *restrictions.Orifice,
    Void: *volumes.Void,
    Static: *volumes.Static,

    // 1DOF
    Simple1DOF: *forces.d1.Simple,
    Spring1DOF: *forces.d1.Spring,
    Motion1DOF: *motions.d1.Motion,

    // 3DOF
    Simple3DOF: *forces.d3.Simple,
    BodySimple3DOF: *forces.d3.BodySimple,
    Motion3DOF: *motions.d3.Motion,

    // Sim
    SimInfo: *Sim,

    pub fn as_restriction(self: *const Self) !restrictions.Restriction {
        return switch (self.*){
            .Orifice => |impl| impl.as_restriction(),
            .ConstantMdot => |impl| impl.as_restriction(),
            inline else => errors.InvalidInterface
        };
    }

    pub fn as_d1force(self: *const Self) !forces.d1.Force{
        return switch (self.*){
            .Simple1DOF => |impl| impl.as_force(),
            .Spring1DOF => |impl| impl.as_force(),
            inline else => errors.InvalidInterface
        };
    }

    pub fn as_d3force(self: *const Self) !forces.d3.Force{
        return switch (self.*){
            // 3DOF
            .Simple3DOF => |impl| impl.as_force(),
            .BodySimple3DOF => |impl| impl.as_force(),
            inline else => errors.InvalidInterface
        };
    }

    pub fn name(self: *const Self) []const u8 {
        return switch (self.*) {
            .SimInfo => Sim.sim_name,
            inline else => |impl| impl.name,
        };
    }

    pub fn get_header(self: *const Self) []const []const u8 {
        return switch (self.*) {
            .SimInfo => Sim.sim_header[0..],

            // Fluids
            .ConstantMdot => restrictions.ConstantMdot.header[0..],
            .Orifice => restrictions.Orifice.header[0..],
            .Void => volumes.Void.header[0..],
            .Static => volumes.Static.header[0..],

            // 1DOF
            .Simple1DOF => forces.d1.Simple.header[0..],
            .Spring1DOF => forces.d1.Spring.header[0..],
            .Motion1DOF => motions.d1.Motion.header[0..],

            // 3DOF
            .Simple3DOF => forces.d3.Simple.header[0..],
            .BodySimple3DOF => forces.d3.BodySimple.header[0..],
            .Motion3DOF => motions.d3.Motion.header[0..]
        };
    }

    pub fn save_len(self: *const Self) usize {
        return switch (self.*) {
            .SimInfo => Sim.sim_header.len,

            // Fluids
            .ConstantMdot => restrictions.ConstantMdot.header.len,
            .Orifice => restrictions.Orifice.header.len,
            .Void => volumes.Void.header.len,
            .Static => volumes.Static.header.len,

            // 1DOF
            .Simple1DOF => forces.d1.Simple.header.len,
            .Spring1DOF => forces.d1.Spring.header.len,
            .Motion1DOF => motions.d1.Motion.header.len,

            // 3DOF
            .Simple3DOF => forces.d3.Simple.header.len,
            .BodySimple3DOF => forces.d3.BodySimple.header.len,
            .Motion3DOF => motions.d3.Motion.header.len
        };
    }

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        return switch (self.*) {
            .SimInfo => |impl| {
                save_array[0] = @as(f64, @floatFromInt(impl.steps));
                save_array[1] = impl.dt;
                save_array[2] = impl.time;
                save_array[3] = impl.curr_rel_err;
            },
            inline else => |impl| impl.save_vals(save_array),
        };
    }

    pub fn set_vals(self: *const Self, save_array: []f64) !void {
        return switch (self.*) {
            .SimInfo => |impl| {
                impl.time = save_array[2];
            },
            inline else => |impl| impl.set_vals(save_array),
        };
    }

    // Method to dynamically check method avaliblity? Might work?
    //
    // inline else => |impl| blk: {
    // if (@hasDecl(@TypeOf(impl), "as_restriction")) {
    //     break :blk impl.as_restriction();
    // }
    // break :blk error.InvalidInterface;
    //}
    // 


};

pub const Sim = struct {
    const Self = @This();
    const sim_header = [_][]const u8{"steps [-]", "dt [s]", "time [s]", "integration_error [-]"};
    const sim_name = "sim";

    allocator: std.mem.Allocator,
    dt: f64,
    next_dt: f64,
    max_dt: f64,
    min_dt: f64,
    err_allow: f64,
    curr_rel_err: f64 = 0.0,

    enforce_current_dt: bool = false,
    time: f64 = 0.0,
    steps: usize = 0,

    sim_objs: std.ArrayList(SimObject),
    integrator: interfaces.Integrator, 
    updatables: std.ArrayList(interfaces.Updatable),

    state_names: std.ArrayList([]const u8),
    state_vals: std.ArrayList(f64),
    storage: ?*recorder.SimRecorder = null,
    updated_vals: bool = false,

    // Sim Init

    pub fn init(allocator: std.mem.Allocator, dt: f64, max_dt: f64, min_dt: f64, err_allow: f64) !Self {

        if (dt <= 0.0) {
            std.log.err("ERROR| dt input must be >= 0", .{});
            return errors.InputLessThanZero;
        }

        return Self{ 
            .allocator = allocator, 
            .dt = dt, 
            .next_dt = dt, 
            .max_dt = max_dt,
            .min_dt = min_dt,
            .err_allow = err_allow,
            .sim_objs = std.ArrayList(SimObject).init(allocator), 
            .updatables = std.ArrayList(interfaces.Updatable).init(allocator), 
            .state_vals = std.ArrayList(f64).init(allocator), 
            .state_names = std.ArrayList([]const u8).init(allocator),
            .integrator = interfaces.Integrator.init(allocator)
        };
    }

    pub fn create(allocator: std.mem.Allocator, dt: f64, max_dt: f64, min_dt: f64, err_allow: f64) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, dt, max_dt, min_dt, err_allow);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self {
        const new = try create(
            allocator,
            try parse.field(allocator, f64, Self, "dt", contents),
            try parse.optional_field(allocator, f64, Self, "max_dt", contents) orelse 1.0,
            try parse.optional_field(allocator, f64, Self, "min_dt", contents) orelse 1e-3,
            try parse.optional_field(allocator, f64, Self, "allowable_error", contents) orelse 1e-6,
        );
        return new;
    }

    // TODO: Move to record method
    pub fn create_recorder_from_json(self: *Self, contents: std.json.Value) !void{
        self.storage = try recorder.SimRecorder.create(
            self.allocator, 
            try parse.string_field(self.allocator, Self, "path", contents), 
            self.state_names.items,
            try parse.optional_field(self.allocator, usize, Self, "pool_length", contents) orelse 25,
            try parse.optional_field(self.allocator, f64, Self, "min_dt", contents) orelse 1e-3,
        );
    }

    // Adding Objects
    pub fn add_sim_obj(self: *Self, obj: SimObject) !void {

        try self._name_exists(obj.name());

        try self.sim_objs.append(obj);
        for (obj.get_header()) |header| {

            const name: []u8 = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ obj.name(), header});

            try self.state_names.append(name);
            try self.state_vals.append(-404.0);
        }
        obj.save_vals(
            self.state_vals.items[(self.state_vals.items.len - obj.save_len())..]
        );
    }

    pub fn add_updateable(self: *Self, updateable: interfaces.Updatable) !void {
        try self.updatables.append(updateable);
    }

    pub fn add_integratable(self: *Self, integratable: interfaces.Integratable) !void{
        try self.integrator.add_obj(integratable);
    }

    // Using the sim

    pub fn step(self: *Self) !void {

        if (self.updated_vals){
            try self._set_vals();
            self.updated_vals = false;
        }

        const rk45_results = try self.integrator.integrate(
            self.next_dt, 
            self.max_dt, 
            self.min_dt, 
            self.err_allow,
            self.curr_rel_err,
            self.enforce_current_dt 
        );

        self.dt = rk45_results.accepted_dt;
        self.time += self.dt;
        self.curr_rel_err = rk45_results.curr_rel_err;
        self.next_dt = rk45_results.dt;
        self.steps += 1;

        try self._save_vals();
    }

    pub fn step_duration(self: *Self, duration: f64) !void{

        if (0.0 > duration){
            std.log.err("ERROR| step_duration must be > 0, got [{d}]", .{duration});
            return errors.InputLessThanZero;
        }

        const start = self.time;
        while((self.time - start) < duration){
            try self.step();

            if (self.next_dt + (self.time - start) > duration){
                const stash_dt = self.next_dt;
                self.next_dt = duration - (self.time - start);  

                if (self.next_dt < 1e-10) break;
                self.enforce_current_dt = true;
                try self.step();
                self.next_dt = stash_dt;
                self.enforce_current_dt = false;
            }

        }

    }

    pub fn end(self: *Self) !void{
        if (self.storage != null) {
            try self.storage.?.write_remaining(self.state_vals.items);
            try self.storage.?.compress();
        }
    }

    // Sim API
    pub fn get_index(self: *Self, name: [] const u8) !usize{
    
        for (self.state_names.items, 0..) |obj, i|{
            if (std.mem.eql(u8, obj, name)) return i;
        }

        std.log.err("ERROR| Could not find index with object.save named [{s}]", .{name});
        return errors.SimObjectDoesNotExist;
    }

    pub fn get_value_by_name(self: *Self, name: []const u8) !f64{
        // You usually have <50 items in a sim, so linear serach is fine
        const index = try self.get_index(name);
        return self.state_vals.items[index];
    }

    pub fn get_sim_object_by_name(self: *Self, name: []const u8) !SimObject{

        for (self.sim_objs.items) |obj|{
            if (std.mem.eql(u8, obj.name(), name)) return obj;
        }

        std.log.err("ERROR| Could not find object named [{s}]", .{name});
        return errors.SimObjectDoesNotExist;
    }

    pub fn set_value(self: *Self, idx: usize, value: f64) !void{
        if (idx < 0 or idx > self.state_vals.items.len - 1){
            std.log.err("ERROR| When setting a value, indx must be >= 0 and less then {d}", .{self.state_vals.items.len - 1}); 
            return errors.InvalidInput;
        }
        self.state_vals.items[idx] = value;
        self.updated_vals = true;
    }

    pub fn set_value_by_name(self: *Self, name: []const u8, value: f64) !void{
        const idx = try self.get_index(name); 
        try self.set_value(idx, value);
    }

    pub fn as_sim_object(self: *Self) SimObject{
        return SimObject{.SimInfo =  self};
    }

    // Private / Dev Methods

    pub fn _print_info(self: *Self) void {
        std.log.err("\n\nTime [s]: {d:0.5}", .{self.time});
        std.log.err("Steps [-]: {d}", .{self.steps});
        for (self.state_names.items, self.state_vals.items) |name, val| {
            std.log.err("{s}: {d:0.4}", .{ name, val });
        }
    }

    fn _name_exists(self: *Self, name1: []const u8) !void{
        for (self.state_names.items) |name2|{
            if (std.mem.eql(u8, name1, name2)) {
                std.log.err("ERROR| Object Name [{s}] already exists, please remove duplicate", .{name1});
                return errors.SimObjectDuplicate;
            }
        }            
    }

    fn _save_vals(self: *Self) !void{
        var buff_loc: usize = 0;

        for (self.updatables.items) |obj|{
            try obj.update();
        }

        for (self.sim_objs.items) |obj|{

            const len: usize = obj.save_len();

            const save_buffer = self.state_vals.items[buff_loc .. buff_loc + len];

            // Ensures I don't need to check every method for length
            try std.testing.expect(save_buffer.len == obj.save_len());

            obj.save_vals(save_buffer);

            buff_loc += len;

        }

        if (self.storage) |storage|{
            try storage.write_row(self.state_vals.items, self.time);
        }
    }

    fn _set_vals(self: *Self) !void{
        var buff_loc: usize = 0;
        for (self.sim_objs.items) |obj|{

            const len: usize = obj.save_len();

            const save_buffer = self.state_vals.items[buff_loc .. buff_loc + len];

            try obj.set_vals(save_buffer[0..]);

            // Ensures I don't need to check every method for length
            try std.testing.expect(save_buffer.len == obj.save_len());

            buff_loc += len;
        }

        for (self.updatables.items) |obj| {
            try obj.update();
        }
    }

};

test {
    std.testing.refAllDecls(@This());
}