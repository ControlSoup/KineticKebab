const std = @import("std");
const motion = @import("Physics/Motion.zig");
const forces = @import("Physics/Forces.zig");

pub fn main() !void {
    var simple = forces.Force{ .Simple = forces.Simple{ .name = "Simple", .force = 10.0 } };

    var spring = forces.Force{ .Spring = forces.Spring{ .name = "Spring", .spring_constant = 1.0, .preload = 1.0 } };

    var obj = motion.Motion1DOF.new_basic("MotionBoi", 1.0, 0.0, &[_]*forces.Force{ &simple, &spring });

    std.debug.print("{d}\n", .{obj.net_force});

    obj.update();

    std.debug.print("{d} \n", .{obj.net_force});
}
