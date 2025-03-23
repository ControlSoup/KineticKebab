const std = @import("std");
const sim = @import("../sim.zig");
const equations = @import("equations/equations.zig");

// =============================================================================
// Fluids
// =============================================================================

// TODO: This feels super clunky and redirectiony lol fix it

pub const FluidLookup = union(enum) {
    const Self = @This();
    IdealGas: IdealGas,
    CoolProp: []const u8,

    pub fn from_str(lookup_str: []const u8) !Self {
        if (std.mem.eql(u8, lookup_str, "NitrogenIdealGas")) {
            return NitrogenIdealGas;
        } else {
            return FluidLookup{ .CoolProp = lookup_str };
        }
    }
};

pub const NitrogenIdealGas = FluidLookup{ .IdealGas = IdealGas.init(1.4, 0.02002) };

// =============================================================================
// FluidState
// =============================================================================

pub const FluidState = struct {
    const Self = @This();

    medium: FluidLookup,
    press: f64,
    temp: f64,
    gamma: f64 = 0.0,
    density: f64 = 0.0,
    sp_enthalpy: f64 = 0.0,
    sp_inenergy: f64 = 0.0,
    sp_entropy: f64 = 0.0,
    sos: f64 = 0.0,

    pub fn init(medium: FluidLookup, press: f64, temp: f64) Self {
        var new = FluidState{ .medium = medium, .press = press, .temp = temp };
        new.update_from_pt(press, temp);
        return new;
    }

    pub fn update_from_pt(self: *Self, press: f64, temp: f64) void {
        self.press = press;
        self.temp = temp;

        switch (self.medium) {
            .CoolProp => |impl| {
                self.density = sim.coolprop.get_property("D", "P", self.press, "T", self.temp, impl);
                self.sp_inenergy = sim.coolprop.get_property("U", "P", self.press, "T", self.temp, impl);
                self.sp_enthalpy = sim.coolprop.get_property("H", "P", self.press, "T", self.temp, impl);
                self.sp_entropy = sim.coolprop.get_property("S", "P", self.press, "T", self.temp, impl);
                self.sos = sim.coolprop.get_property("A", "P", self.press, "T", self.temp, impl);
                self.gamma = sim.coolprop.get_property("ISENTROPIC_EXPANSION_COEFFICIENT", "P", self.press, "T", self.temp, impl);
            },
            .IdealGas => |impl| {
                self.density = equations.ideal_gas.d_from_pt(impl.sp_r, self.press, self.temp);
                self.sp_inenergy = equations.ideal_gas.u_from_t(impl.cv, impl.t0, self.temp);
                self.sp_enthalpy = equations.ideal_gas.h_from_t(impl.cp, impl.t0, self.temp);
                self.sp_entropy = equations.ideal_gas.s_from_pt(impl.sp_r, impl.cp, self.press, impl.p0, self.temp, impl.t0);
                self.sos = equations.ideal_gas.sos(impl.gamma, impl.sp_r, self.temp);
                self.gamma = impl.gamma;
            },
        }
    }

    pub fn update_from_du(self: *Self, density: f64, sp_inenergy: f64) void {
        self.density = density;
        self.sp_inenergy = sp_inenergy;

        switch (self.medium) {
            .CoolProp => |impl| {
                self.press = sim.coolprop.get_property("P", "D", density, "U", sp_inenergy, impl);
                self.temp = sim.coolprop.get_property("T", "D", density, "U", sp_inenergy, impl);
                self.sp_enthalpy = sim.coolprop.get_property("H", "D", density, "U", sp_inenergy, impl);
                self.sp_entropy = sim.coolprop.get_property("S", "D", density, "U", sp_inenergy, impl);
                self.sos = sim.coolprop.get_property("A", "D", density, "U", sp_inenergy, impl);
                self.gamma = sim.coolprop.get_property("ISENTROPIC_EXPANSION_COEFFICIENT", "D", density, "U", sp_inenergy, impl);
            },
            .IdealGas => |impl| {
                const temp = equations.ideal_gas.t_from_u(impl.cv, self.sp_inenergy, impl.t0);
                const press = equations.ideal_gas.p_from_dt(impl.sp_r, self.density, self.temp);
                self.update_from_pt(press, temp);
            },
        }
    }

    pub fn update_from_ph(self: *Self, press: f64, sp_enthalpy: f64) void {
        self.press = press;
        self.sp_enthalpy = sp_enthalpy;

        switch (self.medium) {
            .CoolProp => |impl| {
                self.density = sim.coolprop.get_property("D", "P", press, "H", sp_enthalpy, impl);
                self.temp = sim.coolprop.get_property("T", "P", press, "H", sp_enthalpy, impl);
                self.sp_inenergy = sim.coolprop.get_property("U", "P", press, "H", sp_enthalpy, impl);
                self.sp_entropy = sim.coolprop.get_property("S", "P", press, "H", sp_enthalpy, impl);
                self.sos = sim.coolprop.get_property("A", "P", press, "H", sp_enthalpy, impl);
                self.gamma = sim.coolprop.get_property("ISENTROPIC_EXPANSION_COEFFICIENT", "P", press, "H", sp_enthalpy, impl);
            },
            .IdealGas => |impl| {
                const temp = equations.ideal_gas.t_from_h(impl.cv, self.sp_enthalpy, impl.t0);
                self.update_from_pt(self.press, temp);
            },
        }
    }

    pub fn update_from_pu(self: *Self, press: f64, sp_inenergy: f64) void {
        self.press = press;
        self.sp_inenergy = sp_inenergy;

        switch (self.medium) {
            .CoolProp => |impl| {
                self.density = sim.coolprop.get_property("D", "P", press, "U", sp_inenergy, impl);
                self.temp = sim.coolprop.get_property("T", "P", press, "U", sp_inenergy, impl);
                self.sp_enthalpy = sim.coolprop.get_property("H", "P", press, "U", sp_inenergy, impl);
                self.sp_entropy = sim.coolprop.get_property("S", "P", press, "U", sp_inenergy, impl);
                self.sos = sim.coolprop.get_property("A", "P", press, "U", sp_inenergy, impl);
                self.gamma = sim.coolprop.get_property("ISENTROPIC_EXPANSION_COEFFICIENT", "P", press, "U", sp_inenergy, impl);
            },
            .IdealGas => |impl| {
                const temp = equations.ideal_gas.t_from_u(impl.cv, self.sp_inenergy, impl.t0);
                self.update_from_pt(self.press, temp);
            },
        }
    }

    pub fn _print(self: *Self) void {
        std.debug.print("Press : {d:0.5}\n", .{self.press});
        std.debug.print("Temp : {d:0.5}\n", .{self.temp});
        std.debug.print("Density : {d:0.5}\n", .{self.density});
        std.debug.print("Sp Enthalpy : {d:0.5}\n", .{self.sp_enthalpy});
        std.debug.print("Sp Inenergy : {d:0.5}\n", .{self.sp_inenergy});
        std.debug.print("Sp Entropy : {d:0.5}\n", .{self.sp_entropy});
        std.debug.print("Speed of Sounds : {d:0.5}\n\n", .{self.sos});
    }
};

