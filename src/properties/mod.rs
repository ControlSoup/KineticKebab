pub mod ideal_gas;
use ideal_gas::IdealGas;

pub trait Fluid{
    fn energy_pt_lookup(&self, pressure: f64, temperature: f64) -> f64;
    fn enthalpy_pt_lookup(&self, pressure: f64, temperature: f64) -> f64;
    fn density_pt_lookup(&self, pressure: f64, temperature: f64) -> f64;
    fn gamma(&self) -> f64;
}