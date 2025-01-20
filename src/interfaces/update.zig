const sim = @import("../sim.zig");

pub const Updatable = union(enum) {
    const Self = @This();

    Volume: sim.volumes.Volume,
    Motion1DOF: sim.motions.d1,
    Motion3DOF: sim.motions.d3,

    pub fn update(self: *const Self) !void {
        return switch (self.*) {
            inline else => |impl| try impl.update(),
        };
    }
};