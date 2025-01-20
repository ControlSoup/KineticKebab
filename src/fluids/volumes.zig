const std = @import("std");
const sim = @import("../sim.zig");
const MAX_STATE_LEN = sim.solvers.MAX_STATE_LEN;

pub const Volume = union(enum) {
    const Self = @This();

    Void: *Void,
    Static: *Static,

    pub fn get_intrinsic(self: *const Self) sim.intrinsic.FluidState{
        switch (self.*){
            inline else => |impl| return impl.intrinsic
        }
    }

    pub fn add_connection_in(self: *const Self, sim_obj: sim.SimObject) !void{
        switch (self.*){
            inline else => |impl| {
                try impl.connections_in.append(sim_obj.Restriction);
                try sim_obj.Restriction.add_connection_out(impl.*.as_volume());
            } 
        }
    }

    pub fn add_connection_out(self: *const Self, sim_obj: sim.SimObject) !void{
        switch (self.*){
            inline else => |impl| {
                try impl.connections_out.append(sim_obj.Restriction);
                try sim_obj.Restriction.add_connection_in(impl.*.as_volume());
            } 
        }
    }

    // =========================================================================
    // Integratable Methods
    // =========================================================================

    pub fn get_state(self: *const Self) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            .Void => return [1]f64{0.0} ** MAX_STATE_LEN,
            inline else => |m| m.get_state(),
        };
    }

    pub fn get_dstate(self: *const Self, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            .Void => return state,
            inline else => |m| m.get_dstate(state),
        };
    }

    pub fn set_state(self: *const Self, state: [MAX_STATE_LEN]f64) void {
        return switch (self.*) {
            .Void => return,
            inline else => |m| m.set_state(state),
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
            .Static => return Static.header[0..],
        };
    }

    pub fn save_len(self: *const Self) usize{
        return switch (self.*) {
            .Void => return Void.header.len,
            .Static => return Static.header.len,
        };
    }

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        switch (self.*){
            inline else => |impl| impl.save_vals(save_array),
        }
    }

    pub fn set_vals(self: *const Self, save_array: []f64) void {
        switch (self.*){
            inline else => |impl| impl.set_vals(save_array),
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

        if (temp < 0.0){
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
        return sim.SimObject{.Void = Volume{.Void = self}};
    }

    pub fn as_volume(self: *Self) Volume{
        return Volume{.Void = self};
    }

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        save_array[0] = self.intrinsic.press;
        save_array[1] = self.intrinsic.temp;
    }

    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.intrinsic.press = save_array[0] ;
        self.intrinsic.temp = save_array[1] ;
    }
};

