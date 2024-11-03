const std = @import("std");
const sim = @import("sim.zig");
const builtin = @import("builtin");
const json_sim = @import("config/create_from_json.zig").json_sim;

const DELIMITER: u8 = 0;

pub fn main() !void {
    // ========================================================================= 
    // Allocation
    // ========================================================================= 
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();


    // ========================================================================= 
    // Stdin / Stdout
    // ========================================================================= 
    const stdin = std.io.getStdIn().reader();
    // const stdout = std.io.getStdIn().writer();
    var input = std.ArrayList(u8).init(allocator);
    defer input.deinit();
    
    stdin.streamUntilDelimiter(input.writer(), DELIMITER, null) catch |err| {
        if (err != error.EndOfStream){
            return err;
        }
    };

    // ========================================================================= 
    // Sim
    // ========================================================================= 
    const json_sim_result = try json_sim(allocator, input.items);

    json_sim_result._print_info();
    try json_sim_result.step_duration(1.0);
    json_sim_result._print_info();

}

test {
    _ = @import("_model_tests/tests.zig");
    std.testing.refAllDecls(@This());
}