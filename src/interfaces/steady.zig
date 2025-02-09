const std = @import("std");
const sim = @import("../sim.zig");

pub const MAX_RESIDUALS = 2;

pub const Steadyable = union(enum) {
    const Self = @This();

    SteadyVolume: *sim.volumes.SteadyVolume,

    pub fn get_residuals(self: *const Self, pertb: [MAX_RESIDUALS]f64) ![MAX_RESIDUALS]f64{
        return switch(self.*){
            inline else => |impl| try impl.get_residuals(pertb)
        };
    }

    pub fn intial_guess(self: *const Self) [MAX_RESIDUALS]f64{
        return switch(self.*){
            inline else => |impl| impl.intial_guess()
        };
    }

    pub fn maxs(self: *const Self) [MAX_RESIDUALS]f64{
        return switch(self.*){
            inline else => |impl| impl.maxs()
        };
    }

    pub fn mins(self: *const Self) [MAX_RESIDUALS]f64{
        return switch(self.*){
            inline else => |impl| impl.mins()
        };
    }

    pub fn max_step_fracs(self: *const Self) [MAX_RESIDUALS]f64{
        return switch(self.*){
            inline else => |impl| impl.max_step_fracs()
        };
    }

    pub fn min_step_fracs(self: *const Self) [MAX_RESIDUALS]f64{
        return switch(self.*){
            inline else => |impl| impl.min_step_fracs()
        };
    }

    pub fn tols(self: *const Self) [MAX_RESIDUALS]f64{
        return switch(self.*){
            inline else => |impl| impl.tols()
        };
    }
}; 
    
pub const SteadySolver = struct{
    const Self = @This();

    obj_list: std.ArrayList(Steadyable),
    guesses: std.ArrayList([MAX_RESIDUALS]f64),
    partials: std.ArrayList([MAX_RESIDUALS]f64),
    residuals: std.ArrayList([MAX_RESIDUALS]f64),

    // =========================================================================
    // Methods
    // =========================================================================

    pub fn init(allocator: std.mem.Allocator) Self{
        return Self{
            .obj_list = std.ArrayList(Steadyable).init(allocator),
            .guesses = std.ArrayList([MAX_RESIDUALS]f64).init(allocator),
            .partials = std.ArrayList([MAX_RESIDUALS]f64).init(allocator),
            .residuals = std.ArrayList([MAX_RESIDUALS]f64).init(allocator),
        };
    }

    pub fn add_obj(self: *Self, steadyable: Steadyable) !void{
        try self.obj_list.append(steadyable);
        try self.guesses.append(steadyable.intial_guess());
        try self.partials.append([MAX_RESIDUALS]f64{-404.0, -404.0});
        try self.residuals.append([MAX_RESIDUALS]f64{-404.0, -404.0});

    }

    // Seperating iter allows debugging itterations of the solutions 
    pub fn iter(self: *Self) !bool{
        // Not using a linear algebra library, this is essentially the same as the jacobian approach 
        // instead of a matrix and Ax = B solution, the next guess is done with algebra for each "row" of the jacobian

        if (self.obj_list.items.len == 0){
            return true;
        }

        var converged = true;

        // 5% perteb?
        const frac_peturb = 0.05;

        // Mutable to prevent creating new ones each loop.... does compiler fix this anyway?
        var perturb = [1]f64{-404.0} ** MAX_RESIDUALS;
        var intervals = [1]f64{-404.0} ** MAX_RESIDUALS;
        var x1_res = [1]f64{-404.0} ** MAX_RESIDUALS;
        var x2_res = [1]f64{-404.0} ** MAX_RESIDUALS;
        var perturb_pos_val: f64 = -404.0;
        var perturb_neg_val: f64 = -404.0;
        var next_guess: f64 = -404.0;

        for (self.obj_list.items, 0..) |obj, i|{


            // Peterbations and residuls
            for (self.guesses.items[i], obj.maxs(), obj.mins(), 0..) |guess, max,  min, j|{

                perturb = self.guesses.items[i];

                if (guess > max){
                    self.guesses.items[i][j] = max;
                }

                if (guess < min){
                    self.guesses.items[i][j] = min;
                }

                perturb_pos_val = (1.0 + frac_peturb) * guess;
                perturb_neg_val = (1.0 - frac_peturb) * guess;

                intervals[j] = @abs(perturb_pos_val - perturb_neg_val);

                if (perturb_pos_val >  max){
                    perturb_pos_val = max;
                }

                if (perturb_neg_val < min){
                    perturb_neg_val = min;
                }

                // Perterb the element indepdent
                perturb[j] = perturb_pos_val;
                x1_res[j] = (try obj.get_residuals(perturb))[j];
                perturb[j] = perturb_neg_val;
                x2_res[j] = (try obj.get_residuals(perturb))[j];
            }

            self.residuals.items[i] = try obj.get_residuals(self.guesses.items[i]);

            // Partials + update guesses
            for (
                self.guesses.items[i], 
                self.residuals.items[i], 
                x1_res,
                x2_res,
                obj.tols(),
                // obj.max_step_fracs(),
                // obj.min_step_fracs(),
                0..
            ) |
                guess, 
                residual, 
                x1, 
                x2, 
                tol, 
                // max_step_frac,
                // min_step_frac, 
                j
            | {

                // If all residuals are < tolerance then convergence will happen
                if (@abs(residual) > tol) converged = false;

                // Compute partials
                const partial: f64 = (x1 - x2) / (intervals[j] + 1e-10); // precent nans by adding a small number
                self.partials.items[i][j] = partial;

                // Update next guess (newton method with the computed partial)
                next_guess = guess - (residual / (partial + 1e-10));

                const is_positive = next_guess >= 0;

                // Clamp the step size

                // if (@abs(next_guess - guess) > @abs(guess * (1.0 + max_step_frac))){
                //     next_guess = @abs(guess * (1.0 + max_step_frac));
                // }

                // if (@abs(next_guess - guess) < @abs(guess * min_step_frac)){
                //     next_guess =  @abs(guess *  min_step_frac);
                // }

                if (!is_positive) next_guess = -next_guess;

                self.guesses.items[i][j] = next_guess;
            }
            std.log.err("Residuals: {any}\n", .{self.residuals.items});
            std.log.err("Converged: {any}\n", .{converged});

        }

        return converged;
    }

};