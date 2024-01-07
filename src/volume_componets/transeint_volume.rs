use crate::properties;
use crate::flow_componets;
use crate::sim;

pub struct TransientVolume<F: properties::Fluid, O: flow_componets::FlowComponet>{
    temperature: f64,
    pressure: f64,
    density: f64,
    volume: f64,
    mdot: f64,
    mdot_in: f64,
    mdot_out: f64,
    mass: f64,
    udot: f64,
    energy: f64,
    energy_in: f64,
    energy_out: f64,
    enthalpy: f64,
    fluid: F,
    connections_in: Vec<Box<O>>,
    connections_out: Vec<Box<O>>,

}

impl<F: properties::Fluid, O: flow_componets::FlowComponet> TransientVolume<F, O>{
    /// Intializes a new static volume
    ///
    /// Specify the intial pressure, temperature, volume and the fluid in use to create a new instance
    fn new(
        pressure: f64,
        temperature: f64,
        volume: f64,
        fluid: F,
        connections_in: Vec<Box<O>>,
        connections_out: Vec<Box<O>>
    ) -> TransientVolume<F,O>{

        let density = fluid.density_pt_lookup(pressure, temperature);

        return TransientVolume{
            temperature,
            pressure,
            density,
            volume,
            mdot: 0.0,
            mdot_in: 0.0,
            mdot_out: 0.0,
            mass: density * volume,
            udot: 0.0,
            energy: fluid.energy_pt_lookup(pressure, temperature),
            energy_in: 0.0,
            energy_out: 0.0,
            enthalpy: fluid.enthalpy_pt_lookup(pressure, temperature),
            fluid,
            connections_in,
            connections_out
        }
    }

    fn pt_lookup(&mut self){
        self.pressure = self.fluid.pressure_du_lookup(self.density, self.energy);
        self.temperature = self.fluid.temperature_du_lookup(self.density, self.energy);
        self.enthalpy = self.fluid.enthalpy_pt_lookup(self.pressure, self.temperature);
    }

    fn update_connections(&mut self){
        // Conections in
        for i in self.connections_in.iter_mut(){
            let component = &mut *i;
            let mdot = component.calc_mdot(
                self.pressure,
                self.density,
                101000.0,
                self.fluid.get_gamma()
            );
            self.mdot_in += mdot;
            self.energy_in += mdot * self.enthalpy
        }

        // Conections out
        for i in self.connections_out.iter_mut(){
            let component = &mut *i;
            let mdot = component.calc_mdot(
                self.pressure,
                self.density,
                101000.0,
                self.fluid.get_gamma()
            );
            self.mdot_out += mdot;
            self.energy_out += mdot * self.enthalpy
        }

        // Update equations justed
        self.mdot = self.mdot_in - self.mdot_out;
        self.udot = self.energy_in - self.energy_out;

        // Clear properties for the next time
        self.mdot_in = 0.0;
        self.mdot_out = 0.0;
        self.energy_in = 0.0;
        self.energy_out = 0.0;
    }
}

impl<F: properties::Fluid, O: flow_componets::FlowComponet>
    sim::Integrate for TransientVolume<F,O>
    where TransientVolume<F,O>: Clone
{
    fn effects(&mut self) {
        self.update_connections();
    }
    fn get_derivative(&self)-> Self {
        let mut d = self.clone();
        d.mass = self.mdot;
        d.energy = self.udot;
        d.mdot = 0.0;
        d.udot = 0.0;
        return d
    }
}

