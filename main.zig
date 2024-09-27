const std = @import("std");
const motion = @import("Physics/Motion.zig");
const forces = @import("Physics/Forces.zig");
const sim = @import("Sim/sim.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    var simple = forces.Simple{ .name = "Simple", .force = 10.0 };
    var spring = forces.Spring{ .name = "Spring", .spring_constant = 1.0, .preload = 1.0 };

    var Motion1DOF = motion.Motion1DOF.new_basic("MotionBoi", 1.0, 0.0, &[_]forces.Force{ simple.as_force(), spring.as_force() });
    var main_sim = sim.Sim.init(allocator, 1e-3);

    try main_sim.add_obj(Motion1DOF.as_sim_object());
}
