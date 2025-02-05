const std = @import("std");
const sim = @import("../sim.zig");
const volumes = @import("volumes.zig");
const MAX_STATE_LEN = sim.interfaces.MAX_STATE_LEN;

pub const RuntankUllage = struct{
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
    working_connection: ?*RuntankWorkingFluid = null,

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
            std.log.err("Obect [{s}] press [{d:0.3}] is less minimum pressure [{d}]", .{name, press, 0.0});
            return sim.errors.InvalidInput;
        }

        if (temp < 0.0){
            std.log.err("Obect [{s}] temp [{d:0.3}] is less minimum pressure [{d}]", .{name, temp, 0.0});
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

    pub fn as_sim_object(self: *Self) sim.SimObject{
        return sim.SimObject{.RuntankUllage = self};
    }

    pub fn as_integratable(self: *Self) sim.interfaces.Integratable{
        return sim.interfaces.Integratable{.RuntankUllage = self};
    }

    pub fn as_volume(self: *Self) volumes.Volume{
        return volumes.Volume{.RuntankUllage = self};
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        save_array[0] = self.intrinsic.press;
        save_array[1] = self.intrinsic.temp;
        save_array[2] = self.mass;
        save_array[3] = self.volume;
        save_array[4] = self.inenergy;
        save_array[5] = self.mdot_in;
        save_array[6] = self.mdot_out;
        save_array[7] = self.net_mdot;
        save_array[8] = self.hdot_in;
        save_array[9] = self.hdot_out;
        save_array[10] = self.net_inenergy_dot;
    }
    
    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.intrinsic.press = save_array[0];
        self.intrinsic.temp = save_array[1];
        self.mass = save_array[2];
        self.volume = save_array[3];
        self.inenergy = save_array[4]; 
        self.mdot_in = save_array[5]; 
        self.mdot_out = save_array[6]; 
        self.net_mdot = save_array[7]; 
        self.hdot_in = save_array[8]; 
        self.hdot_out = save_array[9]; 
        self.net_inenergy_dot = save_array[10]; 
    }

    pub fn ullage_update(self: *Self) !void{


        self.mdot_in = 0.0;
        self.hdot_in = 0.0;
        for (self.connections_in.items) |c|{
            const new_mdot = try c.get_mdot(); 

            if (@abs(new_mdot) < 1e-8){
                continue;
            }
            else if (new_mdot >= 0.0){
                self.mdot_in += new_mdot; 
                self.hdot_in += try c.get_hdot(); 
            } else{
                self.mdot_out += - new_mdot; 
                self.hdot_out += try c.get_hdot(); 
            }
        }

        self.mdot_out = 0.0;
        self.hdot_out = 0.0;
        for (self.connections_out.items) |c|{
            const new_mdot = try c.get_mdot(); 

            if (@abs(new_mdot) < 1e-8){
                continue;
            }
            else if (new_mdot >= 0.0){
                self.mdot_out += new_mdot; 
                self.hdot_out += try c.get_hdot(); 
            } else{
                self.mdot_in += - new_mdot; 
                self.hdot_in += try c.get_hdot(); 
            }
        }


        // Continuity Equation (ingoring head and velocity)
        self.net_mdot = self.mdot_in - self.mdot_out;
        self.net_inenergy_dot = (self.mdot_in * self.hdot_in) - (self.mdot_out * self.hdot_out);


        // State update
        self.intrinsic.update_from_du(self.mass / self.volume, self.inenergy / self.mass);
    }

    // =========================================================================
    // Integratable Methods
    // =========================================================================

    pub fn set_state(self: *Self, integrated_state: [MAX_STATE_LEN]f64) void {
        self.mass = integrated_state[1];
        self.inenergy = integrated_state[3];
        self.volume = integrated_state[5];
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
            state[2],
        } ++ ([1]f64{0.0} ** (MAX_STATE_LEN - 4));
    }

};


