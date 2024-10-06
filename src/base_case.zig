const std = @import("std");
const motion = @import("../physics/motion.zig");
const forces = @import("../physics/forces.zig");
const sim = @import("sim/sim.zig");
const json_sim = @import("config/json_maker.zig").json_sim;

pub fn main() !void {
    // ========================================================================= 
    // Allocation
    // ========================================================================= 

    var gpa = std.heap.GeneralPurposeAllocator(.{.verbose_log = true}){};
    const allocator = gpa.allocator();
    defer {
        if (gpa.deinit() == .leak) @panic("MEMORY LEAK");
    }

    // ========================================================================= 
    // File Reading
    // ========================================================================= 
    var file = try std.fs.cwd().openFile("base_case.json", .{ .mode = .read_only });
    const file_size = (try file.stat()).size;
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    try file.reader().readNoEof(buffer);
    file.close();

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const sim_ptr = try json_sim(allocator, buffer);
    
    sim_ptr._print_info();
    sim_ptr.step_duration(1.0);
    sim_ptr._print_info();
}
