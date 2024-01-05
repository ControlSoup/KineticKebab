use crate::properties;
use super::ControlVolume;

pub struct TransientVolume<F: properties::Fluid>{
    temperature: f64,
    pressure: f64,
    density: f64,
    volume: f64,
    mdot: f64,
    mdot_in: f64,
    mdot_out: f64,
    mass: f64,
    udot: f64,
    energy: f64,
    energy_in: f64,
    energy_out: f64,
    enthalpy: f64,
    fluid: F

}

impl<F: properties::Fluid> TransientVolume<F>{
    /// Intializes a new static volume
    /// 
    /// Specify the intial pressure, temperature, volume and the fluid in use to create a new instance
    fn new(pressure: f64, temperature: f64, volume: f64, fluid: F) -> TransientVolume<F>{ 

        let density = fluid.density_pt_lookup(pressure, temperature);

        return TransientVolume{
            temperature,
            pressure,
            density,
            volume,
            mdot: 0.0,
            mdot_in: 0.0,
            mdot_out: 0.0,
            mass: density * volume, 
            udot: 0.0,
            energy: fluid.energy_pt_lookup(pressure, temperature),
            energy_in: 0.0,
            energy_out: 0.0,
            enthalpy: fluid.enthalpy_pt_lookup(pressure, temperature),
            fluid,
        }    
    }
}

impl<F: properties::Fluid> ControlVolume for TransientVolume<F>{
    fn set_mdot_in(&mut self, mdot: f64){self.mdot_in = mdot}
    fn set_mdot_out(&mut self, mdot: f64){self.mdot_out = mdot}
    fn set_energy_in(&mut self, energy: f64){self.energy_in = energy}
    fn set_energy_out(&mut self, energy: f64){self.energy_out = energy}
    fn set_mdot(&mut self, mdot: f64){self.mdot = mdot}
    fn set_udot(&mut self, udot: f64){self.udot = udot}
    fn set_mass(&mut self, mass: f64){self.mass = mass}
    fn set_energy(&mut self, energy: f64){self.energy = energy}
    
    fn get_mdot_in(&self) -> f64{self.mdot_in}
    fn get_mdot_out(&self) -> f64{self.mdot_out}
    fn get_energy_in(&self) -> f64{self.energy_in}
    fn get_energy_out(&self) -> f64{self.energy_out}
}