use std::sync::Arc;

use crate::sim;

pub mod transeint_volume;
pub use transeint_volume::TransientVolume;

pub trait ControlVolume{
    fn set_mdot_in(&mut self, mdot: f64);
    fn set_mdot_out(&mut self, mdot: f64);
    fn set_energy_in(&mut self, energy: f64);
    fn set_energy_out(&mut self, energy: f64);
    fn set_mdot(&mut self, mdot: f64);
    fn set_udot(&mut self, udot: f64);
    fn set_mass(&mut self, mass: f64);
    fn set_energy(&mut self, energy: f64);
    
    fn get_mdot_in(&self) -> f64;
    fn get_mdot_out(&self) -> f64;
    fn get_energy_in(&self) -> f64;
    fn get_energy_out(&self) -> f64;

    fn get_pressure(&self) -> f64;
    fn get_temperature(&self) -> f64;

    fn add_mdot_in(&mut self, mdot: f64){
        self.set_mdot_in(mdot + self.get_mdot_in())
    }
    fn add_mdot_out(&mut self, mdot: f64){
        self.set_mdot_out(mdot + self.get_mdot_out())
    }
    fn add_energy_in(&mut self, energy: f64){
        self.set_energy_in(energy + self.get_energy_in())
    }
    fn add_energy_out(&mut self, energy: f64){
        self.set_energy_out(energy + self.get_energy_out())
    }
}

impl<T: ControlVolume> sim::Integrate for T where T: Clone{
    /// Solves the continuity equations
    /// 
    /// 
    /// $ \dot{m} = \Sigma \dot{m}_{in} - \Sigma \dot{m}_{out} $
    /// 
    /// $ \dot{E} = \Sigma \dot{m}_{in} h_{in} - \Sigma \dot{m}_out h_{out}
    /// 
    /// Assumes no external work, or heat input from outside 
    /// the control volume
    /// 
    /// ## Units
    /// 
    /// $\dot{m}: [\frac{\textrm{kg}}{\textrm{s}}]$ Mass flowrate 
    /// 
    /// $\dot{m_{in}}: [\frac{\textrm{kg}}{\textrm{s}}]$ Mass flowrate going into the control volume
    /// 
    /// $\dot{m_{out}}: [\frac{\textrm{kg}}{\textrm{s}}]$ Mass flowrate going out of the control volume
    /// 
    /// $\dot{h_{in}}: [\frac{\textrm{J}}{\textrm{kg}}]$ Specific enthalpy going into the control volume 
    /// 
    /// $\dot{h_{out}}: [\frac{\textrm{J}}{\textrm{kg}}]$ Specific enthalpy going out of the control volume 
    fn get_derivative(&self)-> Self {
        let mut d = self.clone();

        d.set_mass(self.get_mdot_in() - self.get_mdot_out());
        d.set_energy(self.get_energy_in() - self.get_energy_out());
        d.set_mdot(0.0);
        d.set_udot(0.0);

        return d
    }
}



