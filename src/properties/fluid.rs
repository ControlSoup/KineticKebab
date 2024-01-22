use coolprop_rs::PropsSI;
use crate::sim;

/// Stores lookup properties for real fluids
#[derive(Clone)]
struct FluidProperties{
    prop1: String,
    prop2: String,
    value1: f64,
    value2: f64,
    fluid: String
}
impl FluidProperties{
    pub fn new(
        prop1: &str,
        value1: f64,
        prop2: &str,
        value2: f64,
        fluid: &str
    ) -> FluidProperties{
        let prop1 = prop1.to_string();
        let prop2 = prop2.to_string();
        let fluid = fluid.to_string();
        return FluidProperties{
            prop1,
            value1,
            prop2,
            value2,
            fluid
        }
    }

    /// Uses CoolProp to lookup a property given the current state
    pub fn lookup(&self, prop: &str) -> f64{
        if prop == &self.prop1{return self.value1};
        if prop == &self.prop2{return self.value2};

        return PropsSI(
            prop,
            &self.prop1, self.value1,
            &self.prop2, self.value2,
            &self.fluid
        ).unwrap()
    }
}
#[derive(Clone)]
pub struct IntensiveState{
    pressure: f64,
    temperature: f64,
    density: f64,
    sp_inenergy: f64,
    sp_enthalpy: f64,
    sp_entropy: f64,
    cp: f64,
    cv: f64,
    gamma: f64,
    speed_of_sound: f64,
    props: FluidProperties
}


impl IntensiveState{
    pub fn new(prop1: &str, value1: f64, prop2: &str, value2: f64, fluid: &str) -> IntensiveState{
        let props = FluidProperties::new(prop1, value1, prop2, value2, fluid);
        return IntensiveState{
            pressure: props.lookup("P"),
            temperature: props.lookup("T"),
            density: props.lookup("D"),
            sp_inenergy: props.lookup("UMASS"),
            sp_enthalpy: props.lookup("HMASS"),
            sp_entropy: props.lookup("SMASS"),
            cp: props.lookup("CPMASS"),
            cv: props.lookup("CVMASS"),
            gamma: props.lookup("ISENTROPIC_EXPANSION_COEFFICIENT"),
            speed_of_sound: props.lookup("A"),
            props
        }
    }

    pub fn new_from_pt(pressure: f64, temperature: f64, fluid: &str) -> IntensiveState{
        return IntensiveState::new("P", pressure, "T", temperature, fluid);
    }

    pub fn new_from_du(density: f64, sp_inenergy: f64, fluid: &str) -> IntensiveState{
        return IntensiveState::new("D", density, "UMASS", sp_inenergy, fluid)
    }

    pub fn update_from_du(&mut self, density: f64, sp_inenergy: f64){
        self.update_props("D", density, "UMASS", sp_inenergy)
    }

    pub fn update_from_pt(&mut self, pressure: f64, temperature: f64){
        self.update_props("P", pressure, "T", temperature)
    }


    /// Updates propeties based on new inputs
    pub fn update_props(&mut self, prop1: &str, value1: f64, prop2: &str, value2: f64){
        self.props = FluidProperties::new(
            prop1,value1,
            prop2, value2,
            &self.props.fluid
        );
        self.state_update();
    }

    /// Updates the current state based on input properties
    fn state_update(&mut self){
        self.pressure = self.props.lookup("P");
        self.temperature = self.props.lookup("T");
        self.density = self.props.lookup("D");
        self.sp_inenergy = self.props.lookup("UMASS");
        self.sp_enthalpy = self.props.lookup("HMASS");
        self.sp_entropy = self.props.lookup("SMASS");
        self.cp = self.props.lookup("CPMASS");
        self.cv = self.props.lookup("CVMASS");
        self.gamma = self.props.lookup("ISENTROPIC_EXPANSION_COEFFICIENT");
        self.speed_of_sound = self.props.lookup("A");
    }

    /// Returns a new state with the same entropy as the current
    pub fn isentropic(&self, prop: &str, value: f64) -> IntensiveState{
        return  IntensiveState::new(
            prop, value,
            "SMASS",self.sp_entropy,
            &self.props.fluid
        );
    }

    /// Returns a new state with the same temperature as the current
    pub fn isothermal(&self, prop: &str, value: f64) -> IntensiveState{
        return  IntensiveState::new(
            prop, value,
            "T",self.temperature,
            &self.props.fluid
        );
    }

    /// Returns a new state with the same enthalpy as the current
    pub fn isenthalpic(&self, prop: &str, value: f64) -> IntensiveState{
        return  IntensiveState::new(
            prop, value,
            "HMASS",self.sp_enthalpy,
            &self.props.fluid
        );
    }

    // Getters
    pub fn pressure(&self) -> f64 {self.pressure}
    pub fn temperature(&self) -> f64 {self.temperature}
    pub fn density(&self) -> f64 {self.density}
    pub fn sp_inenergy(&self) -> f64 {self.sp_inenergy}
    pub fn sp_enthalpy(&self) -> f64 {self.sp_enthalpy}
    pub fn sp_entropy(&self) -> f64 {self.sp_entropy}
    pub fn cp(&self) -> f64 {self.cp}
    pub fn cv(&self) -> f64 {self.cv}
    pub fn gamma(&self) -> f64 {self.gamma}
    pub fn speed_of_sound(&self) -> f64 {self.speed_of_sound}
    pub fn fluid(&self) -> &String {&self.props.fluid}
}

// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------

impl sim::Save for IntensiveState{
    fn save_data(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        runtime.add_or_set(&format!(
            "{prefix}.pressure [Pa]"),
            self.pressure
        );
        runtime.add_or_set(&format!(
            "{prefix}.temperature [degK]"),
            self.temperature
        );
        runtime.add_or_set(&format!(
            "{prefix}.density [kg/m^3]"),
            self.density
        );
        runtime.add_or_set(&format!(
            "{prefix}.sp_inenergy [J/kg]"),
            self.sp_inenergy
        );
        runtime.add_or_set(&format!(
            "{prefix}.sp_enthalpy [J/kg]"),
            self.sp_enthalpy
        );
        runtime.add_or_set(&format!(
            "{prefix}.sp_entropy [J/degK]"),
            self.sp_entropy
        );
        runtime.add_or_set(&format!(
            "{prefix}.speed_of_sound [m/s]"),
            self.speed_of_sound
        );
    }
    fn save_data_verbose(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.save_data(prefix, runtime);
        runtime.add_or_set(&format!(
            "{prefix}.cp [J/(kg*degK)]"),
            self.cp
        );
        runtime.add_or_set(&format!(
            "{prefix}.cv [J/(kg*degK)]"),
            self.cv
        );
        runtime.add_or_set(&format!(
            "{prefix}.gamma [-]"),
            self.cv
        );
    }
}