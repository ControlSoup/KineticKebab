const std = @import("std");
const sim = @import("../../sim.zig");

const MAX_STATE_LEN = sim.solvers.MAX_STATE_LEN;

pub const Motion = struct {
    const Self = @This();

    pub const header = [14][]const u8{
        "pos.x [m]", 
        "vel.x [m/s]", 
        "accel.x [m/s^2]", 
        "net_force.x [N]", 
        "pos.y [m]", 
        "vel.y [m/s]", 
        "accel.y [m/s^2]", 
        "net_force.y [N]", 
        "mass [kg]", 
        "theta [rad]", 
        "theta_dot [rad/s]", 
        "theta_ddot [rad/s^2]", 
        "net_moment [N*m]", 
        "inertia [kg*m^2]",
    };

    name: []const u8,


    pos: sim.math.Vec2,
    theta: f64,
    mass: f64,
    inertia: f64, 

    vel: sim.math.Vec2 = sim.math.Vec2.init_zeros(),
    accel: sim.math.Vec2 = sim.math.Vec2.init_zeros(),
    net_force: sim.math.Vec2 = sim.math.Vec2.init_zeros(),
    theta_dot: f64 = 0.0,
    theta_ddot: f64 = 0.0,
    net_moment: f64 = 0.0,
    connections: std.ArrayList(sim.forces.d2.Force),

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8, 
        pos_x: f64,
        pos_y: f64,
        theta: f64,
        inertia: f64,
        mass: f64,
    ) !Self{
        return Self{
            .name = name, 
            .mass = mass,
            .pos = sim.math.Vec2.init(pos_x, pos_y),
            .theta = theta,
            .inertia = inertia,
            .connections = std.ArrayList(sim.forces.d2.Force).init(allocator)
        };
    }

    pub fn create(
        allocator: std.mem.Allocator, 
        name: []const u8, 
        pos_x: f64,
        pos_y: f64,
        theta: f64,
        inertia: f64,
        mass: f64,
    ) !*Motion {
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, name, pos_x, pos_y, theta, inertia, mass);
        return ptr;
    }

    pub fn from_json(
        allocator: std.mem.Allocator,
        contents: std.json.Value
    ) !*Motion{

        return try create(
            allocator, 
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "pos.x", contents),
            try sim.parse.field(allocator, f64, Self, "pos.y", contents),
            try sim.parse.field(allocator, f64, Self, "theta", contents),
            try sim.parse.field(allocator, f64, Self, "inertia", contents),
            try sim.parse.field(allocator, f64, Self, "mass", contents),
        );
    }

    pub fn add_connection(self: *Self, sim_obj: sim.SimObject) !void {
        try self.connections.append(sim_obj.Force2DOF);
        try sim_obj.Force2DOF.add_connection(self);
    }


    // =========================================================================
    // SimObject Methods
    // =========================================================================

    /// Creates a sim object interface, that holds a pointer to this object as integratable
    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{.Integratable = sim.solvers.Integratable{.Motion2DOF = self}};
    }

    /// Computes the net force and resulting acceleration based on mass
    pub fn update(self: *Self) !void {
        // Update net force
        self.net_force = sim.math.Vec2.init_zeros();
        self.net_moment = 0.0;

        var force_moment_arr = [3]f64{0.0, 0.0, 0.0};

        for (self.connections.items) |force| {
            force_moment_arr = try force.get_force_moment_arr();
            self.net_force.i += force_moment_arr[0];
            self.net_force.j += force_moment_arr[1];
            self.net_moment += force_moment_arr[2];
        }

        // Get accel from force and mass
        self.accel = self.net_force.div_const(self.mass);
        self.theta_ddot = self.net_moment / self.inertia;
    }

    pub fn save_values(self: *Self, save_array: []f64) void {
        save_array[0] = self.pos.i;
        save_array[1] = self.vel.i;
        save_array[2] = self.accel.i;
        save_array[3] = self.net_force.i;
        save_array[4] = self.pos.j;
        save_array[5] = self.vel.j;
        save_array[6] = self.accel.j;
        save_array[7] = self.net_force.j;
        save_array[8] = self.mass;
        save_array[9] = self.theta;
        save_array[10] = self.theta_dot;
        save_array[11] = self.theta_ddot;
        save_array[12] = self.net_moment;
        save_array[13] = self.inertia;
    }

    // =========================================================================
    // Integratable Methods
    // =========================================================================

    pub fn set_state(self: *Self, integrated_state: [MAX_STATE_LEN]f64) void {
        self.vel.i = integrated_state[1];
        self.pos.i = integrated_state[2];

        self.vel.j = integrated_state[4];
        self.pos.j = integrated_state[5];

        self.theta_dot = integrated_state[7];
        self.theta = integrated_state[8];
    }

    pub fn get_state(self: *Self) [MAX_STATE_LEN]f64 {
        return [9]f64{ 
            self.accel.i, 
            self.vel.i, 
            self.pos.i, 
            self.accel.j, 
            self.vel.j, 
            self.pos.j, 
            self.theta_ddot, 
            self.theta_dot, 
            self.theta 
        };
    }

    pub fn get_dstate(self: *Self, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        _ = self;
        return [9]f64{
            0.0,
            state[0],
            state[1],
            0.0,
            state[3],
            state[4],
            0.0,
            state[6],
            state[7],
        };
    }
     
};