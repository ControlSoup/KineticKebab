const std = @import("std");
const sim = @import("../sim.zig");

pub const MAX_RESIDUALS = 2;

pub const Steadyable = union(enum) {
    const Self = @This();

    SteadyVolume: *sim.volumes.SteadyVolume,

    pub fn get_residuals(self: *const Self, pertb: []f64) ![]f64{
        return switch(self.*){
            inline else => |impl| try impl.get_residuals(pertb)
        };
    }

    pub fn get_intial_guess(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.intial_guess()
        };
    }

    pub fn get_maxs(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.maxs[0..]
        };
    }

    pub fn get_mins(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.mins[0..]
        };
    }

    pub fn get_max_step_fracs(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.max_step_fracs[0..]
        };
    }

    pub fn get_min_step_fracs(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.min_step_fracs[0..]
        };
    }

    pub fn get_tols(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.tols[0..]
        };
    }

    pub fn __runtime_testing_check(self: *const Self) !bool{
        try std.testing.expect(self.get_intial_guess().len == (try self.get_residuals(self.get_intial_guess())).len);
        try std.testing.expect(self.get_intial_guess().len == self.get_maxs().len);
        try std.testing.expect(self.get_intial_guess().len == self.get_mins().len);
        try std.testing.expect(self.get_intial_guess().len == self.get_max_step_fracs().len);
        try std.testing.expect(self.get_intial_guess().len == self.get_min_step_fracs().len);
        try std.testing.expect(self.get_intial_guess().len == self.get_tols().len);

        return true;
    }
}; 
    
pub const SteadySolver = struct{
    const Self = @This();

    obj_list: std.ArrayList(Steadyable),
    perterb_positive: std.ArrayList(f64),
    residuals: std.ArrayList(f64),
    guesses_unfolded: std.ArrayList(f64),
    guess_delta: std.ArrayList(f64),
    partials: sim.math.ArrayMatrixf64,

    // =========================================================================
    // Methods
    // =========================================================================

    pub fn init(allocator: std.mem.Allocator) Self{
        return Self{
            .obj_list = std.ArrayList(Steadyable).init(allocator),
            .perterb_positive = std.ArrayList(f64).init(allocator),
            .residuals = std.ArrayList(f64).init(allocator),
            .guesses_unfolded = std.ArrayList(f64).init(allocator),
            .guess_delta = std.ArrayList(f64).init(allocator),
            .partials = sim.math.ArrayMatrixf64.init(allocator),
        };
    }

    pub fn create(allocator: std.mem.Allocator) *Self{
        const ptr = allocator.create(Self);
        ptr.* = init(allocator);
        return ptr;
    }

    pub fn add_obj(self: *Self, steadyable: Steadyable) !void{

        std.testing.expect(try steadyable.__runtime_testing_check()) catch |err|{
            std.log.err("The programmer has failed to do his job, and has given you a object that is not solvable.... please contact him\n {!}", .{err});
        };

        try self.obj_list.append(steadyable);

        const guesses = steadyable.get_intial_guess();
        for (guesses) |g|{
            try self.guesses_unfolded.append(g);
        }
        
        try self.guess_delta.appendNTimes(std.math.nan(f64), guesses.len);
        try self.perterb_positive.appendNTimes(std.math.nan(f64), guesses.len);
        try self.residuals.appendNTimes(std.math.nan(f64), guesses.len);
        try self.partials.resize_clear(self.residuals.items.len, self.residuals.items.len, std.math.nan(f64));
        
    }

    pub fn __update_except_index(self: *Self, guess: *std.ArrayList(f64), obj_index: usize) !void{
        for (self.obj_list.items, 0..) |obj, i|{

            if (i == obj_index) continue;

            const len = obj.get_tols().len;
            _ = try obj.get_residuals(guess.items[sim.math.ArrayMatrix.to_1d(i, 0, len)..sim.math.ArrayMatrix.to_1d(i, len, len)]);

        }
    }

    // Seperating iter allows debugging itterations of the solutions 
    pub fn iter(self: *Self) !bool{

        if (self.obj_list.items.len == 0){
            return true;
        }

        // Check for convergence befor setpping into perturbations
        var converged = true;
        var _break_ = false;
        for (self.obj_list.items, 0..) |obj, i|{
            const tols = obj.get_tols();

            const obj_guess = self.guesses_unfolded.items[
                sim.math.ArrayMatrix.to_1d(i, 0, tols.len)..sim.math.ArrayMatrix.to_1d(i, tols.len, tols.len)
            ]; 

            for (try obj.get_residuals(obj_guess), tols, 0..) |res, tol, j|{
                self.residuals.items[sim.math.ArrayMatrix.to_1d(i, j, tols.len)] = res;

                if (res == std.math.nan(f64)){
                    _break_ = true;
                    converged = false;
                }

                if (@abs(res) > tol){
                    _break_ = true;
                    converged = false;
                }

            }

            if (_break_) break;
        }
        if (converged) return converged;

        const perturb_frac = 0.01;

        // Have to re-run itteration through the objects if no convergence is found
        for (self.obj_list.items, 0..) |obj, i|{
            
            const tols = obj.get_tols();
            const obj_guess = self.guesses_unfolded.items[
                sim.math.ArrayMatrix.to_1d(i, 0, tols.len)..sim.math.ArrayMatrix.to_1d(i, tols.len, tols.len)
            ];


            for (0..tols.len) |j|{

                const perturb_interval = perturb_frac * obj_guess[j];

                // Perturb high 
                obj_guess[j] += perturb_interval;

                // Itterate all other objects
                for (self.obj_list.items, 0..) |p_obj, k| {

                    try self.__update_except_index(&self.guesses_unfolded, k);
                    const p_obj_len = p_obj.get_tols().len;
                    const p_obj_guess = self.guesses_unfolded.items[
                        sim.math.ArrayMatrix.to_1d(k, 0, tols.len)..sim.math.ArrayMatrix.to_1d(k, p_obj_len, p_obj_len)
                    ];

                    const p_residual = try p_obj.get_residuals(p_obj_guess);

                    // Save residual result from perturb
                    for (p_residual, 0..) |p_res, l| {
                        self.perterb_positive.items[sim.math.ArrayMatrix.to_1d(k, l, p_obj_len)] = p_res;
                    }

                }

                for (self.perterb_positive.items, 0..) |p_pos, k|{
                    const partial = (p_pos - self.residuals.items[k]) / perturb_interval;
                    self.partials.set(j, k, partial);
                }

                // Put guess back where it was for next partial
                obj_guess[j] += perturb_interval;

            }

        }

        // Solve for new guesses
        try self.__print("GAUSE TIME");
        try sim.math.ArrayMatrix.gaussian(&self.partials, &self.residuals, &self.guess_delta);

        // Update next guess per jacobian solve
        for (self.guess_delta.items, 0..) |delta, i|{
            self.guesses_unfolded.items[i] -= delta;
        }

        return converged;
    }

    pub fn __print(self: *Self, comment: []const u8) !void{
        std.log.err("\n========================== Steady {s} ==========================\n", .{comment});
        std.log.err("\nGuesses (unfolded) = {any}\n", .{self.guesses_unfolded.items});
        std.log.err("\nGuesses Delta (unfolded) = {any}\n", .{self.guess_delta.items});
        std.log.err("\nResiduals = {any}\n", .{self.residuals.items});
        try self.partials.__print("Partials");
    }

};