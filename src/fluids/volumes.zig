const std = @import("std");
const sim = @import("../sim.zig");
const state = @import("state.zig");
const restrictions = @import("restrictions.zig");

pub const Volume = union(enum) {
    const Self = @This();

    Void: *Void,

    pub fn fluid_state(self: *const Self) state.FluidState{
        switch (self.*){
            inline else => |impl| return impl.state
        }
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

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
    state: state.FluidState,

    pub fn init(name: []const u8, press: f64, temp: f64, fluid: state.FluidLookup) !Self{

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
            .state = state.FluidState.init(fluid, press, temp)
        };
    }

    pub fn create(
        allocator: std.mem.Allocator, 
        name:[]const u8, 
        press: f64, 
        temp: f64, 
        fluid: state.FluidLookup
    ) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = try init(name, press, temp, fluid);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "press", contents),
            try sim.parse.field(allocator, f64, Self, "temp", contents),
            try state.FluidLookup.from_str(
                try sim.parse.string_field(allocator, Self, "fluid", contents)
            )
        );

    }

    pub fn as_sim_object(self: *Self) sim.SimObject{
        return sim.SimObject{.Void = self};
    }

    pub fn as_volume(self: *Self) sim.volumes.Volume{
        return sim.volumes.Volume{.Void = self};
    }

    pub fn save_values(self: *const Self, save_array: []f64) void {
        save_array[0] = self.state.press;
        save_array[1] = self.state.temp;
    }
};