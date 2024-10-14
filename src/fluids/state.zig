const std = @import("std");
const sim = @import("../sim.zig");

// =============================================================================
// Fluids
// =============================================================================

// TODO: This feels super clunky and redirectiony lol fix it

pub const FluidLookup = union(enum){
    const Self = @This();
    IdealGas: IdealGas,

    pub fn from_str(lookup_str: []const u8) !Self{
        if (std.mem.eql(u8, lookup_str, "NitrogenIdealGas")){
            return NitrogenIdealGas;
        }else {
            return sim.errors.InvalidInput;
        } 
    }
};

pub const NitrogenIdealGas = FluidLookup{ 
    .IdealGas = IdealGas.init(1040.0, 1.4, 0.02002)
};

// =============================================================================
// FluidState
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
                self.density = ideal_gas_density(impl.molar_mass, press, temp); 
                self.sp_inenergy = ideal_gas_sp_inenergy(impl.cv, temp); 
                self.sp_enthalpy = impl.enthalpy0 - ideal_gas_sp_enthalpy(self.sp_inenergy, press, self.density);
                self.sp_entropy = impl.entropy0 - ideal_gas_sp_entropy(impl.cv, temp, impl.molar_mass, press);
                self.sos = ideal_gas_sos(impl.gamma, press, self.density);
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
        std.debug.print("Speed of Sounds : {d:0.5}\n\n", .{self.sos});
    }

};


// =============================================================================
// Lookup Methods
// =============================================================================

pub const IdealGas = struct{
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

    pub fn init(cp: f64, gamma: f64, molar_mass: f64) Self{
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

pub fn ref_enthalpy(ideal_gas: IdealGas) f64{
    const inenergy = ideal_gas_sp_inenergy(ideal_gas.cv, IdealGas.t0);
    const density = ideal_gas_density(ideal_gas.molar_mass, IdealGas.p0, IdealGas.t0);
    return ideal_gas_sp_enthalpy(inenergy, IdealGas.p0, density);
}

pub fn ref_entropy(ideal_gas: IdealGas) f64{
    return ideal_gas_sp_entropy(ideal_gas.cp, IdealGas.t0, ideal_gas.molar_mass, IdealGas.p0);
}


fn ideal_gas_density(molar_mass: f64, press: f64, temp: f64) f64{
    return molar_mass * press / (IdealGas.r * temp);
}

fn ideal_gas_sp_inenergy(cv: f64, temp: f64) f64{
    return cv * temp;
}

fn ideal_gas_sp_enthalpy(sp_inenergy: f64, press: f64, density: f64) f64{
    return sp_inenergy * (press / density);
}

fn ideal_gas_sp_entropy(cp: f64, temp: f64, molar_mass: f64, press: f64) f64{
    return (cp * @log(temp / IdealGas.t0)) - ((IdealGas.r / molar_mass) * (@log(press / IdealGas.p0)));
}

fn ideal_gas_sos(gamma: f64, press: f64, density: f64) f64{
    return @sqrt(gamma * press / density);
}