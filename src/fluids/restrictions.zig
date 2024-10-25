const std = @import("std");
const sim = @import("../sim.zig");
const volumes = @import("volumes.zig");

pub const Restriction = union(enum){
    const Self = @This();
    
    Orifice: *Orifice,

    pub fn get_mdot(self: *const Self) !f64{
        switch (self.*){
            inline else => |r| return r.get_mdot(),
        }
    }

    pub fn add_connection_in(
        self: *const Self, 
        volume_obj: sim.volumes.Volume
    ) !void{
        switch (self.*) {
            inline else => |f| {
                if (f.connection_in) |_| {
                    std.log.err("ERROR| Object [{s}] is already connected to [{s}]", .{ f.name, f.connection_in.?.name()});
                    return sim.errors.AlreadyConnected;
                } else {
                    f.*.connection_in = volume_obj;
                }
            }
        }
    }

    pub fn add_connection_out(
        self: *const Self, 
        volume_obj: sim.volumes.Volume
    ) !void{
        switch (self.*) {
            inline else => |f| {
                if (f.connection_out) |_| {
                    std.log.err("ERROR| Object[{s}] is already connected to [{s}]", .{ f.name, f.connection_out.?.name()});
                    return sim.errors.AlreadyConnected;
                } else {
                       f.*.connection_out = volume_obj; 
                }
            }
        }
    }

    // =========================================================================
    // Sim Object Methods
    // =========================================================================

    pub fn name(self: *const Self) []const u8{
        return switch (self.*){
            inline else => |impl| impl.name,
        };
    }

    pub fn save_values(self: *const Self, save_array: []f64) void{
        switch (self.*){
            inline else => |impl| impl.save_values(save_array),
        }
    }

    pub fn get_header(self: *const Self) []const []const u8{
        return switch (self.*){
            .Orifice => return Orifice.header[0..],
        };
    }

    pub fn save_len(self: *const Self) usize{
        return switch (self.*){
            .Orifice => return Orifice.header.len,
        };
    }
};

pub const MdotMethod = enum{
    const Self = @This();
    IdealCompressible, 

    pub fn from_str(str: []const u8, ) !Self{
        if (std.mem.eql(u8, str, "IdealCompressible")) {
            return .IdealCompressible;
        }else{
            return sim.errors.InvalidInput;
        }
    }
};


pub const Orifice = struct{
    const Self = @This();
    pub const header = [_][]const u8{"cda [m^2]", "mdot [kg/s]", "dp [Pa]", "is_choked [-]"};

    name: []const u8,
    cda: f64,
    mdot_method: MdotMethod,

    mdot: f64 = 0.0,
    dp: f64 = 0.0,
    is_choked: bool = false,
    connection_in: ?volumes.Volume = null,
    connection_out: ?volumes.Volume = null,

    pub fn init(name: []const u8, cda: f64, mdot_method: MdotMethod) Self{
        return Orifice{.name = name, .cda = cda, .mdot_method = mdot_method};
    }

    pub fn create(allocator: std.mem.Allocator, name: []const u8, cda: f64, mdot_method: MdotMethod) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = init(name, cda, mdot_method); 
        return ptr;
    }

    pub fn from_json(allocator: std.mem.Allocator, contents: std.json.Value) !*Self{
        return create(
            allocator, 
            try sim.parse.string_field(allocator, Self, "name", contents),
            try sim.parse.field(allocator, f64, Self, "cda", contents),
            try MdotMethod.from_str(
                try sim.parse.string_field(allocator, Self, "mdot_method",  contents)
            )
        );
    }

    pub fn get_mdot(self: *Self) !f64{

        if (self.connection_in == null){
            std.log.err("ERROR| Object[{s}] is missing a connection_in", .{self.name});
            return sim.errors.AlreadyConnected; 
        }

        var state_in = self.connection_in.?.get_intrinsic();

        if (self.connection_out == null){
            std.log.err("ERROR| Object[{s}] is missing a connection_out", .{self.name});
            return sim.errors.AlreadyConnected; 
        }

        var state_out = self.connection_out.?.get_intrinsic();

        self.dp = state_in.press - state_out.press;

        // For the purposes of the calc is dp < 0 flow is reversed
        if (self.dp < 0.0){
            const temp = state_in;
            state_in = state_out;
            state_out = temp;
        }

        if (self.dp == 0.0){
            self.mdot = 0.0;
            return 0.0;
        }

        self.is_choked = ideal_is_choked(state_in.press, state_out.press, state_in.gamma);

        switch (self.mdot_method) {
            .IdealCompressible =>{ 
                if (self.is_choked) {
                    self.mdot = ideal_choked_mdot(self.cda, state_in.density, state_in.press, state_in.gamma);
                } else {
                    self.mdot = ideal_unchoked_mdot(self.cda, state_in.density, state_in.press, state_out.press, state_in.gamma);   
                }
            },
        }

        if (self.dp < 0.0) self.mdot *= -1;
        return self.mdot;
    }

    pub fn save_values(self: *const Self, save_array: []f64) void{
        save_array[0] = self.cda;
        save_array[1] = self.mdot;
        save_array[2] = self.dp;
        save_array[3] = if (self.is_choked) 1.0 else 0.0;
    }

    // =========================================================================
    //  Sim Object Methods
    // =========================================================================

    pub fn as_sim_object(self: *Self) sim.SimObject {
        return sim.SimObject{.Restriction = Restriction{.Orifice = self}};
    }


};

// =============================================================================
// Orifice plate equations:
// - https://en.wikipedia.org/wiki/Orifice_plate 
// - https://en.wikipedia.org/wiki/Choked_flow 
// =============================================================================

pub fn ideal_is_choked(us_stag_press: f64, ds_stag_press: f64, gamma: f64) bool {
    if (us_stag_press / ds_stag_press > 4) return true
    else{
        return ds_stag_press < std.math.pow(f64, 2.0 / (gamma + 1.0), gamma / (gamma - 1.0)) * us_stag_press;
    }
}

pub fn ideal_unchoked_mdot(cda: f64, us_density: f64, us_press: f64, ds_press: f64, gamma: f64) f64{
    const a: f64 = 2.0 * us_density * us_press;
    const b: f64 = gamma / (gamma - 1.0);
    const c: f64 = std.math.pow(f64, ds_press / us_press, 2.0 / gamma);
    const d: f64 = std.math.pow(f64, ds_press / us_press, (gamma + 1.0) / gamma);
    return cda * std.math.sqrt(a * b * (c-d));
}

pub fn ideal_choked_mdot(cda: f64, us_density: f64, us_press: f64, gamma: f64) f64{
    const a: f64 = gamma * us_density * us_press;
    const b: f64 = std.math.pow(f64, 2.0 / (gamma + 1.0),(gamma + 1)/(gamma - 1));
    return cda * std.math.sqrt(a*b);
}

test "ideal_mdots"{
    // Choked flow inputs
    const p1 = 100;
    const p2_choked = 10;
    const gamma = 2;
    const d1 = 3;
    const cda = 10;

    try std.testing.expect(ideal_is_choked(p1, p2_choked, gamma));
    try std.testing.expectApproxEqRel(133.333, ideal_choked_mdot(cda, d1, p1, gamma), 1e-4);

    // Unchoked
    const p2_unchoked = 90;

    try std.testing.expect(!ideal_is_choked(p1, p2_unchoked, gamma));
    try std.testing.expectApproxEqRel(74.4459791, ideal_unchoked_mdot(cda, d1, p1, p2_unchoked, gamma), 1e-4);

}