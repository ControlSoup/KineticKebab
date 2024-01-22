use crate::sim::Save;
use crate::volume::Volume;
use crate::sim;
use crate::props;
use super::FlowRestriction;
use roots;
use std::rc::Rc;

pub struct RealOrifice<V: Volume>{
    node_name: String,
    mdot: f64,
    cda: f64,
    velocity: f64,
    is_choked: bool,
    connection_in: Rc<V>,
    connection_out: Rc<V>
}

impl<V: Volume + Clone> RealOrifice<V>{
    pub fn new(
        node_name: &str,
        cda: f64,
        connection_in: Rc<V>,
        connection_out: Rc<V>
    ) -> Self{
        return RealOrifice{
            node_name: node_name.to_string(),
            mdot: 0.0,
            cda,
            velocity: 0.0,
            is_choked: false,
            connection_in,
            connection_out
        }
    }
}

impl<V: Volume + Clone> FlowRestriction<V> for RealOrifice<V>{
    fn calc_mdot(&mut self) -> f64{
        let state_in = self.connection_in.get_intensive_state();
        let state_out = self.connection_out.get_intensive_state();

        // Don't solve for very low dp
        if state_in.pressure() - state_out.pressure() < 1e-5{
            return 0.0
        };

        // Check if unchoked flow is plausible
        if state_in.pressure() / state_out.pressure() < 5.0{
            // Assume unchoked flow
            let throat_velocity = throat_vel(state_in.sp_enthalpy(), state_out.sp_enthalpy());

            // Check if its choked
            if throat_velocity <= state_in.speed_of_sound(){
                // Solve assuming throat matches downstream state
                self.velocity = throat_velocity;
                self.mdot = mdot(self.cda, state_out.density(), self.velocity);

                return self.mdot
            }
        }

        // If you make it here its choked
        self.is_choked = true;

        let throat_pressure = root_solve_throat_pressure(
            &state_in,
            state_out.pressure()
        );

        let throat_state = state_in.isentropic("P", throat_pressure);

        self.velocity = throat_state.speed_of_sound();
        self.mdot = mdot(self.cda, throat_state.density(), self.velocity);

        return self.mdot
    }

    fn get_connection_in(&mut self) -> Rc<V> {
        return Rc::clone(&self.connection_in)
    }
    fn get_connection_out(&mut self) -> Rc<V> {
       return Rc::clone(&self.connection_out)
    }

 }
// ----------------------------------------------------------------------------
// Save
// ----------------------------------------------------------------------------
impl<V: Volume + Clone> sim::Save for RealOrifice<V>{
    fn save_data(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        runtime.add_or_set(&format!(
            "{prefix}.cda [m^2]"),
            self.cda
        );
        runtime.add_or_set(&format!(
            "{prefix}.mdot [kg/s]"),
            self.mdot
        );
        runtime.add_or_set(&format!(
            "{prefix}.is_choked [-]"),
            self.is_choked as usize as f64
        );
    }
    fn save_data_verbose(&self, prefix: &str, runtime: &mut sim::Runtime) where Self: Sized {
        self.save_data(prefix, runtime);
        runtime.add_or_set(&format!(
            "{prefix}.velocity [m/s]"),
            self.velocity as usize as f64
        );
    }
}

// ----------------------------------------------------------------------------
// Update
// ----------------------------------------------------------------------------
impl<V: Volume + Clone> sim::Update for RealOrifice<V>{
    fn update(&mut self, runtime: &mut sim::Runtime) {

        // Save data
        self.save_data_verbose(&self.node_name, runtime);

        // Transfer mass and enthalpy
        self.transfer_state();
    }
}

// ----------------------------------------------------------------------------
// Real Mdot Lookup
// ----------------------------------------------------------------------------

pub fn throat_vel(upstream_sp_enthalpy: f64, downstream_sp_enthalpy: f64) -> f64{
    return (2.0 * (upstream_sp_enthalpy - downstream_sp_enthalpy)).sqrt()
}

pub fn mdot(cda: f64, density: f64, velocity: f64) -> f64{
    return velocity * density * cda
}

pub fn root_solve_throat_pressure(
    upstream: &props::IntensiveState,
    downstream_pressure: f64
) -> f64{


    // Use a closure to allow parent scope
    // Solve for throat enthalpy through isentropic expansion
    // Such that the throat velocity = mach 1
    let root_function = |pressure: f64| -> f64{

        let throat_state = upstream.isentropic("P", pressure);

        return throat_state.speed_of_sound() - throat_vel(
            upstream.sp_enthalpy(),
            throat_state.sp_enthalpy()
        )
    };

    // Root solve the defined closure above
    let mut convergency = roots::SimpleConvergency{eps:1e-5, max_iter:300};
    let root_result = roots::find_root_brent(
        downstream_pressure,
        upstream.pressure(),
        &root_function,
        &mut convergency
    );

    return root_result.unwrap()

}

