const std = @import("std");
const sim = @import("../../sim.zig");
const MAX_STATE_LEN = sim.solvers.MAX_STATE_LEN;

pub const Force = union(enum) {
    const Self = @This();
    Simple: *Simple,
    BodySimple: *BodySimple,
    // TVCSimple: *TVCSimple,

    pub fn get_force_moment_arr(self: *const Force) ![3]f64{
        try switch (self.*) {
            .Simple => |f| return [3]f64{f.x, f.y, f.moment},
            inline else => |f| return f.get_force_moment_arr(),
        };
    }

    pub fn add_connection(self: *const Self, connection: *sim.motions.d3.Motion) !void {
        switch (self.*) {
            .Simple => |_| return,
            .TVCSimple => |f| {
                if (f.body_force.cg_ptr) |_| {
                    std.log.err("ERROR| Object[{s}] is already connected to [{s}]", .{ f.*.name, connection.name });
                    return sim.errors.AlreadyConnected;
                } else {
                    f.*.body_force.cg_ptr = connection;
                }
            },
            inline else => |f| {
                if (f.cg_ptr) |_| {
                    std.log.err("ERROR| Object[{s}] is already connected to [{s}]", .{ f.*.name, connection.name });
                    return sim.errors.AlreadyConnected;
                } else {
                    f.*.cg_ptr = connection;
                }
            },
        }
    }
    
};

pub const Simple = struct {
    const Self = @This();
    pub const header: [3][]const u8 = [3][]const u8{"force.x [N]", "force.y [N]", "moment [N*m]"};

    name: []const u8,
    x: f64,
    y: f64,
    moment: f64,


    pub fn init(name:[] const u8, x: f64, y: f64, moment: f64) Self{
        return Simple{
            .name = name, 
            .x = x, 
            .y = y,
            .moment = moment
        };
    }

    pub fn create(allocator: std.mem.Allocator, name:[]const u8, x: f64, y: f64, moment: f64) !*Self{
        const ptr = try allocator.create(Simple);
        ptr.* = init(name, x, y, moment);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "force.x", contents),
            try sim.parse.field(allocator, f64, Self, "force.y", contents),
            try sim.parse.field(allocator, f64, Self, "moment", contents),
        );
    }

    // =========================================================================
    // Interfaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{.Simple1DOF = self};
    }

    pub fn as_force(self: *Self) Force{
        return Force{.Simple = self};
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *Self, save_array: []f64) void {
        save_array[0] = self.x;
        save_array[1] = self.y;
        save_array[2] = self.moment;
    }
    
    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.x = save_array[0] ;
        self.y = save_array[1] ;
        self.moment = save_array[2] ;
    }

};

pub const BodySimple = struct {
    const Self = @This();
    pub const header: [7][]const u8 = [7][]const u8{
        "loc_cg.i [m]", 
        "loc_cg.j [m]", 
        "body_force.i [N]", 
        "body_force.j [N]", 
        "global_force.x [N]", 
        "global_force.y [N]", 
        "moment [N*m]", 
    };

    name: []const u8,
    loc: sim.math.Vec2,
    force: sim.math.Vec2,
    global_force: sim.math.Vec2 = sim.math.Vec2.init_zeros(),
    moment: f64 = 0.0,
    cg_ptr: ?*sim.motions.d3.Motion = null,


    pub fn init(name:[] const u8, loc_cg_x: f64, loc_cg_y: f64, x: f64, y: f64) Self{
        return Self{
            .name = name, 
            .loc = sim.math.Vec2.init(loc_cg_x, loc_cg_y),
            .force = sim.math.Vec2.init(x, y),
        };
    }

    pub fn create(allocator: std.mem.Allocator, name:[]const u8, loc_cg_x: f64, loc_cg_y: f64, x: f64, y: f64) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = init(name, loc_cg_x, loc_cg_y, x, y);
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        return try create(
            allocator,
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "loc_cg.i", contents),
            try sim.parse.field(allocator, f64, Self, "loc_cg.j", contents),
            try sim.parse.field(allocator, f64, Self, "force.i", contents),
            try sim.parse.field(allocator, f64, Self, "force.j", contents),
        );
    }

    // =========================================================================
    // Interfaces
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{ .BodySimple3DOF = self};
    }

    pub fn as_force(self: *Self) Force{
        return Force{.BodySimple = self};
    }

    // =========================================================================
    // Force Methods
    // =========================================================================

    pub fn get_force_moment_arr(self: *Self) ![3]f64{
        if (self.cg_ptr == null){
            std.log.err("ERROR| Object[{s}] is missing a connection", .{self.name});
            return sim.errors.MissingConnection; 
        }

        // Convert to the body frame of the object
        self.global_force = sim.math.Vec2.from_angle_rad(self.force.norm(), self.cg_ptr.?.theta);

        // Compute moments (r x F)
        self.moment = (self.force.i * self.loc.j) + (self.force.j + self.loc.i);

        return [3]f64{self.global_force.i, self.global_force.j, self.moment};
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn save_vals(self: *Self, save_array: []f64) void {
        save_array[0] = self.loc.i;
        save_array[1] = self.loc.j;
        save_array[2] = self.force.i;
        save_array[3] = self.force.j;
        save_array[4] = self.global_force.i;
        save_array[5] = self.global_force.j;
        save_array[6] = self.moment;
    }

    pub fn set_vals(self: *Self, save_array: []f64) void {
        self.loc.i = save_array[0] ;
        self.loc.j = save_array[1] ;
        self.force.i = save_array[2] ;
        self.force.j = save_array[3] ;
        self.global_force.i = save_array[4] ;
        self.global_force.j = save_array[5] ;
        self.moment = save_array[6] ;
    }


};