// =============================================================================
// Lookup Methods
// =============================================================================
pub const r = 8.31446261815324;
pub const t0 = 293.15;
pub const p0 = 101_325;

pub const IdealGas = struct {
    const Self = @This();

    cp: f64,
    cv: f64,
    sp_r: f64,
    gamma: f64,
    p0: f64,
    t0: f64,

    pub fn init(gamma: f64, sp_r: f64) Self {
        return IdealGas{
            //
            .gamma = gamma,
            .sp_r = sp_r,
            .cp = equations.ideal_gas.cp_from_base(sp_r, gamma),
            .cv = equations.ideal_gas.cv_from_base(sp_r, gamma),
            .p0 = p0,
            .t0 = t0,
        };
    }
};

test IdealGas {
    const press = 100_000;
    const temp = 300;

    var gas = FluidState.init(try FluidLookup.from_str("NitrogenIdealGas"), press, temp);

    try std.testing.expect(gas.press == press);
    try std.testing.expect(gas.press == temp);

    // Functional check that everything in reversable
    const density = gas.density;
    const sp_inenergy = gas.sp_inenergy;
    const sp_enthalpy = gas.density;

    gas.update_from_pt(press, temp);
    try std.testing.expectApproxEqRel(press, gas.press, 1e-7);
    try std.testing.expectApproxEqRel(temp, gas.temp, 1e-7);

    gas.update_from_du(density, sp_inenergy);
    try std.testing.expectApproxEqRel(density, gas.density, 1e-7);
    try std.testing.expectApproxEqRel(sp_inenergy, gas.sp_inenergy, 1e-7);

    gas.update_from_ph(press, sp_enthalpy);
    try std.testing.expectApproxEqRel(press, gas.press, 1e-7);
    try std.testing.expectApproxEqRel(sp_enthalpy, gas.sp_enthalpy, 1e-7);

    gas.update_from_pu(press, sp_inenergy);
    try std.testing.expectApproxEqRel(density, gas.density, 1e-7);
    try std.testing.expectApproxEqRel(sp_inenergy, gas.sp_inenergy, 1e-7);
}
