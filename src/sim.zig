const std = @import("std");
pub const parse = @import("config/create_from_json.zig");

// Helpers
pub const math = @import("math/math.zig");
pub const coolprop = @import("3rdparty/coolprop.zig");
pub const intrinsic = @import("fluids/intrinsic.zig");

pub const interfaces = @import("interfaces/interfaces.zig");
pub const fluids_equations = @import("fluids/equations/equations.zig");

// Objects
pub const forces = @import("physics/forces/forces.zig");
pub const motions = @import("physics/motions/motions.zig");
pub const volumes = @import("fluids/volumes.zig");
pub const restrictions = @import("fluids/restrictions.zig");

pub const errors = parse.errors || error{
    SimObjectDuplicate,
    SimObjectDoesNotExist,
    InputLessThanZero,
    InvalidInput,
    AlreadyConnected,
    MissingConnection,
    MismatchedLength,
    CannotSet,
    InvalidInterface,
    ConvergenceError
};

pub const SimObject = union(enum) {
    const Self = @This();

    // Fluids
    ConstantMdot: *restrictions.ConstantMdot,
    Orifice: *restrictions.Orifice,
    VoidVolume: *volumes.VoidVolume,
    StaticVolume: *volumes.StaticVolume,
    SteadyVolume: *volumes.SteadyVolume,

    // 1DOF
    SimpleForce: *forces.d1.Simple,
    SpringForce: *forces.d1.Spring,
    Motion: *motions.d1.Motion,

    // 3DOF
    SimpleForce3DOF: *forces.d3.Simple,
    BodySimpleForce3DOF: *forces.d3.BodySimple,
    Motion3DOF: *motions.d3.Motion,

    // Sim
    SimInfo: *Sim,

    // Integrator
    Integrator: *interfaces.Integrator,

    pub fn as_restriction(self: *const Self) !restrictions.Restriction {
        return switch (self.*){
            .Orifice => |impl| impl.as_restriction(),
            .ConstantMdot => |impl| impl.as_restriction(),
            inline else => errors.InvalidInterface
        };
    }

    pub fn as_d1force(self: *const Self) !forces.d1.Force{
        return switch (self.*){
            .SimpleForce => |impl| impl.as_force(),
            .SpringForce => |impl| impl.as_force(),
            inline else => errors.InvalidInterface
        };
    }

    pub fn as_d3force(self: *const Self) !forces.d3.Force{
        return switch (self.*){
            // 3DOF
            .SimpleForce3DOF => |impl| impl.as_force(),
            .BodySimpleForce3DOF => |impl| impl.as_force(),
            inline else => errors.InvalidInterface
        };
    }

    pub fn name(self: *const Self) []const u8 {
        return switch (self.*) {
            .SimInfo => Sim.sim_name,
            .Integrator => interfaces.Integrator.name,
            inline else => |impl| impl.name,
        };
    }

    pub fn get_header(self: *const Self) []const []const u8 {
        return switch (self.*) {

            // Fluids
            .ConstantMdot => restrictions.ConstantMdot.header[0..],
            .Orifice => restrictions.Orifice.header[0..],
            .VoidVolume => volumes.VoidVolume.header[0..],
            .StaticVolume => volumes.StaticVolume.header[0..],
            .SteadyVolume => volumes.SteadyVolume.header[0..],

            // 1DOF
            .SimpleForce => forces.d1.Simple.header[0..],
            .SpringForce => forces.d1.Spring.header[0..],
            .Motion => motions.d1.Motion.header[0..],

            // 3DOF
            .SimpleForce3DOF => forces.d3.Simple.header[0..],
            .BodySimpleForce3DOF => forces.d3.BodySimple.header[0..],
            .Motion3DOF => motions.d3.Motion.header[0..],

            // Misc
            .SimInfo => Sim.sim_header[0..],
            .Integrator => interfaces.Integrator.header[0..],
        };
    }

    pub fn save_len(self: *const Self) usize {
        return switch (self.*) {

            // Fluids
            .ConstantMdot => restrictions.ConstantMdot.header.len,
            .Orifice => restrictions.Orifice.header.len,
            .VoidVolume => volumes.VoidVolume.header.len,
            .StaticVolume => volumes.StaticVolume.header.len,
            .SteadyVolume => volumes.SteadyVolume.header.len,

            // 1DOF
            .SimpleForce => forces.d1.Simple.header.len,
            .SpringForce => forces.d1.Spring.header.len,
            .Motion => motions.d1.Motion.header.len,

            // 3DOF
            .SimpleForce3DOF => forces.d3.Simple.header.len,
            .BodySimpleForce3DOF => forces.d3.BodySimple.header.len,
            .Motion3DOF => motions.d3.Motion.header.len,

            //Misc
            .SimInfo => Sim.sim_header.len,
            .Integrator => interfaces.Integrator.header.len,
        };
    }

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        return switch (self.*) {
            .SimInfo => |impl| {
                save_array[0] = @as(f64, @floatFromInt(impl.steady_steps));
                save_array[1] = @as(f64, @floatFromInt(impl.transient_steps));
                save_array[2] = impl.time;
            },
            inline else => |impl| impl.save_vals(save_array),
        };
    }

    pub fn set_vals(self: *const Self, save_array: []f64) !void {
        return switch (self.*) {
            .SimInfo => |impl| {
                impl.time = save_array[1];
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
    const sim_name = "sim";
    const sim_header = [_][]const u8{"steady_steps [-]", "transient_steps [-]", "time [s]"};

    allocator: std.mem.Allocator,

    time: f64 = 0.0,
    transient_steps: usize = 0,

    sim_objs: std.ArrayList(SimObject),
    integrator: *interfaces.Integrator, 
    max_iter: usize,
    updatables: std.ArrayList(interfaces.Updatable),

    steady: interfaces.SteadySolver,
    steady_steps: usize = 0,

    state_names: std.ArrayList([]const u8),
    state_vals: std.ArrayList(f64),
    updated_vals: bool = false,

    // Sim Init

    pub fn init(allocator: std.mem.Allocator, integrator: *interfaces.Integrator, max_iter: usize) !Self {

        return Self{ 
            .allocator = allocator, 
            .sim_objs = std.ArrayList(SimObject).init(allocator), 
            .updatables = std.ArrayList(interfaces.Updatable).init(allocator), 
            .state_vals = std.ArrayList(f64).init(allocator), 
            .state_names = std.ArrayList([]const u8).init(allocator),
            .steady = interfaces.SteadySolver.init(allocator),
            .max_iter = max_iter,
            .integrator = integrator,
        };
    }

    pub fn create(allocator: std.mem.Allocator, integrator: *interfaces.Integrator, max_iter: usize) !*Self {
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, integrator, max_iter);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self {
        const integrator_ptr = try interfaces.Integrator.from_json(allocator, contents);
        const new = try create(
            allocator, 
            integrator_ptr,
            (try parse.optional_field(allocator, usize, Self, "max_iter", contents)) orelse 100
        );
        return new;
    }

    // Adding Objects
    pub fn add_sim_obj(self: *Self, obj: SimObject) !void {

        try self._name_exists(obj.name());

        try self.sim_objs.append(obj);
        for (obj.get_header()) |header| {

            const name: []u8 = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ obj.name(), header});

            try self.state_names.append(name);
            try self.state_vals.append(std.math.nan(f64));
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

    pub fn add_steadyable(self: *Self, steadyable: interfaces.Steadyable) !void{
        try self.steady.add_obj(steadyable);
    }

    pub fn step(self: *Self) !void {
        
        // Update user enforced states
        if (self.updated_vals){
            try self._set_vals();
            self.updated_vals = false;
        }

        // Update anythign that can be
        for (self.updatables.items) |updateable|{
            try updateable.update();
        }

        // Integrate anything that can be
        try self.integrator.integrate();

        // Increment time step
        self.time += self.integrator.accepted_dt;
        self.transient_steps += 1;

        // Save values to the save array
        try self._save_vals();
    }

    pub fn step_duration(self: *Self, duration: f64) !void{

        if (0.0 > duration){
            std.log.err("step_duration must be > 0, got [{d}]", .{duration});
            return errors.InputLessThanZero;
        }

        const start = self.time;
        while(@abs((self.time - start) - duration) > 1e-8){

            if (((self.time - start) + self.integrator.new_dt) > duration) {
                self.integrator.new_dt = duration - (self.time - start);
                self.integrator.enforce_dt = true; 
                try self.step();
                self.integrator.enforce_dt = false;
                break;
            }

            try self.step();
        }

    }

    pub fn iter_steady(self: *Self) !bool{
        for (self.updatables.items) |obj| {
            try obj.update();
        }
        
        const converged = self.steady.iter();
        self.steady_steps += 1;

        for (self.updatables.items) |obj| {
            try obj.update();
        }

        try self._save_vals();

        return converged;

    }

    pub fn solve_steady(self: *Self) !void{

        for (0..self.max_iter) |_| {
            self.steady_steps += 1;
            for (self.updatables.items) |obj| {
                try obj.update();
            }
            if (try self.steady.iter()){
                for (self.updatables.items) |obj| {
                    try obj.update();
                }
                try self._save_vals();
                return;
            }
        }
        return errors.ConvergenceError;
    }

    pub fn end(self: *Self) !void{
        _ = self;
    }

    pub fn get_index(self: *Self, name: [] const u8) !usize{
    
        for (self.state_names.items, 0..) |obj, i|{
            if (std.mem.eql(u8, obj, name)) return i;
        }

        std.log.err("Could not find index with object.save named [{s}]", .{name});
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

        std.log.err("Could not find object named [{s}]", .{name});
        return errors.SimObjectDoesNotExist;
    }

    pub fn set_value(self: *Self, idx: usize, value: f64) !void{
        if (idx < 0 or idx > self.state_vals.items.len - 1){
            std.log.err("When setting a value, indx must be >= 0 and less then {d}", .{self.state_vals.items.len - 1}); 
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
        for (self.state_names.items, self.state_vals.items) |name, val| {
            std.log.err("{s}: {d:0.4}", .{ name, val });
        }
    }

    fn _name_exists(self: *Self, name1: []const u8) !void{
        for (self.state_names.items) |name2|{
            if (std.mem.eql(u8, name1, name2)) {
                std.log.err("Object Name [{s}] already exists, please remove duplicate", .{name1});
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
    // _ = @import("_model_tests/test_motion_1dof.zig");
    // _ = @import("_model_tests/test_motion_3dof.zig");
    // _ = @import("_model_tests/test_transient_orifice.zig");
    // _ = @import("_model_tests/test_orifice_reverse.zig");
    // _ = @import("_model_tests/test_blowdown.zig");
    _ = @import("_model_tests/test_steady.zig");
    // std.testing.refAllDecls(@This());
}