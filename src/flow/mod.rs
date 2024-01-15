//! Componets used for calculating flow conditions
//!
//! ## Sources
//! - <a href=https://en.wikipedia.org/wiki/Orifice_plate>Orifice Equations</a>
//! - <a href=ihttps://en.wikipedia.org/wiki/Choked_flow>Choked Flow Equation</a>
//!
pub mod orifice;

use crate::volume::Volume;
use crate::sim;
use crate::props;

pub trait FlowComponet<V: Volume>{
    fn calc_mdot(&mut self) -> f64;
    fn connection_in(&self) -> &V;
    fn connection_out(&self) -> &V;
}

impl<V: Volume> sim::Update for dyn FlowComponet<V>{
    fn update(&mut self) {
        let mdot = self.calc_mdot();

        let mut connection = self.connection_in();
        let fluid_state = connection.get_fluidstate();
        let conservation = connection.get_conservation();

        // If the volume wants to conserver, do so!
        match conservation{
            Some(conservation) => {
                conservation.add_mdot_in(mdot);
                conservation.add_energy_in(mdot * fluid_state.sp_enthalpy());
            }
            None =>{}
        }

        let mut connection = self.connection_out();
        let fluid_state = connection.get_fluidstate();
        let conservation = connection.get_conservation();
        match conservation{
            Some(conservation) => {
                conservation.add_mdot_out(mdot);
                conservation.add_energy_out(mdot * fluid_state.sp_enthalpy());
            }
            None =>{}
        }

    }
}

