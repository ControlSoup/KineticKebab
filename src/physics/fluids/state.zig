const std = @import("std");

// =============================================================================
// Fluids
// =============================================================================
pub const NitrogenIdealGas = FluidLookup{ .IdealGas = IdealGas{
    .cp = 1040.0,
    .cv = 742.857142857,
    .gamma = 1.4,
    .molar_mass =  0.02002
}};


// =============================================================================
// Fluids
// =============================================================================

pub const FluidState = struct{
    const Self = @This();
    
    medium: FluidLookup,
    press: f64,
    temp: f64,
    density: f64 = 0.0,
    sp_enthalpy: f64 = 0.0,
    sp_inenergy: f64 = 0.0,
    sp_entropy: f64 = 0.0,
    sos: f64 = 0.0,

    pub fn update_from_pt(self: *Self, press: f64, temp: f64) void{

        self.press = press;
        self.temp = temp;

        switch (self.medium){
            .IdealGas => |impl| {
                self.density = impl.molar_mass * self.press / (IdealGas.r * temp);
                self.sp_inenergy = impl.cv  * temp;
                self.sp_enthalpy = self.sp_inenergy * (self.press / self.density);
                self.sp_entropy = (impl.cp * @log(temp / IdealGas.t0)) - ((IdealGas.r / impl.molar_mass) * (@log(press / IdealGas.p0)));
                self.sos = @sqrt(impl.gamma * self.press / self.density);
            }
            
        }
    }

    pub fn init(medium: FluidLookup, press: f64, temp: f64) Self{
        var new = FluidState{.medium = medium, .press = press, .temp = temp};
        new.update_from_pt(press, temp);
        return new;
    }

    pub fn _print(self: *Self) void{
        std.debug.print("Press : {d:0.5}\n", .{self.press});
        std.debug.print("Temp : {d:0.5}\n", .{self.temp});
        std.debug.print("Density : {d:0.5}\n", .{self.density});
        std.debug.print("Sp Enthalpy : {d:0.5}\n", .{self.sp_enthalpy});
        std.debug.print("Sp Inenergy : {d:0.5}\n", .{self.sp_inenergy});
        std.debug.print("Sp Entropy : {d:0.5}\n", .{self.sp_entropy});
        std.debug.print("Speed of Sounds : {d:0.5}\n", .{self.sos});
    }

};


// =============================================================================
// Lookup Methods
// =============================================================================

pub const FluidLookup = union(enum){
    IdealGas: IdealGas
};

pub const IdealGas = struct{

    // https://en.wikipedia.org/wiki/Gas_constant
    // https://en.wikipedia.org/wiki/Entropy_(classical_thermodynamics)
    pub const r = 8.31446261815324; 
    pub const t0 = 293.15; 
    pub const p0 = 101_325; 

    cp: f64,
    cv: f64,
    gamma: f64,
    molar_mass: f64,

    pub fn as_fluid_look(self: IdealGas) FluidLookup{
        return FluidLookup{.IdealGas = self};
    }
};
