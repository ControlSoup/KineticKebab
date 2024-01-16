use std::str::pattern::DoubleEndedSearcher;

use coolprop_rs::PropsSI;

use super::IdealGas;
use crate::{sim, props::fluid};

pub enum FluidLookup{
    Ideal{ideal_gas: IdealGas},
    Real{name: String}
}

impl FluidLookup{

    fn intensive_pt_update(&self, pressure: f64, temperature: f64, fluid_state: &mut FluidState){
        use FluidLookup::{Ideal,Real};

        fluid_state.pressure = pressure;
        fluid_state.temperature = temperature;

        match self{
            Ideal{ ideal_gas } =>{
                // pressure
                // temperature
                fluid_state.density = ideal_gas.density_pt_lookup(pressure, temperature);
                fluid_state.sp_energy = ideal_gas.sp_energy_pt_lookup(pressure, temperature);
                fluid_state.sp_enthalpy = ideal_gas.sp_enthalpy_pt_lookup(pressure, temperature);
                fluid_state.sp_entropy = ideal_gas.sp_entropy_pt_lookup(pressure, temperature);
                fluid_state.speed_of_sound = ideal_gas.speed_of_sound_pd_lookup(pressure, fluid_state.density);
                // gamma
            }
            Real{ name } => { // Should this be a simplifer method to prevent error?
                // pressure
                // temperature
                fluid_state.density = PropsSI("D", "P", pressure, "T", temperature, &name).unwrap();
                fluid_state.sp_energy = PropsSI("UMASS","P", pressure, "T", temperature, &name).unwrap();
                fluid_state.sp_enthalpy = PropsSI("HMASS","P", pressure, "T", temperature, &name).unwrap();
                fluid_state.sp_entropy = PropsSI("SMASS","P", pressure, "T", temperature, &name).unwrap();
                fluid_state.speed_of_sound = PropsSI("A","P", pressure, "T", temperature, &name).unwrap();
                fluid_state.gamma = PropsSI("ISENTROPIC_EXPANSION_COEFFICIENT", "P", pressure, "T", temperature, &name).unwrap();
            }
        }
    }

    fn intensive_du_update(&self, density: f64, sp_energy: f64, fluid_state: &mut FluidState){
        use FluidLookup::{Ideal,Real};

        fluid_state.density = density;
        fluid_state.sp_energy = sp_energy;

        match self{
            Ideal{ ideal_gas } => {
                fluid_state.pressure = ideal_gas.pressure_du_lookup(density, sp_energy);
                fluid_state.temperature = ideal_gas.temperature_du_lookup(density, sp_energy);
                // density
                // sp_energy
                fluid_state.sp_entropy = ideal_gas.sp_entropy_pt_lookup(fluid_state.pressure, fluid_state.temperature);
                fluid_state.speed_of_sound = ideal_gas.speed_of_sound_pd_lookup(fluid_state.pressure, fluid_state.density);
                // gamma
            }
            Real { name } =>{
                fluid_state.pressure = PropsSI("P", "D", density, "UMASS", sp_energy, &name).unwrap();
                fluid_state.temperature = PropsSI("T", "D", density, "UMASS", sp_energy, &name).unwrap();
                // density
                // sp_energy
                fluid_state.sp_entropy = PropsSI("SMASS", "D", density, "UMASS", sp_energy, &name).unwrap();
                fluid_state.speed_of_sound = PropsSI("A", "D", density, "UMASS", sp_energy, &name).unwrap();
                fluid_state.gamma = PropsSI("ISENTROPIC_EXPANSION_COEFFICIENT", "D", density, "UMASS", sp_energy, &name).unwrap();
            }
        }

    }

    fn extensive_mu_udpate(&self, mass: f64, energy: f64, fluid_state: &mut FluidState){

        // Update the new mass
        fluid_state.mass = mass;

        // Calculate new density and specific energy
        self.intensive_du_update(mass / fluid_state.volume, energy / mass, fluid_state);

    }
}

/// Stores fluid_state and extensive properties with a fluid
pub struct FluidState{
    pressure: f64,
    temperature: f64,
    density: f64,
    sp_energy: f64,
    sp_enthalpy: f64,
    sp_entropy: f64,
    speed_of_sound: f64,
    gamma: f64, // Isentropic Expansion Coefficent

    mass: f64,
    volume: f64,

    update_method: FluidLookup
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
    pub fn update_method(&self) -> FluidLookup{self.update_method}

    fn null_volume(volume: f64, update_method: FluidLookup) -> Self{
        return FluidState{
            pressure: 0.0,
            temperature: 0.0,
            density: 0.0,
            sp_energy: 0.0,
            sp_enthalpy: 0.0,
            sp_entropy: 0.0,
            speed_of_sound: 0.0,
            gamma: 0.0,
            mass: 0.0,
            volume,
            update_method
        }
    }

    pub fn new_from_ptv(
        pressure: f64,
        temperature: f64,
        volume: f64,
        update_method: FluidLookup
    ) -> Self{
        let mut fluid_state = FluidState::null_volume(volume, update_method);

        // Update intensive properties
        fluid_state.update_method.intensive_pt_update(pressure, temperature, &mut fluid_state);

        // Update mass based on calculated intensive density
        fluid_state.mass = volume / fluid_state.density;

        return fluid_state
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