const std = @import("std");
const sim = @import("../sim.zig");

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
        } else if (std.mem.eql(u8, lookup_str, NitrogenCoolProp)) {
            return FluidLookup{ .CoolProp = NitrogenCoolProp };
        } else if (std.mem.eql(u8, lookup_str, HeliumCoolProp)) {
            return FluidLookup{ .CoolProp = HeliumCoolProp };
        } else if (std.mem.eql(u8, lookup_str, AirCoolProp)) {
            return FluidLookup{ .CoolProp = AirCoolProp };
        } else if (std.mem.eql(u8, lookup_str, WaterCoolProp)) {
            return FluidLookup{ .CoolProp = WaterCoolProp };
        } else {
            std.log.err("Invalid fluid: {s}", .{lookup_str});
            return sim.errors.InvalidInput;
        }
    }
};

pub const NitrogenIdealGas = FluidLookup{ .IdealGas = IdealGas.init(1040.0, 1.4, 0.02002) };

pub const NitrogenCoolProp: []const u8 = "Nitrogen";
pub const HeliumCoolProp: []const u8 = "Helium";
pub const AirCoolProp: []const u8 = "Air";
pub const WaterCoolProp: []const u8 = "Water";

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
            .IdealGas => std.debug.panic("Have not implemented ideal gases in full", .{}),
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
            .IdealGas => std.debug.panic("Have not implemented ideal gases in full", .{}),
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
            .IdealGas => std.debug.panic("Have not implemented ideal gases in full", .{}),
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
            .IdealGas => std.debug.panic("Have not implemented ideal gases in full", .{}),
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

pub const IdealGas = struct {
    const Self = @This();
    pub const r = 8.31446261815324;
    pub const t0 = 293.15;
    pub const p0 = 101_325;

    cp: f64,
    cv: f64,
    gamma: f64,
    molar_mass: f64,
    enthalpy0: f64 = 0.0,
    entropy0: f64 = 0.0,

    pub fn init(cp: f64, gamma: f64, molar_mass: f64) Self {
        var gas = IdealGas{
            .cp = cp,
            .cv = cp / gamma,
            .gamma = gamma,
            .molar_mass = molar_mass,
        };

        gas.enthalpy0 = ref_enthalpy(gas);
        gas.entropy0 = ref_entropy(gas);

        return gas;
    }
};

pub fn ref_enthalpy(ideal_gas: IdealGas) f64 {
    const inenergy = ideal_gas_sp_inenergy(ideal_gas.cv, IdealGas.t0);
    const density = ideal_gas_density(ideal_gas.molar_mass, IdealGas.p0, IdealGas.t0);
    return ideal_gas_sp_enthalpy(inenergy, IdealGas.p0, density);
}

pub fn ref_entropy(ideal_gas: IdealGas) f64 {
    return ideal_gas_sp_entropy(ideal_gas.cp, IdealGas.t0, ideal_gas.molar_mass, IdealGas.p0);
}

fn ideal_gas_density(molar_mass: f64, press: f64, temp: f64) f64 {
    return molar_mass * press / (IdealGas.r * temp);
}

fn ideal_gas_sp_inenergy(cv: f64, temp: f64) f64 {
    return cv * temp;
}

fn ideal_gas_sp_enthalpy(sp_inenergy: f64, press: f64, density: f64) f64 {
    return sp_inenergy * (press / density);
}

fn ideal_gas_sp_entropy(cp: f64, temp: f64, molar_mass: f64, press: f64) f64 {
    return (cp * @log(temp / IdealGas.t0)) - ((IdealGas.r / molar_mass) * (@log(press / IdealGas.p0)));
}

fn ideal_gas_sos(gamma: f64, press: f64, density: f64) f64 {
    return @sqrt(gamma * press / density);
}
