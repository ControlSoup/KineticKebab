pub const STD_ATM_PA: f64 = 101_325.0;
pub const STD_ATM_DEGK: f64 = 288.15;

pub struct IdealGas{
    cp: f64,
    cv: f64,
    sp_r: f64
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
    pub fn new(cp: f64, cv: f64) -> IdealGas{
        return IdealGas{
            cp,
            cv,
            sp_r: cp - cv
        }
    }
}

impl IdealGas{
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
    pub fn density_pt_lookup(&self, pressure: f64, temperature: f64) -> f64 {
        return pressure / (self.sp_r * temperature)
    }

    /// $ h = Tcp$
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
    /// and using the definition of the specific gas constant
    ///
    /// Gives the final
    /// equation of sp_enthalpy as a function only of temperature and constants
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
    pub fn sp_enthalpy_pt_lookup(&self, pressure: f64, temperature: f64) -> f64 {
        return temperature * self.cp
    }

    /// $ s = c_v\frac{T}{T_{\textrm{std}}} + r\frac{P}{P_\textrm{std}}$
    pub fn sp_entropy_pt_lookup(&self, pressure: f64, temperature: f64) -> f64{
        return (self.cv * (temperature / STD_ATM_DEGK).ln()) + (self.sp_r * (pressure / STD_ATM_PA).ln())
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
    pub fn sp_energy_pt_lookup(&self, pressure: f64, temperature: f64) -> f64 {
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
    pub fn gamma(&self) -> f64 {
        return self.cp / self.cv
    }

    /// $c_{\textrm{ideal}} = \sqrt{\gamma\frac{P}{\rho}}}
    ///
    /// <a href=https://en.wikipedia.org/wiki/Speed_of_sound> Speed of Sound</a>:
    /// ## Units
    ///
    /// $\gamma: [-]$ Ratio of specific heats
    ///
    /// $P: [\textrm{Pa}]$ Pressure
    ///
    /// $\rho: [\frac{\textrm{kg}}{\textrm{m}^3}]$ Pressure
    ///
    pub fn speed_of_sound_pd_lookup(&self, pressure: f64, density: f64) -> f64 {
        return (self.gamma() * (pressure / density)).sqrt()
    }

    /// $P = \frac{u\rhor}{c_v}$
    ///
    /// Using the density formulation of the
    /// <a href=https://en.wikipedia.org/wiki/Ideal_gas_law> Ideal Gas Law </a>:
    /// $[ P = T \rho r]$
    ///
    /// And the defintion of internal energy: [$u = c_vT$]
    ///
    /// Substitute internal energy for temperature inthe ideal gas low to get
    /// the final equation pressure in terms of energy and density
    ///
    pub fn pressure_du_lookup(&self, density: f64, sp_energy: f64) -> f64 {
        return sp_energy * density / self.cv
    }

    /// $T = \frac{u}{c_v}
    ///
    /// For an gas that follows the
    /// <a href=https://en.wikipedia.org/wiki/Ideal_gas_law> Ideal Gas Law </a>:
    ///
    /// Internal energy is only a funciton of temperature, so density is not needed
    /// to calculate temperature from energy
    ///
    pub fn temperature_du_lookup(&self, density: f64, sp_energy: f64) -> f64 {
        return sp_energy / self.cv
    }

}
