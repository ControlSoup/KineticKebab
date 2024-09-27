const std = @import("std");

const u8list = std.ArrayList(u8);
const f64list = std.ArrayList(f64);
const Test = struct {
    const Self = @This();
    list1: u8list,
    list2: f64list,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Test{ .list1 = u8list.init(allocator), .list2 = f64list.init(allocator) };
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var maybe = Test.init(allocator);

    try maybe.list1.append(1);
    try maybe.list2.append(1.0);

    std.debug.print("{any}\n{any}\n", .{ maybe.list1.items, maybe.list2.items });
}
