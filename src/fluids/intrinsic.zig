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
        }
        if (std.mem.eql(u8, lookup_str, "OxMethane")){
            return FluidLookup{.IdealGas = IdealGas.init_cealookup(ox_methane_cea)};
        } else {
            return FluidLookup{ .CoolProp = lookup_str };
        }
    }
};

pub const NitrogenIdealGas = FluidLookup{ .IdealGas = IdealGas.init(1.4, 296.8) };

// =============================================================================
// FluidState
// =============================================================================

pub const FluidState = struct {
    const Self = @This();

    medium: FluidLookup,
    press: f64,
    temp: f64,
    gamma: f64 = std.math.nan(f64),
    density: f64 = std.math.nan(f64),
    sp_enthalpy: f64 = std.math.nan(f64),
    sp_inenergy: f64 = std.math.nan(f64),
    sp_entropy: f64 = std.math.nan(f64),
    sos: f64 = std.math.nan(f64),

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
                self.sp_inenergy = equations.ideal_gas.u_from_t(impl.cv, self.temp, impl.t0);
                self.sp_enthalpy = equations.ideal_gas.h_from_t(impl.cp, self.temp, impl.t0);
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
                const temp = equations.ideal_gas.t_from_h(impl.cp, self.sp_enthalpy, impl.t0);
                self.update_from_pt(press, temp);
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

    pub fn update_cea(self: *Self, pc: f64, mr: f64) !void{
        switch (self.medium) {
            .CoolProp => |impl| {
                std.log.err("Cannot update base properties of Coolprop string: [{s}]", .{impl});
            },
            .IdealGas => |*impl| self.update_from_pt(pc, try impl.update_cea_temp(pc, mr))
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

    cealookup: ?CeaLookup = null,

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

    pub fn init_cealookup(cealookup: CeaLookup) Self{

        const gamma = cealookup.gamma_map[0];
        const sp_r = cealookup.sp_r_map[0];

        return IdealGas{
            .gamma = gamma,
            .sp_r = sp_r,
            .cp = equations.ideal_gas.cp_from_base(sp_r, gamma),
            .cv =  equations.ideal_gas.cv_from_base(sp_r, gamma),
            .p0 = p0,
            .t0 = t0,
            .cealookup = cealookup
        };
    }


    pub fn update_cea_temp(self: *Self, pc: f64, mr: f64) !f64 {

        if (self.cealookup == null){
            std.log.err("No Cea Lokup Exists for [{any}]", .{self});
            return error.InvalidCeaLookup;
        }


        const mr_f32: f32 = @as(f32, @floatCast(mr));
        const pc_f32: f32 = @as(f32, @floatCast(pc));

        try self.cealookup.?.check_input_bounds(mr_f32, pc_f32); 

        const high_mr_idx = try sim.math.index_geql(f32, self.cealookup.?.mr_range[0..], mr_f32);
        const low_mr_idx = try sim.math.index_leql(f32, self.cealookup.?.mr_range[0..], mr_f32);
        const high_mr = self.cealookup.?.mr_range[high_mr_idx];
        const low_mr = self.cealookup.?.mr_range[low_mr_idx];

        const high_pc_idx = try sim.math.index_geql(f32, self.cealookup.?.pc_range[0..], pc_f32);
        const low_pc_idx = try sim.math.index_leql(f32, self.cealookup.?.pc_range[0..], pc_f32);
        const high_pc = self.cealookup.?.pc_range[high_pc_idx];
        const low_pc = self.cealookup.?.pc_range[low_pc_idx];

        const ll_gamma = self.cealookup.?.lookup_2d(low_mr_idx, low_pc_idx, self.cealookup.?.gamma_map[0..]);
        const lh_gamma = self.cealookup.?.lookup_2d(low_mr_idx, high_pc_idx, self.cealookup.?.gamma_map[0..]);
        const hl_gamma = self.cealookup.?.lookup_2d(high_mr_idx, low_pc_idx, self.cealookup.?.gamma_map[0..]);
        const hh_gamma = self.cealookup.?.lookup_2d(high_mr_idx, high_pc_idx, self.cealookup.?.gamma_map[0..]);

        const hh_sp_r = self.cealookup.?.lookup_2d(high_mr_idx, high_pc_idx, self.cealookup.?.sp_r_map[0..]);
        const hl_sp_r = self.cealookup.?.lookup_2d(high_mr_idx, low_pc_idx, self.cealookup.?.sp_r_map[0..]);
        const lh_sp_r = self.cealookup.?.lookup_2d(low_mr_idx, high_pc_idx, self.cealookup.?.sp_r_map[0..]);
        const ll_sp_r = self.cealookup.?.lookup_2d(low_mr_idx, low_pc_idx, self.cealookup.?.sp_r_map[0..]);

        const ll_temp = self.cealookup.?.lookup_2d(low_mr_idx, low_pc_idx, self.cealookup.?.temp_map[0..]);
        const hl_temp = self.cealookup.?.lookup_2d(high_mr_idx, low_pc_idx, self.cealookup.?.temp_map[0..]);
        const lh_temp = self.cealookup.?.lookup_2d(low_mr_idx, high_pc_idx, self.cealookup.?.temp_map[0..]);
        const hh_temp = self.cealookup.?.lookup_2d(high_mr_idx, high_pc_idx, self.cealookup.?.temp_map[0..]);

        self.gamma = sim.math.multilinear_poly(
            f32, 
            mr_f32, 
            pc_f32, 
            low_mr,
            high_mr,
            low_pc,
            high_pc,
            ll_gamma,
            lh_gamma,
            hl_gamma,
            hh_gamma,
        );
        self.sp_r = sim.math.multilinear_poly(
            f32, 
            mr_f32, 
            pc_f32, 
            low_mr,
            high_mr,
            low_pc,
            high_pc,
            ll_sp_r,
            lh_sp_r,
            hl_sp_r,
            hh_sp_r,
        );

        self.cp = equations.ideal_gas.cp_from_base(self.sp_r, self.gamma);
        self.cv = equations.ideal_gas.cv_from_base(self.sp_r, self.gamma);


        const temp = sim.math.multilinear_poly(
            f32, 
            mr_f32, 
            pc_f32, 
            low_mr,
            high_mr,
            low_pc,
            high_pc,
            ll_temp,
            lh_temp,
            hl_temp,
            hh_temp,
        );

        return temp;
    }
};

test IdealGas {
    const press = 100_000;
    const temp = 300;

    var gas = FluidState.init(try FluidLookup.from_str("NitrogenIdealGas"), press, temp);

    try std.testing.expect(gas.press == press);
    try std.testing.expect(gas.temp == temp);

    // Functional check that everything in reversable
    const gamma = gas.gamma;
    const density = gas.density;
    const sp_enthalpy = gas.sp_enthalpy;
    const sp_inenergy = gas.sp_inenergy;
    const sp_entropy = gas.sp_entropy;
    const sos = gas.sos;

    gas.update_from_pt(press, temp);

    try std.testing.expectApproxEqRel(press, gas.press, 1e-7);
    try std.testing.expectApproxEqRel(temp, gas.temp, 1e-7);
    try std.testing.expectApproxEqRel(gamma, gas.gamma, 1e-7);
    try std.testing.expectApproxEqRel(density, gas.density, 1e-7);
    try std.testing.expectApproxEqRel(sp_enthalpy, gas.sp_enthalpy, 1e-7);
    try std.testing.expectApproxEqRel(sp_inenergy, gas.sp_inenergy, 1e-7);
    try std.testing.expectApproxEqRel(sp_entropy, gas.sp_entropy, 1e-7);
    try std.testing.expectApproxEqRel(sos, gas.sos, 1e-7);

    gas.update_from_du(density, sp_inenergy);

    try std.testing.expectApproxEqRel(press, gas.press, 1e-7);
    try std.testing.expectApproxEqRel(temp, gas.temp, 1e-7);
    try std.testing.expectApproxEqRel(gamma, gas.gamma, 1e-7);
    try std.testing.expectApproxEqRel(density, gas.density, 1e-7);
    try std.testing.expectApproxEqRel(sp_enthalpy, gas.sp_enthalpy, 1e-7);
    try std.testing.expectApproxEqRel(sp_enthalpy, gas.sp_enthalpy, 1e-7);
    try std.testing.expectApproxEqRel(sp_entropy, gas.sp_entropy, 1e-7);
    try std.testing.expectApproxEqRel(sos, gas.sos, 1e-7);

    gas.update_from_ph(press, sp_enthalpy);

    try std.testing.expectApproxEqRel(press, gas.press, 1e-7);
    try std.testing.expectApproxEqRel(temp, gas.temp, 1e-7);
    try std.testing.expectApproxEqRel(gamma, gas.gamma, 1e-7);
    try std.testing.expectApproxEqRel(density, gas.density, 1e-7);
    try std.testing.expectApproxEqRel(sp_enthalpy, gas.sp_enthalpy, 1e-7);
    try std.testing.expectApproxEqRel(sp_inenergy, gas.sp_inenergy, 1e-7);
    try std.testing.expectApproxEqRel(sp_entropy, gas.sp_entropy, 1e-7);
    try std.testing.expectApproxEqRel(sos, gas.sos, 1e-7);

    gas.update_from_pu(press, sp_inenergy);

    try std.testing.expectApproxEqRel(press, gas.press, 1e-7);
    try std.testing.expectApproxEqRel(temp, gas.temp, 1e-7);
    try std.testing.expectApproxEqRel(gamma, gas.gamma, 1e-7);
    try std.testing.expectApproxEqRel(density, gas.density, 1e-7);
    try std.testing.expectApproxEqRel(sp_enthalpy, gas.sp_enthalpy, 1e-7);
    try std.testing.expectApproxEqRel(sp_inenergy, gas.sp_inenergy, 1e-7);
    try std.testing.expectApproxEqRel(sp_entropy, gas.sp_entropy, 1e-7);
    try std.testing.expectApproxEqRel(sos, gas.sos, 1e-7);
}

// CEA methods

pub const CeaLookup = struct {
    const Self = @This();
    const MR_SIZE: usize = 50;
    const PC_SIZE: usize = 500;

    mr_range: [MR_SIZE]f32,
    pc_range: [PC_SIZE]f32,
    gamma_map: [MR_SIZE * PC_SIZE]f32,
    sp_r_map: [MR_SIZE * PC_SIZE]f32,
    temp_map: [MR_SIZE * PC_SIZE]f32,
    
    pub fn lookup_2d(_: Self, mr_idx: usize, pc_idx: usize, map: []f32) f32{
        return map[PC_SIZE * pc_idx + mr_idx];
    }

    pub fn max_pc(self: *Self) f32{
        return self.pc_range[self.pc_range.len - 1];
    }

    pub fn min_pc(self: *Self) f32{
        return self.pc_range[0];
    }

    pub fn max_mr(self: *Self) f32{
        return self.mr_range[self.mr_range.len - 1];
    }

    pub fn min_mr(self: *Self) f32{
        return self.mr_range[0];
    }

    pub fn check_input_bounds(self: *Self, mr: f32, pc: f32) !void{
        if (mr > self.max_mr()){
            std.log.err("Input MR: [{d}] > Max MR: [{d}]", .{mr, self.max_mr()});
            return error.InvalidMR;
        }

        if (mr < self.min_mr()){
            std.log.err("Input MR: [{d}] < Min MR: [{d}]", .{mr, self.min_mr()});
            return error.InvalidMR;
        }

        if (pc > self.max_pc()){
            std.log.err("Input PC: [{d}] > Max PC: [{d}]", .{pc, self.max_pc()});
            return error.InvalidPC;
        }

        if (pc < self.min_pc()){
            std.log.err("Input PC: [{d}] < Min PC: [{d}]", .{pc, self.min_pc()});
            return error.InvalidPC;
        }
    }
};

const ox_methane_map = @import("maps/oxygen_methane.zig");
const ox_methane_cea = CeaLookup{
    .mr_range = ox_methane_map.MR,
    .pc_range = ox_methane_map.PC,
    .gamma_map = ox_methane_map.GAMMA_MAP,
    .sp_r_map = ox_methane_map.SP_R_MAP,
    .temp_map = ox_methane_map.TEMP_MAP,
};