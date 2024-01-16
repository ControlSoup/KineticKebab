use super::FlowComponet;

use crate::props;
use crate::volume::Volume;
use coolprop_rs::PropsSI;
use roots;

pub struct BasicOrifice<'a, V: Volume>{
    mdot: f64,
    cda: f64,
    is_choked: bool,
    connection_in: &'a mut V,
    connection_out: &'a mut V
}

impl<'a, V: Volume> BasicOrifice<'a, V>{
    fn new(
        cda: f64,
        connection_in: &'a mut V,
        connection_out: &'a mut V
    ) -> Self{
        return BasicOrifice{
            mdot: 0.0,
            cda,
            is_choked: false,
            connection_in,
            connection_out
        }
    }
}

impl<'a, V: Volume> FlowComponet<V> for BasicOrifice<'a, V>{
    fn calc_mdot(&mut self) -> f64 {

        let fluid_state_in  = self.connection_in.get_fluidstate();
        let fluid_state_out = self.connection_out.get_fluidstate();

        match fluid_state_in.fluid_lookup_method(){
            props::FluidLookup::Ideal{ideal_gas: _} => {
                self.is_choked = ideal_is_choked(
                    fluid_state_in.pressure(),
                    fluid_state_in.gamma(),
                    fluid_state_out.pressure()
                );

                if self.is_choked{
                    self.mdot = ideal_choked_orifice_mdot(
                        self.cda,
                        fluid_state_in.pressure(),
                        fluid_state_in.density(),
                        fluid_state_in.gamma()
                    )
                }
                else{
                    self.mdot = ideal_unchoked_orifice_mdot(
                        self.cda,
                        fluid_state_in.pressure(),
                        fluid_state_in.density(),
                        fluid_state_in.gamma(),
                        fluid_state_out.pressure()
                    )
                }
            }
            props::FluidLookup::Real {name} => {
                // Assume unchoked intially
                self.is_choked = false;
                if fluid_state_in.pressure() / fluid_state_out.pressure() < 3.5{
                    let unchoked_throat_vel = throat_vel(
                        fluid_state_in.sp_enthalpy(),
                        fluid_state_out.sp_enthalpy()
                    );

                    // Checked for un-choked conditions
                    let speed_of_sound = PropsSI(
                        "A",
                        "P", fluid_state_in.pressure(),
                        "density", fluid_state_in.density(),
                        &name
                    ).unwrap();

                    if unchoked_throat_vel <= speed_of_sound{

                        self.mdot = real_orifice_mdot(
                            self.cda,
                            fluid_state_in.density(),
                            unchoked_throat_vel
                        );
                    }
                    else{
                        self.is_choked = true;
                    }
                }
                else{
                    self.is_choked = true;
                }

                if self.is_choked{
                    // Find the throat pressure
                    let throat_pressure = root_solve_throat_pressure(
                        fluid_state_in.pressure(),
                        fluid_state_in.sp_enthalpy(),
                        &name
                    );

                    // Get upstream entropy
                    let throat_entropy = PropsSI(
                        "SMASS",
                        "P", fluid_state_in.pressure(),
                        "HMASS", fluid_state_in.sp_enthalpy(),
                        &name
                    ).unwrap();

                    // Get isentropic enthalpy
                    let throat_enthalpy = PropsSI(
                        "HMASS",
                        "P", throat_pressure,
                        "SMASS", throat_entropy,
                    &name
                    ).unwrap();

                    // Calculate new throat velocity
                    let choked_throat_vel = throat_vel(
                        fluid_state_in.sp_enthalpy(),
                        throat_enthalpy
                    );

                    // Get mdot
                    self.mdot = real_orifice_mdot(self.cda, density, velocity)
                }

            }
        }



        return self.mdot
    }

    fn connection_in(&mut self) -> &mut V {
        return &mut self.connection_in
    }
    fn connection_out(&mut self) -> &mut V {
        return &mut self.connection_out
    }
}


// ----------------------------------------------------------------------------
// Ideal Gas Mdot Lookup
// ----------------------------------------------------------------------------

/// $ p^* =  \frac{2p_0}{\gamma + 1}^{(\frac{\gamma}{\gamma - 1})}$
///
/// This is the ideal gas assumption used in evaluating the ['is_choked()'] condition
///
/// ## Units
/// $p^*: [\textrm{Pa}]$ Critical pressure
///
/// $p_0: [\textrm{Pa}]$ Upstream Pressure
///
/// $\gamma: [\textrm{unitless}]$ Ratio of specific heats $\frac{c_p}{c_v}$

pub fn ideal_critical_pressure(upstream_stagnation_press: f64, gamma: f64) -> f64{
    return  (2.0 * upstream_stagnation_press / (gamma + 1.0)).powf(gamma / (gamma + 1.0))
}

