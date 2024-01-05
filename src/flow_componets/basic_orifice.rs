
use super::FlowComponet;
use super::{is_choked,choked_orifice_mdot,unchoked_orifice_mdot};

pub struct BasicOrifice{
    mdot: f64,
    cda: f64,
    is_choked: bool
}

impl BasicOrifice{
    fn new(cda: f64) -> BasicOrifice{
        return BasicOrifice{
            mdot: 0.0,
            cda,
        }
    }
}

impl FlowComponet for BasicOrifice{
    fn calc_mdot(&self) -> f64 {
        
    }
}