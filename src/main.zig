const std = @import("std");
const motion = @import("physics/motion.zig");
const forces = @import("physics/forces.zig");
const sim = @import("sim/sim.zig");
const json_sim = @import("config/json_maker.zig").json_sim;

pub fn main() !void {
    // ========================================================================= 
    // Allocation
    // ========================================================================= 

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    // ========================================================================= 
    // Setup
    // ========================================================================= 

    // Simulation Objects
    var simple = forces.Simple{ .name = "Simple", .force = 1 };
    // var spring = forces.Spring{ .name = "Spring", .spring_constant = 1.0, .preload = 5.0 };

    var motion_obj = motion.Motion1DOF.init(allocator, "MotionBasic", 100.0, 0.0, 0.0, 1.0);
    try motion_obj.add_connection(simple.as_force());
    // try motion_obj.add_connection(spring.as_force());

    // ========================================================================= 
    // Simulaion
    // ========================================================================= 
    var main_sim = sim.Sim.init(allocator, 0.001);
    defer main_sim.deinit();
    try main_sim.add_obj(motion_obj.as_sim_object());
    try main_sim.add_obj(simple.as_sim_object());
    // try main_sim.add_obj(spring.as_sim_object());

    // ========================================================================= 
    // Runtime
    // ========================================================================= 
    main_sim._print_info();
    try main_sim.step_duration(200.0);
    main_sim._print_info();


}