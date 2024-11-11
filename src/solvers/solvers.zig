const std = @import("std");
const sim = @import("../sim.zig");

// Maximum number of state variables an object can have (used to prevent allocations for integration)
pub const MAX_STATE_LEN = 9;


pub const Integrator = struct{
    const Self = @This();

    obj_list: std.ArrayList(Integratable),
    curr_states: std.ArrayList([MAX_STATE_LEN]f64),

    pub const RESULT = struct{
        dt: f64,
        accepted_dt: f64, 
        curr_rel_err: f64
    };

    pub fn init(
        allocator: std.mem.Allocator,
    ) Self{
        return Self{
            .obj_list =  std.ArrayList(Integratable).init(allocator),
            .curr_states = std.ArrayList([MAX_STATE_LEN]f64).init(allocator),
        };
    }

    pub fn add_obj(self: *Self, obj: Integratable) !void{
        try self.obj_list.append(obj);
        try self.curr_states.append([1]f64{-404.0} ** MAX_STATE_LEN);
    } 

    pub fn integrate(self: *Self, dt: f64, max_dt: f64, min_dt: f64, err_allow: f64, last_err: f64, enforce_dt: bool) !RESULT{
        
        if (self.obj_list.items.len == 0){
            return RESULT{.dt = dt, .accepted_dt = dt, .curr_rel_err = 0.0};
        }

        var step_accepted: bool = false;
        var accepted_dt: f64 = dt;
        var new_dt: f64 = dt;


        var curr_max_err: f64 = 0.0;

        // Find an acceptable step size (should there be a cap on itterations?)
        while (!step_accepted){

            curr_max_err = 0.0;


            // Itterate through integratable objects getting a solution, rk45 was giving 0 error so switched to this?
            for (self.obj_list.items, 0..) |obj, i|{
                var new_state = obj.rk4(new_dt);
                var current_state = obj.get_state();
                
                const new_norm = sim.math.slice_norm(f64, new_state[0..]);
                const last_norm = sim.math.slice_norm(f64, current_state[0..]);
                const new_rel_err = sim.math.relative_err(f64, new_norm, last_norm);

                if(curr_max_err < new_rel_err) curr_max_err = new_rel_err;

                self.curr_states.items[i] = new_state;
            }

            if (curr_max_err <= err_allow or (new_dt == max_dt) or (new_dt == min_dt) or enforce_dt){
                step_accepted = true; 
                accepted_dt = new_dt;
            }


            // Compute the new dt
            new_dt = new_t_step(err_allow, curr_max_err, last_err, 5, new_dt);

            // Enforce the limits for the next time step if required
            if (new_dt > max_dt){
                new_dt = max_dt;
            }
            
            if (new_dt < min_dt){
                new_dt = min_dt;
            }


            // If the next time step is a huge jump up, rate limit
            if (new_dt > dt * 3){
                new_dt =  3 * dt;
            }

        } 


        // Store all the cached states
        for (self.obj_list.items, 0..) |obj, i|{
            obj.set_state(self.curr_states.items[i]);
        }

        return RESULT{.dt = new_dt, .accepted_dt = accepted_dt, .curr_rel_err = curr_max_err};
    }

};

pub fn new_t_step(tol_rel: f64, rel_now: f64, rel_last: f64, order: f64, old_dt: f64) f64{
    const a = std.math.pow(f64, 0.8 * tol_rel / rel_now, 0.3 / order);
    const b = std.math.pow(f64, rel_last / rel_now, 0.4 / order);
    return a * b * old_dt;
}


