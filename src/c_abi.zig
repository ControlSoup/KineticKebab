const std = @import("std");
const sim = @import("sim.zig");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

const SimOpaque = *align(@alignOf(sim.Sim)) opaque {};

fn from_opaque_to_sim(curr_sim: SimOpaque) *sim.Sim {
    return @as(*sim.Sim, @ptrCast(curr_sim));
}

export fn json_to_sim(json_content: *const u8, json_len: usize) callconv(.C) SimOpaque { const json_string: []const u8 = @as([*]const u8, @ptrCast(json_content))[0..json_len];
    const result = sim.parse.json_sim(allocator, json_string) catch |e| std.debug.panic("{!}", .{e});
    return @as(SimOpaque, @ptrCast(result));
}

export fn step(curr_sim: SimOpaque) callconv(.C) void {
    const sim_ptr = from_opaque_to_sim(curr_sim);
    sim_ptr.step() catch |e| std.debug.panic("{!}", .{e});
}

export fn step_duration(curr_sim: SimOpaque, duration: f64) callconv(.C) void {
    const sim_ptr = from_opaque_to_sim(curr_sim);
    sim_ptr.step_duration(duration) catch |e| std.debug.panic("{!}", .{e});
}

export fn set_value_by_name(curr_sim: SimOpaque, name: *const u8, name_len: usize, value: f64) callconv(.C) void {
    const name_slice: []const u8 = @as([*]const u8, @ptrCast(name))[0..name_len];
    const sim_ptr = from_opaque_to_sim(curr_sim);
    sim_ptr.set_value_by_name(name_slice, value) catch |e| std.debug.panic("{!}", .{e});
}

export fn get_value_by_name(curr_sim: SimOpaque, name: *const u8, name_len: usize) callconv(.C) f64 {
    const name_slice: []const u8 = @as([*]const u8, @ptrCast(name))[0..name_len];
    const sim_ptr = from_opaque_to_sim(curr_sim);
    const result =  sim_ptr.get_value_by_name(name_slice) catch |e| std.debug.panic("{!}", .{e});
    return result;
}
