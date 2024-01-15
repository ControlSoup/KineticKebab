use super::ConserveME;

use crate::properties as props;
use crate::flow;
use crate::sim;

use super::Volume;

pub struct TransientVolume<F: props::Fluid>{
    node_name: String,
    fluid_state: props::FluidState<F>,
    conservation: ConserveME
}

impl<F: props::Fluid> TransientVolume<F>{
    fn new(
        node_name: String,
        volume: f64,
        pressure: f64,
        temperature: f64,
        fluid: F
    ) -> TransientVolume<F>{
        let fluid_state = props::FluidState::<F>::new_from_ptv(
            pressure,
            temperature,
            volume,
            fluid,
        );

        let conservation = ConserveME::zeros();

        return TransientVolume{
            node_name,
            fluid_state,
            conservation
        }
    }
}

// ----------------------------------------------------------------------------
// Volume
// ----------------------------------------------------------------------------

impl<F: props::Fluid> Volume for TransientVolume<F>{
    fn get_conservation(&mut self) -> Option<&mut ConserveME> {
        return Some(&mut self.conservation)
    }
    fn get_fluidstate(&mut self) -> &props::FluidState<F> {
        return &mut self.fluid_state
    }
}

// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------

impl<F: props::Fluid> sim::Save for TransientVolume<F>{
    fn save_data(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.conservation.save_data(&self.node_name, runtime);
        self.fluid_state.save_data(&self.node_name, runtime);
    }
    fn save_data_verbose(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.conservation.save_data_verbose(&self.node_name, runtime);
        self.fluid_state.save_data_verbose(&self.node_name, runtime);
    }
}

// ----------------------------------------------------------------------------
// Update
// ----------------------------------------------------------------------------

impl<F: props::Fluid> sim::Update for TransientVolume<F>{
    fn update(&mut self) {
        self.conservation.perform_conservation(&mut self.fluid_state);
    }
}