// pub const TVCSimple= struct{
//     const Self = @This();

//     pub const header = [_][]const u8{
//         "loc_cg.i [m]", 
//         "loc_cg.j [m]", 
//         "body_force.i [N]", 
//         "body_force.j [N]", 
//         "global_force.x [N]", 
//         "global_force.y [N]", 
//         "moment [N*m]", 
//         "staring_angle [rad]",
//         "angle [rad]",
//         "thrust [N]"
//     };

//     name: []const u8,
//     body_force: BodySimple,
//     starting_angle: f64,
//     angle: f64,
//     thrust: f64,


//     pub fn init(name:[] const u8, loc_cg_x: f64, loc_cg_y: f64, starting_angle: f64, angle: f64, thrust: f64) Self{
//         return Self{
//             .name = name, 
//             .body_force = BodySimple.init("", loc_cg_x, loc_cg_y, 0.0, 0.0),
//             .starting_angle = starting_angle,
//             .angle = angle,
//             .thrust = thrust
//         };
//     }

//     pub fn create(
//         allocator: std.mem.Allocator, 
//         name:[] const u8, 
//         loc_cg_x: f64, 
//         loc_cg_y: f64, 
//         starting_angle: f64,
//         angle: f64, 
//         thrust: f64
//     ) !*Self{
//         const ptr = try allocator.create(Self);
//         ptr.* = init(name, loc_cg_x, loc_cg_y, starting_angle, angle, thrust);
//         return ptr;
//     }

//     pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
//         return try create(
//             allocator,
//             try sim.parse.string_field(allocator, Self, "name", contents),
//             try sim.parse.field(allocator, f64, Self, "loc_cg.i", contents),
//             try sim.parse.field(allocator, f64, Self, "loc_cg.j", contents),
//             try sim.parse.field(allocator, f64, Self, "starting_angle", contents),
//             try sim.parse.field(allocator, f64, Self, "angle", contents),
//             try sim.parse.field(allocator, f64, Self, "thrust", contents),
//         );
//     }

//     // Interfaces

//     pub fn as_sim_object(self: *Self) sim.SimObject {
//         return sim.SimObject{ .Force3DOF = Force{.TVCSimple = self }};
//     }

//     // =========================================================================
//     // Force Methods
//     // =========================================================================


//     pub fn get_force_moment_arr(self: *Self) ![3]f64{

//         // Convert to the body frame of the object
//         self.body_force.force = sim.math.Vec2.from_angle_rad(self.thrust, self.starting_angle + self.angle);

//         // with the new force and angle update the body force connected to cg
//         _ = try self.body_force.get_force_moment_arr();

//         return [3]f64{
//             self.body_force.global_force.i, 
//             self.body_force.global_force.j, 
//             self.body_force.moment
//         };
//     }

//     // =========================================================================
//     // Sim Object Methods
//     // =========================================================================

//     pub fn save_vals(self: *Self, save_array: []f64) void {
//         save_array[0] = self.body_force.loc.i;
//         save_array[1] = self.body_force.loc.j;
//         save_array[2] = self.body_force.force.i;
//         save_array[3] = self.body_force.force.j;
//         save_array[4] = self.body_force.global_force.i;
//         save_array[5] = self.body_force.global_force.j;
//         save_array[6] = self.body_force.moment;
//         save_array[7] = self.starting_angle;
//         save_array[8] = self.angle;
//         save_array[9] = self.thrust;
//     }

//     pub fn set_vals(self: *Self, save_array: []f64) void {
//         self.body_force.loc.i = save_array[0] ;
//         self.body_force.loc.j = save_array[1] ;
//         self.body_force.force.i = save_array[2] ;
//         self.body_force.force.j = save_array[3] ;
//         self.body_force.global_force.i = save_array[4] ;
//         self.body_force.global_force.j = save_array[5] ;
//         self.body_force.moment = save_array[6] ;
//         self.starting_angle = save_array[7] ;
//         self.angle = save_array[8] ;
//         self.thrust = save_array[9] ;
//     }
// };
