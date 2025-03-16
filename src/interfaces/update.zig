const sim = @import("../sim.zig");

pub const Updatable = union(enum) {
    const Self = @This();

    VoidVolume: *sim.volumes.VoidVolume,
    StaticVolume: *sim.volumes.StaticVolume,
    Motion: *sim.motions.d1.Motion,
    Motion3DOF: *sim.motions.d3.Motion,
    

    pub fn update(self: *const Self) !void {
        return switch (self.*) {
            inline else => |impl| try impl.update(),
        };
    }
};