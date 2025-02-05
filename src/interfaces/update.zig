const sim = @import("../sim.zig");

pub const Updatable = union(enum) {
    const Self = @This();

    RuntankWorkingFluid: *sim.volumes.RuntankWorkingFluid, // Ullage is updated through working fluid
    Static: *sim.volumes.Static,
    Void: *sim.volumes.Void,

    Motion1DOF: *sim.motions.d1.Motion,

    Motion3DOF: *sim.motions.d3.Motion,
    

    pub fn update(self: *const Self) !void {
        return switch (self.*) {
            inline else => |impl| try impl.update(),
        };
    }
};