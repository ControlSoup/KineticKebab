const std = @import("std");
const clap = @import("clap");
const sim = @import("sim.zig");
const builtin = @import("builtin");
const json_sim = @import("config/create_from_json.zig").json_sim;

const DELIMITER: u8 = 0;

const errors = error{
    InvalidArgs
};

pub fn main() !void {
    // ========================================================================= 
    // Allocation
    // ========================================================================= 
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();


    // ========================================================================= 
    // Stdin / Stdout
    // ========================================================================= 

    // First we specify what parameters our program can take.
    // We can use `parseParamsComptime` to parse a string into an array of `Param(Help)`
    const params = comptime clap.parseParamsComptime(
        \\-h, --help             help info 
        \\-i, --input <str>      File Path to the simulation json
        \\-r, --raw <str>        Raw json instead of a file input 
        \\-d, --duration <f64>   Duration to run the simulation
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(
        clap.Help, 
        &params, 
        clap.parsers.default, .{.diagnostic = &diag, .allocator = allocator}
    ) catch |err| {
            diag.report(std.io.getStdErr().writer(), err) catch {};
            return err;
    };
    defer res.deinit();

    if (res.args.input != null and res.args.raw != null){
        std.log.err("ERROR| Cannont use -i/--input and -r/--raw at the same time, please use only one", .{});
        return errors.InvalidArgs; 
    }

    if (res.args.help != 0)
        std.debug.print("--help\n", .{});


    var json_buffer = std.ArrayList(u8).init(allocator);
    defer json_buffer.deinit();

    if (res.args.input) |n|{

        const file: std.fs.File = try std.fs.cwd().openFile(n, .{.mode = .read_write}); 
        defer file.close();

        const file_size = (try file.stat()).size;
        const buffer = try allocator.alloc(u8, file_size);
        defer allocator.free(buffer);
        try file.reader().readNoEof(buffer);

        for (buffer) |char|{
            try json_buffer.append(char);
        }

    }

    if (res.args.raw) |r|{
        for (r) |char|{
            try json_buffer.append(char);
        }
    }

    var duration: f64 = 0.0;
    if (res.args.duration) |d|{
        duration = d;
    } else{
        std.log.err("ERROR| Please specify a duraion to run the sim with -d/--duration", .{});
        return errors.InvalidArgs;
    }

    

    // ========================================================================= 
    // Sim
    // ========================================================================= 

    std.log.info("Loaded sim : \n{s}\n", .{json_buffer.items});
    const json_sim_result = try json_sim(allocator, json_buffer.items);

    std.log.info("Running sim for [{d:0.8}s]", .{duration});
    try json_sim_result.step_duration(duration);

    try json_sim_result.end();
    std.log.info("Simulation Complete", .{});
}