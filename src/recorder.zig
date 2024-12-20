const std = @import("std");
const sim = @import("sim.zig");

const empty_string = "";

pub const SimRecorder = struct{
    const Self = @This();

    allocator: std.mem.Allocator,
    file_path: []const u8,
    header_len: usize,
    pool_len: usize,
    pool_idx: usize = 0,
    contents: std.ArrayList(std.ArrayList(f64)),
    last_record_time: f64 = 0.0,
    min_dt: f64 = 1e-3,
    is_deleted: bool = false,

    pub fn init(
        allocator: std.mem.Allocator, 
        file_path: []const u8, 
        header: [][]const u8, 
        pool_len: usize,
        min_dt: f64,
    ) !Self{
        _ = std.fs.cwd().deleteFile(file_path) catch undefined;
        const file = try std.fs.cwd().createFile(file_path, .{});    
        defer file.close();

        var buffer: []const u8 = empty_string[0..];
        
        // Write the header
        for (0..header.len - 1) |i|{
            buffer = try std.fmt.allocPrint(allocator, "{s}{s},", .{buffer, header[i]});
        }

        _ = try file.writer().writeAll(
            try std.fmt.allocPrint(allocator, "{s}{s}\n", .{buffer, header[header.len - 1]})
        );

        return Self{
            .allocator = allocator,
            .file_path = file_path,
            .header_len = header.len,
            .pool_len = pool_len - 1,
            .contents = try std.ArrayList(std.ArrayList(f64)).initCapacity(allocator, pool_len - 1),
            .min_dt = min_dt
        };
    }

    pub fn create(
        allocator: std.mem.Allocator, 
        file_path: []const u8, 
        header: [][]const u8, 
        pool_len: usize,
        min_dt: f64
    ) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, file_path, header, pool_len, min_dt);
        try ptr.init_pool();
        return ptr;
    }

    pub fn write_row(self: *Self, row: []f64, time: f64) !void{

        if (time - self.last_record_time < self.min_dt){
            return;
        }
        self.last_record_time = time;

        if (self.is_deleted){
            std.log.err("ERROR| Sim recorder has already compressed the data file and cannont write anymore", .{});
            return sim.errors.InvalidInput;
        }

        if ((self.pool_len - self.pool_idx) <= 0){

            const file = try std.fs.cwd().openFile(self.file_path, .{.mode = .read_write});    
            const stat = try file.stat();
            try file.seekTo(stat.size);
            defer file.close();

            if (row.len != self.header_len){
                std.log.err(
                    "Attempted to write row with length [{d}] when header has length [{d}]", .{row.len, self.header_len}
                );
                return sim.errors.MismatchedLength;
            }

            // Write the contets to the file  

            var buffer: []const u8 = empty_string[0..];

            for (0..self.contents.items.len) |i|{

                for (0..self.contents.items[0].items.len - 1) |j|{
                    buffer = try std.fmt.allocPrint(self.allocator, "{s}{d:.8},", .{buffer, self.contents.items[i].items[j]});
                }
                buffer = try std.fmt.allocPrint(self.allocator, "{s}{d:.8}\n",.{
                    buffer, self.contents.items[i].items[self.header_len - 1]
                });
            }

            // Write the final file and flush the pool
            for (0..row.len - 1) |i|{
                buffer = try std.fmt.allocPrint(self.allocator, "{s}{d:.8},", .{buffer, row[i]});
            }
            _ = try file.writer().writeAll(
                try std.fmt.allocPrint(self.allocator, "{s}{d:.8}\n", .{buffer,row[row.len - 1]}
            ));
            try self._flush_pool();
            self.pool_idx = 0;

            return;
        } 

        for (row, 0..) |_, i|{
            self.contents.items[self.pool_idx].items[i]  = row[i];
        }
        self.pool_idx +=1;
    }

    pub fn write_remaining(self: *Self, row: []f64) !void{
            const file = try std.fs.cwd().openFile(self.file_path, .{.mode = .read_write});    
            const stat = try file.stat();
            try file.seekTo(stat.size);
            defer file.close();

            // Write whatever was passed in as the final peice of data, force it to go through
            try self.write_row(row, self.last_record_time + self.min_dt*2);

            // Write the contents to the file  
            for (0..self.pool_idx) |i|{
                const content_len = self.contents.items[i].items.len;
                for (0..content_len - 1) |j|{
                    _ = try file.writer().writeAll(
                        try std.fmt.allocPrint(self.allocator, "{d:.8},", 
                        .{self.contents.items[i].items[j]}
                    ));
                }
                _ = try file.writer().writeAll(
                    try std.fmt.allocPrint(self.allocator, "{d:.8}\n", 
                    .{self.contents.items[i].items[self.header_len - 1]}
                ));
            }
    }

    pub fn init_pool(self: *Self) !void{
        self.contents.expandToCapacity();

        for (self.contents.items, 0..) |_, i|{
            self.contents.items[i] = try std.ArrayList(f64).initCapacity(self.allocator, self.header_len);
            self.contents.items[i].expandToCapacity();
        }

        try self._flush_pool();
    }

    pub fn _flush_pool(self: *Self) !void{
        for (self.contents.items, 0..) |_, i|{
            for (self.contents.items[i].items, 0..) |_, j|{
                try std.testing.expect(self.header_len == self.contents.items[i].items.len);
                self.contents.items[i].items[j] = -404;
            }
        }
    }

    pub fn print_pool(self: *Self) void{
        std.log.err("Pool Print:", .{}); 

        for (self.contents.items) |i|{
            for (i.items) |j|{
                std.log.err("{d:.8}", .{j});
            }
            std.log.err("", .{}); 
        }
    }

    pub fn compress(self: *Self) !void{
        var file = try std.fs.cwd().openFile(self.file_path, .{.mode = .read_only});
        const new_file = try std.fs.cwd().createFile(
            try std.fmt.allocPrint(self.allocator, "{s}.gz", .{self.file_path}
        ), .{});    
        defer new_file.close();

        try std.compress.gzip.compress(file.reader(), new_file.writer(), .{});

        file.close();
        try std.fs.cwd().deleteFile(self.file_path);
        self.is_deleted = true;
    }
};


// test "SimRecorder"{
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     const allocator = arena.allocator();
//     defer arena.deinit();

//     const file_path = "test.csv";
//     var header = [3][]const u8{"test1", "test2", "test3"};
//     var temp1 = [3]f64{0.0,1.0,2.0};
//     var a = try SimRecorder.create(allocator, file_path, header[0..], 50);

//     for (0..777) |i|{
//         temp1[0] = @floatFromInt(i);
//         temp1[1] *= (temp1[1] + 2.0) * temp1[0];
//         temp1[1] *= (temp1[1] + 10.0) * temp1[0];
//         try a.write_row(temp1[0..]);
//     }
// }