use std::f64::INFINITY;

use crate::props;
use crate::sim;

use super::Volume;

pub struct InfiniteVolume{
    node_name: String,
    fluid_state: props::FluidState,

}

impl InfiniteVolume{
    fn new(node_name: &str, pressure: f64, temperature: f64, fluid_lookup: F) -> Self{
        return InfiniteVolume{
            node_name: node_name.to_string(),
            fluid_state: props::FluidState::new_from_ptv(
                pressure,
                temperature,
                INFINITY,
                fluid
            )
        }
    }
}

// ----------------------------------------------------------------------------
// Volume
// ----------------------------------------------------------------------------

impl<F: props::Fluid + Sized> Volume for InfiniteVolume<F>{
    fn get_conservation(&mut self) -> Option<&mut super::ConserveME> {None}
    fn get_fluidstate(&mut self) -> &props::FluidState<F> {
        return &self.fluid_state
    }
}

// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------

impl<F: props::Fluid> sim::Save for InfiniteVolume<F>{
    fn save_data(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.fluid_state.save_data(&self.node_name, runtime);
    }
    fn save_data_verbose(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.fluid_state.save_data_verbose(&self.node_name, runtime);
    }
}

// ----------------------------------------------------------------------------
// Update
// ----------------------------------------------------------------------------

impl<F: props::Fluid> sim::Update for InfiniteVolume<F>{
    fn update(&mut self) {}
}