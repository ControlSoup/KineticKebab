//! Componets used for calculating flow conditions
//!
//! ## Sources
//! - <a href=https://en.wikipedia.org/wiki/Orifice_plate>Orifice Equations</a>
//! - <a href=ihttps://en.wikipedia.org/wiki/Choked_flow>Choked Flow Equation</a>
//!
pub mod basic_orifice;
pub use basic_orifice::BasicOrifice;

pub trait FlowComponet{
    fn calc_mdot(
        &mut self,
        upstream_press: f64,
        upstream_density: f64,
        downstream_press: f64,
        gamma: f64
    ) -> f64;
}


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

pub fn critical_pressure(upstream_stagnation_press: f64, gamma: f64) -> f64{
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
pub fn is_choked(upstream_press: f64, downstream_press: f64, gamma: f64) -> bool{
    if downstream_press < critical_pressure(upstream_press, gamma){
        return true
    }else {
        return false
    }
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
pub fn choked_orifice_mdot(
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
pub fn unchoked_orifice_mdot(
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