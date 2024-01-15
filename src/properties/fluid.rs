use super::ideal_gas::{IdealGas, self};

use crate::sim;

use coolprop_rs::PropsSI;
pub enum FluidLookup{
    Ideal{
        ideal_gas: IdealGas
    },
    Real{
        name: String
    }
}

impl FluidLookup{
    fn sp_energy_pt_lookup(&self, pressure: f64, temperature: f64) -> f64{
        match *self{
            FluidLookup::Ideal{ideal_gas} => {
                return ideal_gas.sp_energy_pt_lookup(pressure, temperature);
            },
            FluidLookup::Real{name} => {
                return PropsSI("UMASS", "P", pressure, "T", temperature, name.as_str()h)
            }
        }
    }

    fn sp_enthalpy_pt_lookup(&self, pressure: f64, temperature: f64) -> f64{
        match *self{
            FluidLookup::Ideal{ideal_gas} => {
                return ideal_gas.sp_energy_pt_lookup(pressure, temperature);
            },
            FluidLookup::Real{name} => {
                return PropsSI("HMASS", "P", pressure, "T", temperature, name.as_str())
            }
        }
    }

    fn density_pt_lookup(&self, pressure: f64, temperature: f64) -> f64{
        match *self{
            FluidLookup::Ideal{ideal_gas} => {
                return ideal_gas.density_pt_lookup(pressure, temperature);
            },
            FluidLookup::Real{name} => {
                return PropsSI("D", "P", pressure, "T", temperature, name.as_str())
            }
        }
    }

    fn pressure_du_lookup(&self, density: f64, sp_energy: f64) -> f64{
        match *self{
            FluidLookup::Ideal{ideal_gas} => {
                return ideal_gas.pressure_du_lookup(density, sp_energy);
            },
            FluidLookup::Real{name} => {
                return PropsSI("P", "D", density, "UMASS", sp_energy, name.as_str())
            }
        }
    }

    fn temperature_du_lookup(&self, density: f64, sp_energy: f64) -> f64{
        match *self{
            FluidLookup::Ideal{ideal_gas} => {
                return ideal_gas.temperature_du_lookup(density, sp_energy);
            },
            FluidLookup::Real{name} => {
                return PropsSI("T", "D", density, "UMASS", sp_energy, name.as_str())
            }
        }
    }

    fn gamma_pt_lookup(&self, pressure: f64, temperature: f64) -> f64{
        match *self{
            FluidLookup::Ideal{ideal_gas} => {
                return ideal_gas.gamma();
            },
            FluidLookup::Real{name} => {
                return PropsSI("ISENTROPIC_EXPANSION_COEFFICIENT", "P", pressure, "T", temperature, name.as_str())
            }
        };

    }

    fn speed_of_sound_ps_lookup(&self, pressure: f64, sp_entropy: f64) -> Option<f64>{
        match *self{
            FluidLookup::Ideal{ideal_gas} => {

            },
            FluidLookup::Real{name} => {
                return PropsSI("A", "P", pressure, "SMASS", sp_entropy, name)
            }
        }
    }

}

/// Stores intensive and extensive properties with a fluid
pub struct FluidState{
    // Intensive
    pressure: f64,
    temperature: f64,
    density: f64,
    sp_energy: f64,
    sp_enthalpy: f64,
    gamma: f64,
    speed_of_sound: f64,

    // Extensive
    mass: f64,
    volume: f64,
    fluid_lookup: FluidLookup
}

impl FluidState{

    /// Creates a new FluidState from volume, pressure and temperature
    ///
    /// Uses pressure and temperature to lookup the current density,
    /// specific energy, and specific enthalpy for a given fluid
    ///
    /// Calculates mass, based on density and given volume
    ///
    pub fn pressure(&self) -> f64{self.pressure}
    pub fn temperature(&self) -> f64{self.temperature}
    pub fn density(&self) -> f64{self.density}
    pub fn sp_energy(&self) -> f64{self.sp_energy}
    pub fn sp_enthalpy(&self) -> f64{self.sp_enthalpy}
    pub fn gamma(&self) -> f64{self.gamma}
    pub fn speed_of_sound(&self) -> f64{self.speed_of_sound}
    pub fn mass(&self) -> f64{self.mass}
    pub fn volume(&self) -> f64{self.volume}
    pub fn fluid_lookup_method(&self) -> FluidLookup{self.fluid_lookup}

    pub fn new_from_ptv(
        pressure: f64,
        temperature: f64,
        volume: f64,
        fluid_lookup: FluidLookup
    ) -> FluidState{

        let density = fluid_lookup.density_pt_lookup(pressure, temperature);

        return FluidState{
            pressure,
            temperature,
            density,
            sp_energy: fluid_lookup.sp_energy_pt_lookup(pressure, temperature),
            sp_enthalpy: fluid_lookup.sp_enthalpy_pt_lookup(pressure, temperature),
            gamma: fluid_lookup.gamma_pt_lookup(pressure, temperature),
            mass: density * volume,
            volume,
            fluid_lookup
        }
    }

    /// Updates the state based on mass and specific energy
    ///
    /// Updates energy and mass. Calculates the new intensive
    /// property density from the current volume
    ///
    /// Using density and sp_energy, looks up new pressure and temp data
    ///
    /// Using new pressure and temp data, looks up sp_enthalpy
    ///
    pub fn update_from_mu(&mut self, mdot: f64, energy: f64){
        self.mass += mdot;
        self.density = self.mass / self.volume;
        self.sp_energy = energy / self.mass;
        self.pressure = self.fluid_lookup.pressure_du_lookup(self.density, self.sp_energy);
        self.temperature = self.fluid_lookup.temperature_du_lookup(self.density, self.sp_energy);
        self.sp_enthalpy = self.fluid_lookup.sp_energy_pt_lookup(self.pressure, self.temperature);
    }
}

impl sim::Save for FluidState{
    fn save_data(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        runtime.add_or_set(format!(
            "{prefix}.mass [kg]").as_str(),
            self.mass
        );
        runtime.add_or_set(format!(
            "{prefix}.volume [m^3]").as_str(),
            self.volume
        );
        runtime.add_or_set(format!(
            "{prefix}.pressure [Pa]").as_str(),
            self.pressure
        );
        runtime.add_or_set(format!(
            "{prefix}.temperature [degK]").as_str(),
            self.temperature
        );
    }
    fn save_data_verbose(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.save_data(prefix, runtime);
        runtime.add_or_set(format!(
            "{prefix}.density [kg/m^3]").as_str(),
            self.density
        );
        runtime.add_or_set(format!(
            "{prefix}.sp_energy [J/kg]").as_str(),
            self.sp_energy
        );
        runtime.add_or_set(format!(
            "{prefix}.sp_enthalpy [J/kg]").as_str(),
            self.sp_enthalpy
        );
    }
}