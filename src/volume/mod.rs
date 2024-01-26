use crate::{sim, props::IntensiveState};

pub mod transeint_volume;
pub use transeint_volume::TransientVolume;

pub mod infinite_volume;
pub use infinite_volume::InfiniteVolume;

pub trait Volume{
    fn get_conservation(&mut self) -> Option<Box<ConserveME>>;
    fn get_intensive_state(&self) -> &IntensiveState;
}

#[derive(
    Clone,
    Copy,
    derive_more::Mul,
    derive_more::Div,
    derive_more::Add
)]
pub struct ConserveME{
    mdot_in: f64,
    mdot_out: f64,
    energy_in: f64,
    energy_out: f64,
    mdot: f64,
    udot: f64,
    mass: f64,
    inenergy: f64
}

impl ConserveME{

    fn new_from_mu(mass: f64, inenergy: f64) -> ConserveME{
        return ConserveME{
            mdot_in: 0.0,
            mdot_out: 0.0,
            energy_in: 0.0,
            energy_out: 0.0,
            mdot: 0.0,
            udot: 0.0,
            mass,
            inenergy
        }
    }

    /// Set mass flux and energy flux to 0.0
    fn clear(&mut self){
        self.mdot_in = 0.0;
        self.mdot_out = 0.0;
        self.energy_in = 0.0;
        self.energy_out = 0.0;
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

    /// Calcualtes and updates rate of change in mass and specific enthalpy
    ///
    /// Continuity Equations:
    ///
    /// $\dot{m} = \Sigma\dot{m_{in}} - \Sigma\dot{m_{out}}
    ///
    /// $\dot{u} = \frac{\Sigma\dot{U_{in}} - \Sigma\dot{U_{out}}}{m}
    ///
    /// TODO: Add units
    pub fn perform_conservation(&mut self){
        self.mdot = self.mdot_in - self.mdot_out;
        self.udot = self.energy_in - self.energy_out;
        self.clear()
    }

}

// ----------------------------------------------------------------------------
// Integration
// ----------------------------------------------------------------------------

impl sim::Integrate for ConserveME{
    fn get_derivative(&mut self)-> Self {
        let mut d = self.clone();
        d.mass = d.mdot;
        d.inenergy = d.udot;
        d.mdot = 0.0;
        d.udot = 0.0;

        return d
    }
}

// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------

impl sim::Save for ConserveME{

    fn save_data(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        runtime.add_or_set(&format!(
            "{prefix}.mass [kg]"),
            self.mass
        );
        runtime.add_or_set(&format!(
            "{prefix}.inenergy [J]"),
            self.inenergy
        );
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

// ----------------------------------------------------------------------------
// Test
// ----------------------------------------------------------------------------

#[cfg(test)]
mod tests {

    use crate::sim::Integrate;

    use approx::assert_relative_eq;

    use super::*;

    #[test]
    fn mass_test(){
        let mut conservation = ConserveME::new_from_mu(10.0, 10.0);

        let time = 1.0;
        let dt = 1e-3;
        let steps = (time / dt) as usize;

        // Test Mass In
        conservation.add_mdot_in(1.0);
        conservation.perform_conservation();
        for _ in 0..steps{
            conservation.rk4(dt)
        }

        assert_relative_eq!(
            conservation.mass,
            11.0,
            max_relative = 1e-6
        );

        // Test Mass Out
        conservation.add_mdot_out(1.0);
        conservation.perform_conservation();
        for _ in 0..steps{
            conservation.rk4(dt)
        }

        assert_relative_eq!(
            conservation.mass,
            10.0,
            max_relative = 1e-6
        );

    }

    #[test]
    fn energy_test(){
        let mut conservation = ConserveME::new_from_mu(10.0, 10.0);

        let time = 1.0;
        let dt = 1e-3;
        let steps = (time / dt) as usize;

        // Test Mass In
        conservation.add_energy_in(1.0);
        conservation.perform_conservation();
        for _ in 0..steps{
            conservation.rk4(dt)
        }

        assert_relative_eq!(
            conservation.inenergy,
            11.0,
            max_relative = 1e-6
        );

        // Test Mass Out
        conservation.add_energy_out(1.0);
        conservation.perform_conservation();
        for _ in 0..steps{
            conservation.rk4(dt)
        }

        assert_relative_eq!(
            conservation.inenergy,
            10.0,
            max_relative = 1e-6
        );


    }
}