pub const Integratable = union(enum) {
    const Self = @This();

    Motion3DOF: *sim.motions.d3.Motion,
    Motion1DOF: *sim.motions.d1.Motion,
    Volume: sim.volumes.Volume,

    pub const RESULT = struct{
        rel_err: f64,
        state: [MAX_STATE_LEN]f64    
    };

    pub fn name(self: *const Self) []const u8 {
        return switch (self.*) {
            .Volume => |impl| impl.name(),
            inline else => |m| m.name,
        };
    }

    pub fn get_state(self: *const Self) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            inline else => |m| m.get_state(),
        };
    }

    pub fn get_dstate(self: *const Self, state: [MAX_STATE_LEN]f64) [MAX_STATE_LEN]f64 {
        return switch (self.*) {
            inline else => |m| m.get_dstate(state),
        };
    }

    pub fn set_state(self: *const Self, state: [MAX_STATE_LEN]f64) void {
        return switch (self.*) {
            .Volume => |impl| switch (impl){
                .Void => return,
                inline else => |m| m.set_state(state),
            },
            inline else => |m| m.set_state(state),
        };
    }

    pub fn rk4(self: *const Self, dt: f64) [MAX_STATE_LEN]f64 {

        const intial_state = self.get_state();

        const k1 = self.get_dstate(intial_state);

        var k2 = [1]f64{1e9}**MAX_STATE_LEN; 
        for (intial_state, 0..) |state,i|{
            k2[i] = state + (k1[i] * dt / 2.0);  
        }
        k2 = self.get_dstate(k2);
        
        var k3 = [1]f64{1e9}**MAX_STATE_LEN; 
        for (intial_state, 0..) |state,i|{
            k3[i] = state + (k2[i] * dt / 2.0);  
        }
        k3 = self.get_dstate(k3);

        var k4 = [1]f64{1e9}**MAX_STATE_LEN; 
        for (intial_state, 0..) |state,i|{
            k4[i] = state + (k3[i] * dt);  
        }
        k4 = self.get_dstate(k4);

        var result = [1]f64{1e9}**MAX_STATE_LEN; 
        for (intial_state, 0..) |state, i|{
            result[i] = state + ((dt / 6.0) * (k1[i] + (k2[i] * 2.0) + (k3[i] * 2.0) + k4[i])); 
        }

        return result;
    }

    pub fn rk45_adaptive(self: *const Self,  dt: f64) RESULT{

        const intial_state = self.get_state();


        // k1 = h * odefun(tn, yn);
        var k1 = self.get_dstate(intial_state);
        sim.math.slice_product_constant(f64, k1[0..], dt);

        // k2 = h * odefun(tn+h/4, yn+k1/4);
        var k2 = [1]f64{1e9} ** MAX_STATE_LEN;
        for (intial_state, 0..) |yn, i|{
            k2[i] = yn + (k1[i] / 4.0);
            k2[i] *= dt;
        }
        k2 = self.get_dstate(k2);

        // k3 = h * odefun(tn+h*3/8, yn + k1*3/32 + k2*9/32);
        var k3 = [1]f64{1e9} ** MAX_STATE_LEN;
        for (intial_state, 0..) |yn, i|{
            k3[i] = yn + (k1[i] * 3.0 / 32.0) + (k2[i] * 9.0 / 32.0);
            k3[i] *= dt;
        }
        k3 = self.get_dstate(k3);

        // k4 = h * odefun(tn+h*12/13, yn + k1*1932/2197 - k2*7200/2197 + k3*7296/2197);
        var k4 = [1]f64{1e9} ** MAX_STATE_LEN;
        for (intial_state, 0..) |yn, i|{
            k4[i] = yn + (k1[i] * 1932.0 / 2197.0) - (k2[i] * 7200.0 / 2197.0) + (k3[i] * 7296.0 / 2197.0);
            k4[i] *= dt;
        }
        k4 = self.get_dstate(k4);

        // k5 = h * odefun(tn+h, yn + k1*439/216 - 8*k2 + k3*3680/513 - k4*845/4104);
        var k5 = [1]f64{1e9} ** MAX_STATE_LEN;
        for (intial_state, 0..) |yn, i|{
            k5[i] = yn + (k1[i] * 439.0 / 216.0) - (k2[i] * 8.0) + (k3[i] * 3680.0 / 513.0) - (k4[i] * 845.0 / 4104.0);
            k5[i] *= dt;
        }
        k5 = self.get_dstate(k5);

        // k6 = h * odefun(tn+h/2, yn - k1*8/27 + k2*2 - k3*3544/2565 + k4*1859/4104 - k5*11/40);
        var k6 = [1]f64{1e9} ** MAX_STATE_LEN;
        for (intial_state, 0..) |yn, i|{
            k6[i] = yn - (k1[i] * 8.0 / 27.0) + (k2[i] * 2.0) - (k3[i] * 3544.0 / 2565) + (k4[i] * 1859.0 / 4104) - (k5[i] * 11.0 / 40.0);
            k6[i] *= dt;
        }
        k6 = self.get_dstate(k6);

        // Y = yn + 25/216*k1 + 1408/2565*k3 + 2197/4104*k4 - 1/5*k5;
        var y = [1]f64{1e9} ** MAX_STATE_LEN;
        for (intial_state, 0..) |yn, i|{
            y[i] = yn + (k1[i] * 25.0 / 216.0) + (k3[i] * 1408.0 / 2565.0) + (k4[i] * 2197.0 / 4104.0) - (k5[i] / 5.0);
        }

        // Z = yn + 16/135*k1 + 6656/12825*k3 + 28561/56430*k4 - 9/50*k5 + 2/55*k6;
        var z = [1]f64{1e9} ** MAX_STATE_LEN;
        for (intial_state, 0..) |yn, i|{
            z[i] = yn + (k1[i] * 16.0 / 135.0) + (k3[i] * 6656.0 / 12825.0) + (k4[i] * 28561.0 / 56430.0) - (k5[i] * 9.0 / 50.0) + (k6[i] * 2.0 / 55.0);
        }


        const norm_y = sim.math.slice_norm(f64, y[0..]);
        const norm_z = sim.math.slice_norm(f64, z[0..]);

        return RESULT{
            .rel_err =  sim.math.relative_err(f64, norm_y, norm_z),
            .state = y,
        };
    }

    // =========================================================================
    // SimObject
    // =========================================================================

    pub fn get_header(self: *const Self) []const []const u8 {
        return switch (self.*) {
            .Motion1DOF => return sim.motions.d1.Motion.header[0..],
            .Motion3DOF => return sim.motions.d3.Motion.header[0..],
            .Volume => |impl| return impl.get_header()
        };
    }

    pub fn save_vals(self: *const Self, save_array: []f64) void {
        return switch (self.*) {
            inline else => |impl| return impl.save_vals(save_array),
        };
    }

    pub fn set_vals(self: *const Self, save_array: []f64) void {
        return switch (self.*) {
            inline else => |impl| return impl.set_vals(save_array),
        };
    }

    pub fn save_len(self: *const Self) usize {
        return switch (self.*) {
            .Motion1DOF => return sim.motions.d1.Motion.header.len,
            .Motion3DOF => return sim.motions.d3.Motion.header.len,
            .Volume => |impl| return impl.save_len()
        };
    }

    pub fn update(self: *const Self) !void {
        switch (self.*) {
            inline else => |impl| try impl.update(),
        }
    }
};