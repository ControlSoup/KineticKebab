use crate::volume::Volume;

pub mod orifice;
pub use orifice::RealOrifice;
use std::rc::Rc;

pub trait FlowRestriction<V: Volume>{
    fn calc_mdot(&mut self) -> f64;
    fn get_connection_in(&mut self) -> Rc<V>;
    fn get_connection_out(&mut self) -> Rc<V>;
    fn transfer_state(&mut self){
        let mdot = self.calc_mdot();

        let mut connection_in = self.get_connection_in();
        let conservation  = connection_in.get_conservation();
        let intensive_state = connection_in.get_intensive_state();

        // If the volume wants to conserve, do so!
        match conservation{
            Some(mut conservation) => {
                conservation.add_mdot_in(mdot);
                conservation.add_energy_in(mdot * intensive_state.sp_enthalpy());
            }
            None =>{}
        }

        let mut connection_out = self.get_connection_out();
        let conservation  = connection_out.get_conservation();
        let intensive_state = connection_out.get_intensive_state();

        match conservation{
            Some(mut conservation) => {
                conservation.add_mdot_out(mdot);
                conservation.add_energy_out(mdot * intensive_state.sp_enthalpy());
            }
            None =>{}
        }
    }
}