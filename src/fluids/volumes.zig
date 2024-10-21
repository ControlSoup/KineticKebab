const std = @import("std");
const sim = @import("../sim.zig");
const MAX_STATE_LEN = sim.solvers.MAX_STATE_LEN;

pub const Volume = union(enum) {
    const Self = @This();

    Void: *Void,

    pub fn get_intrinsic(self: *const Self) sim.intrinsic.FluidState{
        switch (self.*){
            inline else => |impl| return impl.intrinsic
        }
    }

    pub fn add_connection_in(self: *const Self, sim_obj: sim.SimObject) !void{
        switch (self.*){
            .Void => |impl| try sim_obj.Restriction.add_connection_out(impl.*.as_volume()),
            // inline else => |impl| {
            //     try impl.connection_in.append(sim_obj.Restriction);
            //     try sim_obj.Restriction.add_connection_out(impl);
            // } 
        }
    }

    pub fn add_connection_out(self: *const Self, sim_obj: sim.SimObject) !void{
        switch (self.*){
            .Void => |impl| try sim_obj.Restriction.add_connection_in(impl.*.as_volume()),
            // inline else => |impl| {
            //     try impl.connection_out.append(sim_obj.Restriction);
            //     try sim_obj.Restriction.add_connection_in(impl);
            // } 
        }
    }

    // =========================================================================
    // Integration Methods
    // =========================================================================

    pub fn get_state(self: *const Self) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            .Void => return [1]f64{0.0} ** MAX_STATE_LEN,
            // inline else => |m| m.get_state(),
        };
    }

    pub fn get_dstate(self: *const Self, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            .Void => return state,
            // inline else => |m| m.get_dstate(state),
        };
    }

    pub fn set_state(self: *const Self, state: [MAX_STATE_LEN]f64) void {
        _ = state;
        return switch (self.*) {
            .Void => return,
            // inline else => |m| m.set_state(state),
        };
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn update(self: *const Self) !void{
        try switch (self.*){
            inline else => |impl| impl.update(),
        };
    }

    pub fn name(self: *const Self) []const u8{
        return switch (self.*){
            inline else => |impl| impl.name,
        };
    }

    pub fn get_header(self: *const Self) []const []const u8{
        return switch (self.*){
            .Void => return Void.header[0..],
        };
    }

    pub fn save_len(self: *const Self) usize{
        return switch (self.*) {
            .Void => return Void.header.len,
        };
    }

    pub fn save_values(self: *const Self, save_array: []f64) void {
        switch (self.*){
            inline else => |impl| impl.save_values(save_array),
        }
    }
};

pub const Void = struct{
    const Self = @This();
    pub const header = [_][]const u8{"press [Pa]", "temp [degK]"};

    name: []const u8,
    intrinsic: sim.intrinsic.FluidState,
    connections_in: std.ArrayList(sim.restrictions.Restriction),
    connections_out: std.ArrayList(sim.restrictions.Restriction),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, press: f64, temp: f64, fluid: sim.intrinsic.FluidLookup) !Self{

        if (press < 0.0){
            std.log.err("ERROR| Obect [{s}] press [{d:0.3}] is less minimum pressure [{d}]", .{name, press, 0.0});
            return sim.errors.InvalidInput;
        }

        if (press < 0.0){
            std.log.err("ERROR| Obect [{s}] temp [{d:0.3}] is less minimum pressure [{d}]", .{name, temp, 0.0});
            return sim.errors.InvalidInput;
        }

        return Void{
            .name = name,
            .intrinsic = sim.intrinsic.FluidState.init(fluid, press, temp),
            .connections_in = std.ArrayList(sim.restrictions.Restriction).init(allocator),
            .connections_out = std.ArrayList(sim.restrictions.Restriction).init(allocator),
        };
    }

    pub fn create(
        allocator: std.mem.Allocator, 
        name:[]const u8, 
        press: f64, 
        temp: f64, 
        fluid: sim.intrinsic.FluidLookup
    ) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, name, press, temp, fluid);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "press", contents),
            try sim.parse.field(allocator, f64, Self, "temp", contents),
            try sim.intrinsic.FluidLookup.from_str(
                try sim.parse.string_field(allocator, Self, "fluid", contents)
            )
        );

    }

    pub fn as_sim_object(self: *Self) sim.SimObject{
        return sim.SimObject{.Integration = sim.solvers.Integration{.Volume = Volume{.Void = self}}};
    }

    pub fn as_volume(self: *Self) Volume{
        return Volume{.Void = self};
    }

    pub fn update(self: *Self) !void{
        for (self.connections_in.items) |c|{
           _ = try c.get_mdot(); 
        }
        for (self.connections_out.items) |c|{
           _ = try c.get_mdot(); 
        }
    }

    pub fn save_values(self: *const Self, save_array: []f64) void {
        save_array[0] = self.intrinsic.press;
        save_array[1] = self.intrinsic.temp;
    }
};