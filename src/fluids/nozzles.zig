const std = @import("std");
const sim = @import("../sim.zig");


// pub const IdealChokedNozzle = struct{
//     const Self = @This();

//     pub const header = [_][]const u8{
//         "cf [-]",
//         "throat_area [m^2]",
//         "entrance_area [m^2]",
//         "entrance_static_press [Pa]",
//         "entrance_velocity [m/s]", 
//         "exit_area [m^2]",
//         "exit_static_press [Pa]",
//         "exit_temp [degK]", 
//         "exit_velocity [m/s]", 
//         "thurst [N]", 
//     };

//     name: []const u8,
//     entrance_area: f64,
//     throat_area: f64,
//     exit_area: f64,
//     cf: f64,

//     mdot: f64 = std.math.nan(f64),
//     dp: f64 = std.math.nan(f64),

//     entrace_static_press: f64 = std.math.nan(f64),
//     entrance_velocity: f64 = std.math.nan(f64),
//     exit_static_press: f64 = std.math.nan(f64),
//     exit_temp: f64 = std.math.nan(f64),
//     exit_velocity: f64 = std.math.nan(f64),
//     thrust: f64 = std.math.nan(f64),

//     connection_in: ?sim.volumes.Volume = null,
//     connection_out: ?sim.volumes.Volume = null,
//     position_ptr: ?*sim.motions.d1.Motion = null,

//     pub fn init(name: []const u8, entrance_area: f64, throat_area: f64, exit_area: f64, cf: f64) Self{

//         return Self{
//             .name = name,
//             .entrance_area = entrance_area,
//             .throat_area = throat_area,
//             .exit_area = exit_area,
//             .cf = cf,
//         };
//     }

//     pub fn create(allocator: std.mem.Allocator, name: []const u8, entrance_area: f64, throat_area: f64, exit_area: f64, cf: f64) !*Self{
//         const ptr = try allocator.create(Self);
//         ptr.* = init(name, entrance_area, throat_area, exit_area, cf);
//         return ptr;
//     }

//     pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
//         return create(
//             allocator, 
//             try sim.parse.string_field(allocator, Self, "name", contents),
//             try sim.parse.field(allocator, f64, Self, "entrance_area", contents),
//             try sim.parse.field(allocator, f64, Self, "throat_area", contents),
//             try sim.parse.field(allocator, f64, Self, "exit_area", contents),
//             try sim.parse.field(allocator, f64, Self, "cf", contents),
//         );
//     }

//     // =========================================================================
//     //  Intefaces
//     // =========================================================================

//     pub fn as_sim_object(self: *Self) sim.SimObject {
//         return sim.SimObject{.IdealChokedNozzle = self};
//     }

//     pub fn as_restriction(self: *Self) sim.restrictions.Restriction{
//         return sim.restrictions.Restriction{.IdealChokedNozzle = self};
//     }

//     pub fn as_force(self: *Self) sim.forces.d1.Force{
//         return sim.forces.d1.Force{.IdealChokedNozzle = self};
//     }

//     // =========================================================================
//     //  Sim Object Methods
//     // =========================================================================

//     pub fn save_vals(self: *const Self, save_array: []f64) void{
//         save_array[0] = self.cf;
//         save_array[1] = self.throat_area;
//         save_array[2] = self.entrance_area;
//         save_array[3] = self.entrace_static_press;
//         save_array[4] = self.entrance_velocity;
//         save_array[5] = self.exit_area;
//         save_array[6] = self.exit_static_press;
//         save_array[7] = self.exit_temp;
//         save_array[8] = self.exit_velocity;
//         save_array[9] = self.thrust;
//     }

//     pub fn set_vals(self: *Self, save_array: []f64) void{
//         self.cf = save_array[0];
//         self.throat_area = save_array[1];
//         self.entrance_area = save_array[2];
//         self.entrace_static_press = save_array[3];
//         self.entrance_velocity = save_array[4];
//         self.exit_area = save_array[5];
//         self.exit_static_press = save_array[6];
//         self.exit_temp = save_array[7];
//         self.exit_velocity = save_array[8];
//         self.thrust = save_array[9];
//     }

//     // =========================================================================
//     //  Restriction Methods
//     // =========================================================================

//     pub fn get_mdot(self: *Self) !f64{

//         const state_in = self.connection_in.?.get_intrinsic();
//         const state_out = self.connection_out.?.get_intrinsic();

//         self.dp = state_in.press - state_out.press;

//         std.log.err("DP : {d}", .{self.dp});

//         // Assumes choked even when not
//         if (self.dp <= 0.1){
//             self.mdot = 0.0;
//             self.entrance_velocity = 0.0;
//             self.entrace_static_press = state_in.press;
//             self.exit_static_press = state_out.press;
//             self.exit_temp = state_out.temp;
//             self.exit_velocity = state_out.temp;
//             self.entrance_velocity = 0.0;
//             return 0.0;
//         }

//         // Entrance and exit conditions
//         const entrance_mach = try sim.fluids_equations.sutton.nozzle_mach_from_choked_throat(self.throat_area, self.entrance_area, state_in.gamma, false, 1e-5, 50);
//         var exit_mach = try sim.fluids_equations.sutton.nozzle_mach_from_choked_throat(self.throat_area, self.exit_area, state_in.gamma, true, 1e-5, 50);

//         self.entrace_static_press = sim.fluids_equations.sutton.nozzle_static_press(state_in.press, entrance_mach, state_in.gamma);
//         self.exit_static_press = sim.fluids_equations.sutton.nozzle_static_press(state_in.press, exit_mach, state_in.gamma);

//         self.entrance_velocity = entrance_mach * state_in.sos;

//         // Hacky overexapnsion correction
//         if (self.exit_static_press < state_out.press) {
//             self.exit_static_press = state_out.press;
//             self.exit_velocity = sim.fluids_equations.sutton.nozzle_exit_velocity(state_in.press, state_out.press, self.entrance_velocity, state_in.gamma, state_in.sos);
//             exit_mach = self.exit_velocity / state_in.sos;
//         }  else{
//             self.exit_velocity = exit_mach * state_in.sos;
//         }

//         self.exit_temp = sim.fluids_equations.sutton.nozzle_static_temp(state_in.temp, exit_mach, state_in.gamma); 


//         self.mdot = sim.fluids_equations.sutton.nozzle_mdot(self.throat_area, state_in.press, state_in.gamma, state_in.sos);
//         return self.mdot;
//     }

//     pub fn get_hdot(self: *Self) !f64{
//         // Garenteed to be out flowing else error
//         return self.connection_in.?.get_intrinsic().sp_enthalpy;
//     }

//     // =========================================================================
//     //  Get Froce
//     // =========================================================================

//     pub fn get_force(self: *Self) !f64{

//         const state_out = self.connection_out.?.get_intrinsic();

//         self.thrust = self.cf * (self.mdot * self.exit_velocity + ((self.exit_static_press - state_out.press) * self.exit_area));

//         return self.thrust;
//     }
// };