pub const Static = struct{
    const Self = @This();
    pub const header = [_][]const u8{
        "press [Pa]", 
        "temp [degK]", 
        "mass [kg]", 
        "volume [m^3]", 
        "inenergy [J]",
        "mdot_in [kg/s]",
        "mdot_out [kg/s]",
        "net_mdot [kg/s]",
        "hdot_in [J/kg*s]",
        "hdot_out [J/kg*s]",
        "net_inenergy_dot [J/kg*s]",
    };

    name: []const u8,
    intrinsic: sim.intrinsic.FluidState,
    mass: f64,
    volume: f64,
    inenergy: f64,
    connections_in: std.ArrayList(sim.restrictions.Restriction),
    connections_out: std.ArrayList(sim.restrictions.Restriction),

    net_mdot: f64 = 0.0,
    net_inenergy_dot: f64 = 0.0,
    mdot_in: f64 = 0.0,
    mdot_out: f64 = 0.0,
    hdot_in: f64 = 0.0,
    hdot_out: f64 = 0.0,

    pub fn init(
        allocator: std.mem.Allocator, 
        name: []const u8, 
        press: f64, 
        temp: f64, 
        volume: f64,
        fluid: sim.intrinsic.FluidLookup
    ) !Self{

        if (press < 0.0){
            std.log.err("ERROR| Obect [{s}] press [{d:0.3}] is less minimum pressure [{d}]", .{name, press, 0.0});
            return sim.errors.InvalidInput;
        }

        if (temp < 0.0){
            std.log.err("ERROR| Obect [{s}] temp [{d:0.3}] is less minimum pressure [{d}]", .{name, temp, 0.0});
            return sim.errors.InvalidInput;
        }

        const state = sim.intrinsic.FluidState.init(fluid, press, temp);
        const mass: f64 = state.density * volume;
        const inenergy: f64 = state.sp_inenergy * mass;
        return Self{
            .name = name,
            .intrinsic = sim.intrinsic.FluidState.init(fluid, press, temp), // I think this required for dangling pointers
            .mass = mass,
            .inenergy = inenergy,
            .volume = volume,
            .connections_in = std.ArrayList(sim.restrictions.Restriction).init(allocator),
            .connections_out = std.ArrayList(sim.restrictions.Restriction).init(allocator),
        };
    }

    pub fn create(
        allocator: std.mem.Allocator, 
        name: []const u8, 
        press: f64, 
        temp: f64, 
        volume: f64,
        fluid: sim.intrinsic.FluidLookup
    ) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, name, press, temp, volume, fluid);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "press", contents),
            try sim.parse.field(allocator, f64, Self, "temp", contents),
            try sim.parse.field(allocator, f64, Self, "volume", contents),
            try sim.intrinsic.FluidLookup.from_str(
                try sim.parse.string_field(allocator, Self, "fluid", contents)
            )
        );

    }

    // =========================================================================
    // Interfaces
    // =========================================================================

    pub fn as_volume(self: *Self) Volume{
        return Volume{.Static = self};
    }

    pub fn as_sim_object(self: *Self) sim.SimObject{
        return sim.SimObject{.Static = self};
    }

    pub fn as_updateable(self: *Self) sim.interfaces.Updatable{
        return sim.interfaces.Updatable{.Static = self};
    }

    // =========================================================================
    // Updateable Methods
    // =========================================================================

    pub fn update(self: *Self) !void{


        self.mdot_in = 0.0;
        self.hdot_in = 0.0;
        for (self.connections_in.items) |c|{
            const new_mdot = try c.get_mdot(); 

            if (new_mdot >= 0.0){
                self.mdot_in += new_mdot; 
                self.hdot_in += try c.get_hdot(); 
            } else{
                self.mdot_out += - new_mdot; 
                self.hdot_out += - try c.get_hdot(); 
            }
        }

        self.mdot_out = 0.0;
        self.hdot_out = 0.0;
        for (self.connections_out.items) |c|{
            const new_mdot = try c.get_mdot(); 

            if (new_mdot >= 0.0){
                self.mdot_out += new_mdot; 
                self.hdot_out += try c.get_hdot(); 
            } else{
                self.mdot_out += - new_mdot; 
                self.hdot_in += - try c.get_hdot(); 
            }
        }


        // Continuity Equations (ingoring head and velocity)
        self.net_mdot = self.mdot_in - self.mdot_out;
        self.net_inenergy_dot = (self.mdot_in * self.hdot_in) - (self.mdot_out * self.hdot_out);


        // State update
        self.intrinsic.update_from_du(self.mass / self.volume, self.inenergy / self.mass);
    }
    
    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        save_array[0] = self.intrinsic.press;
        save_array[1] = self.intrinsic.temp;
        save_array[2] = self.mass;
        save_array[3] = self.volume;
    }
    
    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.intrinsic.press = save_array[0] ;
        self.intrinsic.temp = save_array[1] ;
        self.mass = save_array[2] ;
        self.volume = save_array[3] ;
    }

    // =========================================================================
    // Integratable Methods
    // =========================================================================

    pub fn set_state(self: *Self, integrated_state: [MAX_STATE_LEN]f64) void {
        self.mass = integrated_state[1];
        self.inenergy = integrated_state[3];
    }

    pub fn get_state(self: *Self) [MAX_STATE_LEN]f64 {
        return [4]f64{
            self.net_mdot, 
            self.mass, 
            self.net_inenergy_dot,
            self.inenergy
        } ++ ([1]f64{0.0} ** (MAX_STATE_LEN - 4));
    }

    pub fn get_dstate(self: *Self, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        _ = self;
        return [4]f64{
            0.0, 
            state[0], 
            0.0,
            state[2] 
        } ++ ([1]f64{0.0} ** (MAX_STATE_LEN - 4));
    }
};