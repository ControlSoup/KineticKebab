const std = @import("std");
const sim = @import("../sim.zig");

pub const Steadyable = union(enum) {
    const Self = @This();

    UpwindedSteadyVolume: *sim.volumes.UpwindedSteadyVolume,

    pub fn name(self: *const Self) [] const u8{
        return switch(self.*){
            inline else => |impl| impl.name
        };
    }

    pub fn get_residuals(self: *const Self, pertb: []f64) ![]f64{
        return switch(self.*){
            inline else => |impl| try impl.get_residuals(pertb)
        };
    }

    pub fn get_intial_guess(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.get_intial_guess()
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

    pub fn get_max_steps(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.max_steps[0..]
        };
    }

    pub fn get_min_steps(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.min_steps[0..]
        };
    }

    pub fn get_tols(self: *const Self) []f64{
        return switch(self.*){
            inline else => |impl| impl.tols[0..]
        };
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

        try self.obj_list.append(steadyable);

        const guesses = steadyable.get_intial_guess();

        for (guesses) |g| try self.guesses_unfolded.append(g);
        
        try self.guess_delta.appendNTimes(std.math.nan(f64), guesses.len);
        try self.residuals.appendNTimes(std.math.nan(f64), guesses.len);
        try self.partials.resize_clear(self.residuals.items.len, self.residuals.items.len, std.math.nan(f64));
        
    }

    pub fn is_solved(self: *Self) !bool {

        var converged = true;
        var pos_tracker: usize = 0;
        for (self.obj_list.items) |obj|{
            const tols = obj.get_tols();
            const obj_guess = self.guesses_unfolded.items[pos_tracker..pos_tracker + tols.len];
            const residual = try obj.get_residuals(obj_guess);

            for (residual, tols) |r, tol| {
                if (r == std.math.nan(f64) or r == std.math.inf(f64)) {
                    try self.__print("Nan or Inf Residual");
                    return error.InvalidResidual;
                }
                if (@abs(r) > tol) converged = false;
                self.residuals.items[pos_tracker] = r;
                pos_tracker += 1;
            }
        }

        return converged;
    }

    // Seperating iter allows debugging itterations of the solutions 
    pub fn iter(self: *Self) !bool{

        if (self.obj_list.items.len == 0){
            return true;
        }

        if (try self.is_solved()) return true;

        var pos_tracker: usize = 0;
        for (self.obj_list.items) |obj|{
            
            const tols = obj.get_tols();
            const obj_guess = self.guesses_unfolded.items[pos_tracker.. pos_tracker + tols.len];

            for (obj_guess, 0..) |curr_guess, g_idx| {
                
                var perturb = curr_guess * 1.10;
                if (curr_guess == 0) perturb = 1e-6;

                const interval = curr_guess - perturb;

                const temp = obj_guess[g_idx];
                obj_guess[g_idx] = perturb; 

                // Itterate through all other objects
                var p_pos_tracker: usize = 0;
                for (self.obj_list.items) |p_obj|{

                    const p_tols = p_obj.get_tols();
                    for (
                        try p_obj.get_residuals(self.guesses_unfolded.items[p_pos_tracker.. p_pos_tracker + p_tols.len])
                    ) |residual| {
                        
                        const d_residual = self.residuals.items[p_pos_tracker] - residual;

                        var partial = d_residual / interval;
                        if (interval == 0.0) partial = 0.0; 

                        self.partials.set(pos_tracker, p_pos_tracker, partial);

                        p_pos_tracker += 1;
                    }
                }

                // Put the guess back for future objects
                obj_guess[g_idx] = temp;

                pos_tracker += 1;
            }
        }

        // Solve for new guesses
        try sim.math.ArrayMatrix.gaussian(&self.partials, &self.residuals, &self.guess_delta);

        // Update next guess per jacobian solve
        pos_tracker = 0;
        for (self.obj_list.items) |obj| {
            const maxes = obj.get_maxs();
            const mins = obj.get_mins();
            const max_steps = obj.get_max_steps();
            const min_steps = obj.get_min_steps();

            // Rate limit
            for (maxes, mins, max_steps, min_steps) |max, min, max_step, min_step|{
                
                const delta = self.guess_delta.items[pos_tracker];
                const curr_guess = self.guesses_unfolded.items[pos_tracker];

                var new_guess = curr_guess - self.guess_delta.items[pos_tracker];

                if (@abs(delta) > max_step) new_guess = curr_guess - (max_step * std.math.sign(delta));
                if (@abs(delta) < min_step) new_guess = curr_guess - (min_step * std.math.sign(delta));

                new_guess = @min(new_guess, max);
                new_guess = @max(new_guess, min);
                

                self.guesses_unfolded.items[pos_tracker] = new_guess;

                pos_tracker += 1;
            }

        }

        return false;
    }

    pub fn __print(self: *Self, comment: []const u8) !void{
        std.log.err("\n========================== Steady {s} ==========================\n", .{comment});

        var str = try std.fmt.allocPrint(self.partials.array_list.allocator, "", .{});
        for (self.obj_list.items) |obj|{
            const tols = obj.get_tols();
            for (0..tols.len) |i|{
                str = try std.fmt.allocPrint(self.partials.array_list.allocator, "{s}{s} [{d}], ", .{str, obj.name(), i});
            }
        }

        std.log.err("\nGuesses (unfolded) = {any}\n", .{self.guesses_unfolded.items});
        std.log.err("\nResiduals = {any}\n", .{self.residuals.items});
        std.log.err("\nObjects: {s}", .{str});
        try self.partials.__print("Partials");
    }

};