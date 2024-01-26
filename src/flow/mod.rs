use crate::volume::Volume;

pub mod orifice;
pub use orifice::RealOrifice;
use std::{rc::Rc,cell::RefCell};

pub trait FlowRestriction<V: Volume>{
    fn calc_mdot(&mut self) -> f64;
    fn get_connection_in(&mut self) -> Rc<RefCell<V>>;
    fn get_connection_out(&mut self) -> Rc<RefCell<V>>;


    fn transfer_state(&mut self){
        let mdot = self.calc_mdot();

        // In order to maintain mutable references to both this struct and
        // future stucts, disect the Rc and refcell as mutable for editing.
        let connection = self.get_connection_in();
        let mut connection_in = connection.borrow_mut();
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

        let connection = self.get_connection_out();
        let mut connection_out = connection.borrow_mut();
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