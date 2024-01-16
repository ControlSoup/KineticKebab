use crate::sim;
use crate::properties as props;


pub trait Volume{
    fn get_conservation(&mut self) -> Option<&mut ConserveME>;
    fn get_fluidstate(&mut self) -> props::FluidState;
}

pub struct ConserveME{
    mdot_in: f64,
    mdot_out: f64,
    energy_in: f64,
    energy_out: f64,
    mdot: f64,
    udot: f64
}

impl ConserveME{

    /// Intializes the struct with all zeros
    pub fn zeros() -> ConserveME{
        return ConserveME{
            mdot_in: 0.0,
            mdot_out: 0.0,
            energy_in: 0.0,
            energy_out: 0.0,
            mdot: 0.0,
            udot: 0.0
        }
    }

    /// Adds the mdot input to the current mdot_in
    pub fn add_mdot_in(&mut self, mdot: f64){
        self.mdot_in += mdot;
    }

    /// Adds the mdot input to the current mdot_out
    pub fn add_mdot_out(&mut self, mdot: f64){
        self.mdot_out += mdot;
    }

    /// Adds the energy input to the current energy_in
    pub fn add_energy_in(&mut self, energy: f64){
        self.energy_in += energy;
    }

    /// Adds the energy input to the current energy_out
    pub fn add_energy_out(&mut self, energy: f64){
        self.energy_out += energy;
    }

    /// Sets mass flux, and energy flux to zero
    fn clear(&mut self){
        self.mdot_in = 0.0;
        self.mdot_out = 0.0;
        self.energy_in = 0.0;
        self.energy_out = 0.0;
    }

    /// Calcualtes and updates rate of change in mass and specific enthalpy
    ///
    /// Continuity Equations:
    ///
    /// $\dot{m} = \Sigma\dot{m_{in}} - \Sigma\dot{m_{out}}
    ///
    /// $\dot{u} = \frac{\Sigma\dot{U_{in}} - \Sigma\dot{U_{out}}}{m}
    ///
    /// TODO: Add units
    pub fn perform_conservation(&mut self, fluid_state: &mut props::FluidState){
        self.mdot = self.mdot_in - self.mdot_out;
        self.udot = self.energy_in - self.energy_out;

        fluid_state.update_from_mu(self.mdot, self.udot);
        self.clear()
    }

}

impl sim::Save for ConserveME{

    fn save_data(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        runtime.add_or_set(&format!(
            "{prefix}.mdot [kg/s]"),
            self.mdot
        );
        runtime.add_or_set(&format!(
            "{prefix}.udot [J/s]"),
            self.udot
        );

    }

    fn save_data_verbose(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.save_data(prefix, runtime);
        runtime.add_or_set(&format!(
            "{prefix}.mdot_in [kg/s]"),
            self.mdot_in
        );
        runtime.add_or_set(&format!(
            "{prefix}.mdot_out [kg/s]"),
            self.mdot_out
        );

        runtime.add_or_set(&format!(
            "{prefix}.energy_in [J]"),
            self.energy_in
        );
        runtime.add_or_set(&format!(
            "{prefix}.energy_out [J]"),
            self.energy_out
        );
    }
}