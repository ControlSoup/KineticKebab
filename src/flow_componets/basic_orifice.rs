
use super::FlowComponet;
use super::{is_choked,choked_orifice_mdot,unchoked_orifice_mdot};

pub struct BasicOrifice{
    mdot: f64,
    cda: f64,
    is_choked: bool,
}

impl BasicOrifice{
    fn new(cda: f64) -> BasicOrifice{
        return BasicOrifice{
            mdot: 0.0,
            cda,
            is_choked: false
        }
    }
}

impl FlowComponet for BasicOrifice{
    fn calc_mdot(
        &mut self,
        upstream_pressure: f64,
        upstream_density: f64,
        downstream_pressure: f64,
        gamma: f64
    ) -> f64 {
        self.is_choked = is_choked(
            upstream_pressure,
            downstream_pressure,
            gamma
        );

        if self.is_choked{
            self.mdot = choked_orifice_mdot(
                self.cda,
                upstream_pressure,
                upstream_density,
                gamma
            )
        }
        else{
            self.mdot = unchoked_orifice_mdot(
                self.cda,
                upstream_pressure,
                upstream_density,
                gamma,
                downstream_pressure
            )
        }

        return self.mdot
    }
}