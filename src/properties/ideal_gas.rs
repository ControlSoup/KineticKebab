use super::Fluid;

pub struct IdealGas{
    cp: f64,
    cv: f64,
    gamma: f64,
    r_specific: f64
}


impl IdealGas{
    /// Initializes an ideal gas based on $c_p$ and $c_v$.
    /// 
    /// # Ratio of Specific Heats
    /// 
    /// $ \gamma = \frac{c_p}{c_v} $ 
    /// <a href=https://en.wikipedia.org/wiki/Heat_capacity_ratio#>
    /// (also called the heat capacity ratio) </a>
    /// 
    /// # Specific Gas Constant
    /// 
    /// $ r = c_p - c_v$ from
    /// <a href=https://en.wikipedia.org/wiki/Julius_von_Mayer> Mayers relation </a>
    /// 
    /// 
    /// ## Units
    /// 
    /// $c_p: [\frac{\textrm{J}}{\textrm{kg}\textrm{K}}]$ Specific heat capacity at constant pressure
    /// 
    /// $c_v: [\frac{\textrm{J}}{\textrm{kg}\textrm{K}}]$ Specific heat capacity at constant volume
    /// 
    /// $\gamma: [\textrm{unitless}]$ Ratio of specific heats
    /// 
    /// $r: [\frac{\textrm{J}}{\textrm{kg}\textrm{K}}]$ Specific gas constant
    /// 
    fn new(cp: f64, cv: f64) -> IdealGas{
        return IdealGas{
            cp,
            cv,
            gamma: cp / cv,
            r_specific: cp - cv 
        }
    }
}

impl Fluid for IdealGas{
    // $ \rho = \frac{P}{rT} $
    // 
    // Density formulation of the 
    // <a href=https://en.wikipedia.org/wiki/Ideal_gas_law> Ideal Gas Law </a>
    // 
    // ## Units
    // 
    // $P: [\textrm{Pa}]$ Pressure 
    // 
    // $T: [\textrm{degK}]$ Temperature
    // 
    // $\rho: [\frac{\textrm{kg}}{\textrm{m}^3}]$ Density
    // 
    // $r: [\frac{\textrm{J}}{\textrm{kg}\textrm{K}}]$ Specific gas constant
    fn density_pt_lookup(&self, pressure: f64, temperature: f64) -> f64 {
        return pressure / (self.r_specific * temperature)
    }

    /// $ h = T(c_v + r)$
    /// 
    /// For an ideal gas, the specific enthalpy
    /// will only be a function of temperature.
    /// 
    /// $[h = u + \frac{P}{\rho}]$    and    $[u = c_vT]$ 
    /// give: $[h = c_vT + \frac{P}{\rho}]$
    /// 
    /// substituiting the density formulation of the 
    /// <a href=https://en.wikipedia.org/wiki/Ideal_gas_law> Ideal Gas Law </a>:
    /// $[ P = T \rho r]$
    /// 
    /// Gives the final 
    /// equation of specific_enthalpy as a function only of temperature and constants
    ///  
    /// ## Units
    /// 
    /// $P: [\textrm{Pa}]$ Pressure 
    /// 
    /// $T: [\textrm{degK}]$ Temperature
    /// 
    /// $\rho: [\frac{\textrm{kg}}{\textrm{m}^3}]$ Density
    /// 
    /// $r: [\frac{\textrm{J}}{\textrm{kg}\textrm{K}}]$ Specific gas constant
    /// 
    /// $c_v: [\frac{\textrm{J}}{\textrm{kg}\textrm{K}}]$ Specific heat capacity at constant volume
    fn enthalpy_pt_lookup(&self, pressure: f64, temperature: f64) -> f64 {
        return temperature * (self.cv + self.r_specific)
    }

    /// $u = c_vT$
    /// 
    /// For an ideal gas, the specific internal energy 
    /// will only be a function of temperature.
    /// 
    ///  
    /// ## Units
    /// 
    /// $u: [\frac{\textrm{J}}{\textrm{kg}}]$ Specific internal energy 
    /// 
    /// $T: [\textrm{degK}]$ Temperature
    /// 
    /// $c_v: [\frac{\textrm{J}}{\textrm{kg}\textrm{K}}]$ Specific heat capacity at constant volume
    fn energy_pt_lookup(&self, pressure: f64, temperature: f64) -> f64 {
       return self.cv * temperature 
    } 

    /// $c_p / c_v$
    /// 
    /// Ratio of specific heats
    /// 
    /// ## Units
    /// 
    /// $c_v: [\frac{\textrm{J}}{\textrm{kg}\textrm{K}}]$ Specific heat capacity at constant volume
    /// 
    /// $c_p: [\frac{\textrm{J}}{\textrm{kg}\textrm{K}}]$ Specific heat capacity at constant pressure 
    fn gamma(&self) -> f64 {
        return self.gamma
    }
}