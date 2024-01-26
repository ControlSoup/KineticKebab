use std::ops::Add;
use crate::sim;
use crate::props;
use crate::sim::Integrate;
use crate::sim::Save;
use super::{ConserveME, Volume};

pub struct TransientVolume{
    node_name: String,
    intensive_state: props::IntensiveState,
    conservation: ConserveME,
    volume: f64
}

impl TransientVolume{
    fn new_from_vpt(
        node_name: &str,
        volume: f64,
        pressure: f64,
        temperature: f64,
        fluid: &str
    ) -> TransientVolume{
        let intensive_state = props::IntensiveState::new_from_pt(
            pressure,
            temperature,
            fluid
        );

        let mass = intensive_state.density() * volume;
        let inenergy = mass * intensive_state.sp_inenergy();

        return TransientVolume{
            node_name: node_name.to_string(),
            intensive_state,
            conservation: ConserveME::new_from_mu(mass, inenergy),
            volume,
        }
    }

}

impl Volume for TransientVolume{
    fn get_conservation(&mut self) -> Option<Box<ConserveME>> {
        return Some(Box::new(self.conservation))
    }
    fn get_intensive_state(&self) -> &props::IntensiveState{
        return &self.intensive_state
    }
}

// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------

impl sim::Save for TransientVolume{
    fn save_data(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        runtime.add_or_set(&format!(
            "{prefix}.volume [m^3]"),
            self.volume
        );
        self.intensive_state.save_data(prefix, runtime);
        self.conservation.save_data(prefix, runtime);
    }
    fn save_data_verbose(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        runtime.add_or_set(&format!(
            "{prefix}.volume [m^3]"),
            self.volume
        );
        self.intensive_state.save_data_verbose(prefix, runtime);
        self.conservation.save_data_verbose(prefix, runtime);
    }
}

// ----------------------------------------------------------------------------
// Update
// ----------------------------------------------------------------------------

impl sim::Update for TransientVolume{
    fn update(&mut self, runtime: &mut sim::Runtime) {
        // Save data
        self.save_data_verbose(&self.node_name, runtime);

        // Integrate mass conversation
        self.conservation.perform_conservation();
        self.conservation.rk4(runtime.get_dx());

        // Update fluid state based on this new conservation
        let new_density = self.conservation.mass / self.volume;
        let new_sp_inenergy = self.conservation.inenergy / self.conservation.mass;
        self.intensive_state.update_from_du(new_density, new_sp_inenergy);

    }
}
