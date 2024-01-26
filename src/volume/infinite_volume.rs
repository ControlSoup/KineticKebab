use std::f64::INFINITY;

use crate::props;
use crate::sim;
use crate::sim::Save;

use super::Volume;

#[derive(Clone)]
pub struct InfiniteVolume{
    node_name: String,
    intensive_state: props::IntensiveState

}

impl InfiniteVolume{
    pub fn new(node_name: &str, pressure: f64, temperature: f64, fluid: &str) -> Self{
        return InfiniteVolume{
            node_name: node_name.to_string(),
            intensive_state: props::IntensiveState::new_from_pt(pressure, temperature, fluid)
        }
    }
    pub fn atm(node_name: &str, fluid: &str) -> Self{
        return InfiniteVolume{
            node_name: node_name.to_string(),
            intensive_state: props::IntensiveState::new_from_pt(
                props::STD_ATM_PA,
                props::STD_ATM_DEGK,
                fluid
            )
        }
    }
}

// ----------------------------------------------------------------------------
// Volume
// ----------------------------------------------------------------------------

impl Volume for InfiniteVolume{
    fn get_conservation(&mut self) -> Option<Box<super::ConserveME>> {
        return None
    }
    fn get_intensive_state(&self) -> &props::IntensiveState{
        return &self.intensive_state
    }
}

// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------

impl sim::Save for InfiniteVolume{
    fn save_data(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.intensive_state.save_data(&self.node_name, runtime);
    }
    fn save_data_verbose(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.intensive_state.save_data_verbose(&self.node_name, runtime);
    }
}

// ----------------------------------------------------------------------------
// Update
// ----------------------------------------------------------------------------

impl sim::Update for InfiniteVolume{
    fn update(&mut self, runtime: &mut sim::Runtime) {
        self.save_data_verbose(&self.node_name, runtime)
    }
}