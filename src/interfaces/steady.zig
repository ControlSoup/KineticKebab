const std = @import("std");
const sim = @import("../sim.zig");

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

                const perturb_frac = 1.01;
                const perturb = curr_guess * perturb_frac;
                const interval = perturb - curr_guess;
                const temp = obj_guess[g_idx];
                obj_guess[g_idx] = perturb; 

                // Itterate through all other objects
                var p_pos_tracker: usize = 0;
                for (self.obj_list.items) |p_obj|{

                    const p_tols = p_obj.get_tols();
                    for (
                        try p_obj.get_residuals(self.guesses_unfolded.items[p_pos_tracker.. p_pos_tracker + p_tols.len])
                    ) |residual| {
                        
                        self.residuals.items[p_pos_tracker] = residual;

                        const partial = self.residuals.items[p_pos_tracker] - residual / interval;

                        std.log.err("{d}, {d}", .{pos_tracker, p_pos_tracker});
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
        try self.__print("GAUSE TIME");
        try sim.math.ArrayMatrix.gaussian(&self.partials, &self.residuals, &self.guess_delta);

        // Update next guess per jacobian solve
        for (self.guess_delta.items, 0..) |delta, i|{
            self.guesses_unfolded.items[i] -= delta;
        }

        return false;
    }

    pub fn __print(self: *Self, comment: []const u8) !void{
        std.log.err("\n========================== Steady {s} ==========================\n", .{comment});
        std.log.err("\nGuesses (unfolded) = {any}\n", .{self.guesses_unfolded.items});
        std.log.err("\nGuesses Delta (unfolded) = {any}\n", .{self.guess_delta.items});
        std.log.err("\nResiduals = {any}\n", .{self.residuals.items});
        try self.partials.__print("Partials");
    }

};