/// $p_1 < p^* = \textrm{choked flow}$
///
/// If the downstream pressure drops bellow $p^*$ the flow is choked.
///
/// ## Units
///
/// $p^*: [\textrm{Pa}]$ Critical pressure
///
/// $p_1: [\textrm{Pa}]$ Downstream Pressure
///
/// $\gamma: [\textrm{unitless}]$ Ratio of specific heats $\frac{c_p}{c_v}$
pub fn ideal_is_choked(upstream_press: f64, gamma: f64, downstream_press: f64) -> bool{
    if downstream_press < ideal_critical_pressure(upstream_press, gamma){
        return true
    }
    return false
}

/// $ \dot{m} = \textrm{Cda}\sqrt{\gamma \rho_0 p_0 (\frac{2}{\gamma + 1})^\frac{\gamma+1}{\gamma-1}}$
///
/// Mass flowrate for an orifice under choked flow conditions (determined by $p^*$ the critical pressure)
///
/// ## Units
///
/// $\dot{m}: [\frac{\textrm{kg}}{\textrm{s}}]$ Mass flowrate
///
/// $\textrm{Cda}: [\textrm{m}^2]$ Coefficent of discharge times the area of the orifice
///
/// $p_0: [\textrm{Pa}]$ Upstream Pressure
///
/// $\rho_0: [\frac{\textrm{kg}}{\textrm{m}^3}]$ Upstream Density
///
/// $\gamma: [\textrm{unitless}]$ Ratio of specific heats $\frac{c_p}{c_v}$
pub fn ideal_choked_orifice_mdot(
    cda:f64,
    upstream_press: f64,
    upstream_density: f64,
    gamma: f64,
) -> f64{
    let choked_gamma_comp = (2.0 / (gamma + 1.0)).powf((gamma + 1.0)/ (gamma - 1.0));
    return cda * (gamma * upstream_density * upstream_press * choked_gamma_comp).sqrt()
}

/// $ \dot{m} = \textrm{Cda}\sqrt{\gamma \rho_1 p_1
/// (\frac{\gamma}{\gamma - 1})[(\frac{p_1}{p_0})^{\frac{2}{\gamma}} - (\frac{p_1}{p_0})^{\frac{\gamma + 1}{\gamma}}]} $
///
/// Mass flowrate for an orifice under un-choked flow conditions (determined by $p^*$ the critical pressure)
///
/// ## Units
///
/// $\dot{m}: [\frac{\textfrm{kg}}{\textrm{s}}]$ Mass flowrate
///
/// $\textrm{Cda}: [\textrm{m}^2]$ Coefficent of discharge times the area of the orifice
///
/// $p_0: [\textrm{Pa}]$ Upstream Pressure
///
/// $p_1: [\textrm{Pa}]$ Downstream Pressure
pub fn ideal_unchoked_orifice_mdot(
    cda: f64,
    upstream_press: f64,
    upstream_density: f64,
    gamma: f64,
    downstream_press: f64
) -> f64{
    let unchoked_gamma_comp = gamma / (gamma - 1.0);
    let press_ratio = downstream_press / upstream_press;
    let pressure_comp = press_ratio.powf(2.0 / gamma) - (press_ratio.powf((gamma + 1.0) / gamma));
    return cda * (gamma * upstream_density * upstream_press * unchoked_gamma_comp * pressure_comp).sqrt()
}

// ----------------------------------------------------------------------------
// Real Mdot Lookup
// ----------------------------------------------------------------------------

pub fn throat_vel(upstream_sp_enthalpy: f64, downstream_sp_enthalpy: f64) -> f64{
    return (2.0 * (upstream_sp_enthalpy - downstream_sp_enthalpy)).sqrt()
}

pub fn real_orifice_mdot(cda: f64, density: f64, velocity: f64) -> f64{
    return velocity * density * cda
}


pub fn root_solve_throat_pressure(
    upstream_pressure: f64,
    upstream_enthalpy: f64,
    fluid_name: &str
) -> f64{

    let throat_sp_entropy = PropsSI("SMASS", "P", upstream_pressure, "H", upstream_enthalpy, fluid_name).unwrap();
    let throat_speed_of_sound = PropsSI("A", "P", upstream_pressure, "H", upstream_enthalpy, fluid_name).unwrap();

    // Use a closure to allow parent scope
    let root_function = |pressure: f64| -> f64{
        let throat_enthalpy = PropsSI("HMASS", "P", pressure, "SMASS", throat_sp_entropy, fluid_name).unwrap();
        return throat_speed_of_sound - throat_vel(upstream_enthalpy, throat_enthalpy)
    };

    // Root solve the defined closure above
    let mut convergency = roots::SimpleConvergency { eps:1e-9f64, max_iter:50};
    let root_result = roots::find_root_brent(
        upstream_pressure,
        (upstream_pressure / 4.0).max(101000.0), //
        root_function,
        &mut convergency
    );

    return root_result.unwrap()

}