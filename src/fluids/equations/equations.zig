const std = @import("std");

pub const orifice = @import("orifice.zig");
pub const sutton = @import("sutton.zig");

test "equations"{
    std.testing.refAllDecls(@This());
}