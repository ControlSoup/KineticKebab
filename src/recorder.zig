const std = @import("std");
const sim = @import("sim.zig");

pub const SimRecorder = struct{
    const Self = @This();

    allocator: std.mem.Allocator,
    file_path: []const u8,
    header_len: usize,
    pool_len: usize,
    pool_idx: usize = 0,
    contents: std.ArrayList(std.ArrayList(f64)),

    pub fn init(allocator: std.mem.Allocator, file_path: []const u8, header: [][]const u8, pool_len: usize) !Self{
        const file = try std.fs.cwd().createFile(file_path, .{});    
        defer file.close();
        
        // Write the header
        for (0..header.len - 1) |i|{
            _ = try file.writer().writeAll(
                try std.fmt.allocPrint(allocator, "{s},", .{header[i]})
            );
        }

        _ = try file.writer().writeAll(
            try std.fmt.allocPrint(allocator, "{s}\n", .{header[header.len - 1]})
        );

        return Self{
            .allocator = allocator,
            .file_path = file_path,
            .header_len = header.len,
            .pool_len = pool_len - 1,
            .contents = try std.ArrayList(std.ArrayList(f64)).initCapacity(allocator, pool_len - 1),
        };
    }

    pub fn create(allocator: std.mem.Allocator, file_path: []const u8, header: [][]const u8, pool_len: usize) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = try init(allocator, file_path, header, pool_len);
        try ptr.init_pool();
        return ptr;
    }

    pub fn write_row(self: *Self, row: []f64) !void{
        if ((self.pool_len - self.pool_idx) <= 0){
            const file = try std.fs.cwd().openFile(self.file_path, .{.mode = .read_write});    
            const stat = try file.stat();
            try file.seekTo(stat.size);
            defer file.close();

            // Write the contents to the file  
            for (0..self.contents.items.len) |i|{
                for (0..self.contents.items[0].items.len - 1) |j|{
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

            // Write the final file and flush the pool
            for (0..row.len - 1) |i|{
                _ = try file.writer().writeAll(
                    try std.fmt.allocPrint(self.allocator, "{d:.8},", 
                    .{row[i]}
                ));
            }
            _ = try file.writer().writeAll(
                try std.fmt.allocPrint(self.allocator, "{d:.8}\n", 
                .{row[row.len - 1]}
            ));
            try self.init_pool();
            self.pool_idx = 0;
            return;
        } 

        for (row, 0..) |_, i|{
            self.contents.items[self.pool_idx].items[i]  = row[i];
        }
        self.pool_idx +=1;
    }

    pub fn init_pool(self: *Self) !void{
        self.contents.expandToCapacity();

        for (self.contents.items, 0..) |_, i|{
            self.contents.items[i] = try std.ArrayList(f64).initCapacity(self.allocator, self.header_len);
            self.contents.items[i].expandToCapacity();
        }

        for (self.contents.items, 0..) |_, i|{
            for (self.contents.items[0].items, 0..) |_, j|{
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
};


// test "SimRecorder"{
//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     const allocator = arena.allocator();
//     defer arena.deinit();

//     const file_path = "test.csv";
//     var header = [3][]const u8{"test1", "test2", "test3"};
//     var temp1 = [3]f64{0.0,1.0,2.0};
//     var a = try SimRecorder.create(allocator, file_path, header[0..], 4);

//     for (0..4) |i|{
//         a.print_pool();
//         temp1[0] = @floatFromInt(i);
//         try a.write_row(temp1[0..]);
//     }
// }