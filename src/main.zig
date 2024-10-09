const std = @import("std");
const motion = @import("physics/motion.zig");
const forces = @import("physics/forces.zig");
const sim = @import("sim/sim.zig");

pub fn main() !void {
    // ========================================================================= 
    // Allocation
    // ========================================================================= 
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();

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