pub const RuntankWorkingFluid = struct{
    const Self = @This();
    pub const header = [_][]const u8{
        "press [Pa]", 
        "temp [degK]", 
        "mass [kg]", 
        "volume_volume [m^3]", 
        "volume_capacity [m^3]", 
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
    volume_capacity: f64,
    inenergy: f64,
    connections_in: std.ArrayList(sim.restrictions.Restriction),
    connections_out: std.ArrayList(sim.restrictions.Restriction),

    ullage_connection: ?*RuntankUllage = null, 
    vdot: f64 = 0.0,
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
        fill_frac: f64,
        volume_capacity: f64,
        fluid: sim.intrinsic.FluidLookup
    ) !Self{
        
        if (press < 0.0){
            std.log.err("Obect [{s}] press [{d:0.3}] is less minimum pressure [{d}]", .{name, press, 0.0});
            return sim.errors.InvalidInput;
        }

        if (temp < 0.0){
            std.log.err("Obect [{s}] temp [{d:0.3}] is less minimum pressure [{d}]", .{name, temp, 0.0});
            return sim.errors.InvalidInput;
        }

        if (fill_frac < 0.0){
            std.log.err("Obect [{s}] fill_frac [{d:0.3}] is less minimum pressure [{d}]", .{name, fill_frac, 0.0});
            return sim.errors.InvalidInput;
        }

        if (fill_frac < 0.0){
            std.log.err("Obect [{s}] fill_frac [{d:0.3}] is less minimum pressure [{d}]", .{name, fill_frac, 0.0});
            return sim.errors.InvalidInput;
        }

        const state = sim.intrinsic.FluidState.init(fluid, press, temp);
        const volume = volume_capacity * fill_frac;
        const mass: f64 = state.density * volume;
        const inenergy: f64 = state.sp_inenergy * mass;
        return Self{
            .name = name, 
            .mass = mass,
            .inenergy = inenergy,
            .volume = volume,
            .volume_capacity = volume_capacity,
            .intrinsic = state,
            .connections_in = std.ArrayList(sim.restrictions.Restriction).init(allocator),
            .connections_out = std.ArrayList(sim.restrictions.Restriction).init(allocator),

        };
    }

    pub fn create(
        allocator: std.mem.Allocator, 
        name: []const u8, 
        press: f64, 
        temp: f64, 
        volume_capacity: f64,
        fill_frac: f64,
        fluid: sim.intrinsic.FluidLookup
    ) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, name, press, temp, volume_capacity, fill_frac, fluid);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "press", contents),
            try sim.parse.field(allocator, f64, Self, "temp", contents),
            try sim.parse.field(allocator, f64, Self, "volume_capacity", contents),
            try sim.parse.field(allocator, f64, Self, "fill_frac", contents),
            try sim.intrinsic.FluidLookup.from_str(
                try sim.parse.string_field(allocator, Self, "fluid", contents)
            )
        );

    }

    // =========================================================================
    // Interfaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject{
        return sim.SimObject{.RuntankWorkingFluid = self};
    }

    pub fn as_updateable(self: *Self) sim.interfaces.Updatable{
        return sim.interfaces.Updatable{.RuntankWorkingFluid = self};
    }

    pub fn as_integratable(self: *Self) sim.interfaces.Integratable{
        return sim.interfaces.Integratable{.RuntankWorkingFluid = self};
    }

    pub fn as_volume(self: *Self) sim.volumes.Volume{
        return sim.volumes.Volume{.RuntankWorkingFluid = self};
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        save_array[0] = self.intrinsic.press;
        save_array[1] = self.intrinsic.temp;
        save_array[2] = self.mass;
        save_array[3] = self.volume;
        save_array[4] = self.volume_capacity;
        save_array[5] = self.inenergy;
        save_array[6] = self.mdot_in;
        save_array[7] = self.mdot_out;
        save_array[8] = self.net_mdot;
        save_array[9] = self.hdot_in;
        save_array[10] = self.hdot_out;
        save_array[11] = self.net_inenergy_dot;
    }
    
    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.intrinsic.press = save_array[0];
        self.intrinsic.temp = save_array[1];
        self.mass = save_array[2];
        self.volume = save_array[4];
        self.volume_capacity = save_array[4];
        self.inenergy = save_array[5]; 
        self.mdot_in = save_array[6]; 
        self.mdot_out = save_array[7]; 
        self.net_mdot = save_array[8]; 
        self.hdot_in = save_array[9]; 
        self.hdot_out = save_array[10]; 
        self.net_inenergy_dot = save_array[11]; 
    }

    // =========================================================================
    // Updateable Methods
    // =========================================================================

    pub fn update(self: *Self) !void{
        
        if (self.ullage_connection == null){
            std.log.err("[{s}] is missing a ullage connection", .{self.name});
            return sim.errors.MissingConnection;
        }

        // Update Ullage + Sync pressures (No heat transfer between ullage and runtank)
        self.ullage_connection.?.volume = self.volume_capacity - self.volume;
        try self.ullage_connection.?.ullage_update();
        self.intrinsic.update_from_pt(self.ullage_connection.?.intrinsic.press, self.intrinsic.temp);

        // Get all the mdots and enthalpies coming in
        self.mdot_in = 0.0;
        self.hdot_in = 0.0;
        for (self.connections_in.items) |c|{
            const new_mdot = try c.get_mdot(); 

            if (@abs(new_mdot) < 1e-8){
                continue;
            }
            else if (new_mdot >= 0.0){
                self.mdot_in += new_mdot; 
                self.hdot_in += try c.get_hdot(); 
            } else{
                self.mdot_out += - new_mdot; 
                self.hdot_out += try c.get_hdot(); 
            }
        }

        // Get all the mdots and enthalpies going out
        self.mdot_out = 0.0;
        self.hdot_out = 0.0;
        for (self.connections_out.items) |c|{
            const new_mdot = try c.get_mdot(); 

            if (@abs(new_mdot) < 1e-8){
                continue;
            }
            else if (new_mdot >= 0.0){
                self.mdot_out += new_mdot; 
                self.hdot_out += try c.get_hdot(); 
            } else{
                self.mdot_in += - new_mdot; 
                self.hdot_in += try c.get_hdot(); 
            }
        }


        // Continuity Equation (ingoring head and velocity) + Work from ullage
        self.net_mdot = self.mdot_in - self.mdot_out;
        self.vdot = self.net_mdot / self.intrinsic.density;

        self.net_inenergy_dot = (self.mdot_in * self.hdot_in) - (self.mdot_out * self.hdot_out) + (self.vdot * self.ullage_connection.?.intrinsic.press);

        // State update
        self.intrinsic.update_from_du(self.mass / self.volume_capacity, self.inenergy / self.mass);
    }

    // =========================================================================
    // Integratable Methods
    // =========================================================================

    pub fn set_state(self: *Self, integrated_state: [MAX_STATE_LEN]f64) void {
        self.mass = integrated_state[1];
        self.inenergy = integrated_state[3];
        self.volume = integrated_state[5];
    }

    pub fn get_state(self: *Self) [MAX_STATE_LEN]f64 {
        return [_]f64{
            self.net_mdot, 
            self.mass, 
            self.net_inenergy_dot,
            self.inenergy,
            self.vdot,
            self.volume
        } ++ ([1]f64{0.0} ** (MAX_STATE_LEN - 6));
    }

    pub fn get_dstate(self: *Self, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        _ = self;
        return [_]f64{
            0.0, 
            state[0], 
            0.0,
            state[2],
            0.0,
            state[4] 
        } ++ ([1]f64{0.0} ** (MAX_STATE_LEN - 6));
    }

    // =========================================================================
    // Unique Methods
    // =========================================================================

    pub fn connect_ullage(self: *Self, ullage: *RuntankUllage) !void{
        if (self.ullage_connection != null){
            std.log.err("[{s}] is already to [{s}], can't connect to [{s}]", .{self.name, self.ullage_connection.?.name, ullage.name});
            return sim.errors.AlreadyConnected;
        }

        if (ullage.*.working_connection != null){
            std.log.err("[{s}] is already to [{s}], can't connect to [{s}]", .{ullage.name, ullage.working_connection.?.name, self.name});
            return sim.errors.AlreadyConnected;
        }
        self.ullage_connection = ullage;
        ullage.volume = self.volume_capacity  - self.volume;
        self.intrinsic.update_from_pt(self.ullage_connection.?.intrinsic.press, self.intrinsic.temp);
        ullage.*.working_connection = self;
    }

};