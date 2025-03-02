const std = @import("std");

pub fn to_1d(i: usize, j: usize, width: usize) usize{
    return width * i + j;
}

// Arraylist wrapper for 2d, only used for jacobian currenltly not general purpose
pub const ArrayMatrixf64 = struct{
    const Self = @This();
    array_list: std.ArrayList(f64),
    width: usize,


    pub fn init(allocator: std.mem.Allocator) Self{
        return Self{
            .array_list = std.ArrayList(f64).init(allocator),
            .width = 0,
        };
    }

    pub fn create(allocator: std.mem.Allocator) !*Self{
        const ptr = try allocator.create(Self);
        ptr.* = init(allocator);
        return ptr;
    }

    pub fn from_slice(allocator: std.mem.Allocator, slice: []f64, width: usize) !*Self{

        const matrix = try ArrayMatrixf64.create(allocator);
        if (width == 0){
            try matrix.resize_clear(width, 0, 0.0);
        } else{
            try matrix.resize_clear(width, slice.len / width, 0.0);
        }

        for (slice, 0..) |val, i|{
            matrix.array_list.items[i] = val;
        }
        return matrix;
    }

    pub fn deinit(self: *Self) void{
        self.array_list.deinit();
    }

    pub fn get_array_index(self: *Self, i: usize, j: usize) usize{
        return to_1d(i, j, self.width);
    }

    pub fn get(self: *Self, i: usize, j: usize) f64{
        return self.array_list.items[self.get_array_index(i, j)];
    }

    pub fn compute_height(self: *Self) usize{
        if (self.array_list.items.len == 0) return 0;
        return self.array_list.items.len / self.width;
    }

    pub fn set(self: *Self, i: usize, j: usize, val: f64) void{
        self.array_list.items[self.get_array_index(i, j)] = val;
    } 

    pub fn append_row_of(self: *Self, val: f64) !void{
        try self.array_list.appendNTimes(val, self.width);
    }

    pub fn resize_clear(self: *Self, width: usize, height: usize, val: f64) !void{
        self.array_list.clearAndFree();
        try self.array_list.appendNTimes(val, width * height);
        self.width = width;
    }

    pub fn num_mul(self: *Self, mult: f64) void{
        for (0..self.array_list.items.len) |i| {
            self.array_list.items[i] = self.array_list.items[i]  * mult;
        }
    }

    pub fn num_add(self: *Self, add: f64) void{
        for (0..self.array_list.items.len) |i| {
            self.array_list.items[i] = self.array_list.items[i]  + add;
        }
    }

    pub fn determinate(self: *Self) !f64{

        const height = self.compute_height();
        const width = self.width;

        if (width != height){
            std.log.err("Determinate can not be computed for non square matricies", .{});
            try self.__print("");
            return error.InvalidInput;
        }

        // Base case of 2x2 matrix
        if (width == 2){
            return self.array_list.items[0]*self.array_list.items[3] - (self.array_list.items[1]*self.array_list.items[2]); 
        }


        var determinte_sum: f64 = 0.0;
        var local_matrix = ArrayMatrixf64.init(self.array_list.allocator);
        defer local_matrix.deinit();

        for (0..height) |j|{

            // Sub matrix 
            try local_matrix.resize_clear(width - 1, height - 1, 0.0);
            
            var local_i: usize = 0;
            var local_j: usize = 0;
            for (1..width) |sub_i|{
                // Skip current colums and first row
                for (0..height) |sub_j|{
                    if (!(sub_j == j)){
                        local_matrix.set(local_i, local_j, self.get(sub_i, sub_j));
                        local_j +=1;
                    }
                }
                local_i += 1;
                local_j = 0;
            }

            // Alternate sign, recursivly call the deterimate
            const local_determinate =  try local_matrix.determinate();
            if (j % 2 == 0){
                determinte_sum += self.get(0, j) * local_determinate;
            } else{
                determinte_sum -= self.get(0, j) * local_determinate;
            }

        }

        return determinte_sum;
    }

    pub fn swap_rows(self: *Self, j1: usize, j2: usize) void{
        var temp: f64 = 0.0;
        for (0..self.width) |i|{
            temp = self.get(j2, i);
            self.set(j2, i, self.get(j1, i));
            self.set(j1, i, temp);
        }
    }

    pub fn __print(self: *Self, name: []const u8) !void{
        var string: []u8 = try std.fmt.allocPrint(self.array_list.allocator, "\n__ Maxtrix {s} __\n", .{name}); 
        for (0..self.compute_height()) |i|{

            string = try std.fmt.allocPrint(self.array_list.allocator, "{s}{any}", .{string, self.get(i, 0)});

            for (1..self.width) |j|{
                string = try std.fmt.allocPrint(self.array_list.allocator, "{s}, {any}", .{string, self.get(i, j)});
            }

            string = try std.fmt.allocPrint(self.array_list.allocator, "{s}\n", .{string});
        }

        std.log.err("{s}\n", .{string});
    }
};

pub fn transpose(array_matrix: *ArrayMatrixf64) !*ArrayMatrixf64{
    var matrix_copy = try ArrayMatrixf64.create(array_matrix.array_list.allocator);
    try matrix_copy.resize_clear(array_matrix.width, array_matrix.compute_height(), 0.0);
    for (0..array_matrix.width) |i|{
        for (0..array_matrix.compute_height()) |j|{
            matrix_copy.set(j,i, array_matrix.get(i, j));
        }
    }
    return matrix_copy;
}

// Neds adjoint
// pub matrix_inverse(array_matrix: *ArrayMatrixf64) !*ArrayMatrixf64{
//     const det = try array_matrix.determinate();
//     std.log.err("{d}", .{det});
//     try t.num_mul(1.0 / det);
//     return t;
// }

pub fn mat_mul(array_matrix_1: *ArrayMatrixf64, array_matrix_2: *ArrayMatrixf64) !*ArrayMatrixf64{

    if (array_matrix_1.compute_height() != array_matrix_2.width){
        std.log.err(
            "Unable to perform matrix multiplication with size [{d},{d}] vs [{d},{d}]", 
            .{array_matrix_1.width, array_matrix_1.compute_height(), array_matrix_2.width, array_matrix_2.compute_height()}
        );
    }

    var matrix_copy = try ArrayMatrixf64.create(array_matrix_1.array_list.allocator);
    const width = array_matrix_1.width;
    const height = array_matrix_2.compute_height();
    try matrix_copy.resize_clear(width, height, 0.0);
    
    for (0..width) |i|{
        for (0..height) |j|{
            for (0..array_matrix_1.compute_height()) |k|{
                matrix_copy.set(i, j, matrix_copy.get(i,j) + array_matrix_1.get(i,k) * array_matrix_1.get(k,j));
            }
        }
    }
    return matrix_copy;
}

// Extremely basic implementation of gaussian elimination, its not amazingly accurate tbh ~1e-3 or 1e-4 in edge cases
pub fn gaussian(array_matrix: *ArrayMatrixf64, results: *std.ArrayList(f64), solve: *std.ArrayList(f64)) !void{

    if (results.items.len != array_matrix.compute_height()){
        std.log.err("Can't perform gaussian with array_matrix.height != results.len got: {d} vs {d}", .{array_matrix.compute_height(), results.items.len});
        return error.InvalidInput;
    }

    if (results.items.len != solve.items.len){
        std.log.err("Can't perform gaussian with solve.len != results.len got: {d} vs {d}", .{solve.items.len, results.items.len});
        return error.InvalidInput;
    }

    // Create the augmented

    var augment = try ArrayMatrixf64.create(array_matrix.array_list.allocator);
    defer augment.deinit();
    try augment.resize_clear(array_matrix.width + 1, array_matrix.compute_height(), 0.0);

    for (0..array_matrix.compute_height()) |i|{
        for (0..array_matrix.width) |j|{
            augment.set(i,j,array_matrix.get(i,j));
        }
    }

    const height = augment.compute_height();
    const width = augment.width;

    for (results.items, 0..) |result, i|{
        augment.set(i, width - 1, result);
    }

    var pivot: f64 = 0.0;
    var target: f64 = 0.0;
    var correction: f64 = 0.0;

    for (0..width - 1) |j| {
        pivot = augment.get(j, j);

        if (pivot == 0.0){
            for (j..width) |c|{
                if(augment.get(c,j) != 0.0){
                    pivot = augment.get(c,j);
                    augment.swap_rows(c, j);
                    break;
                }

                if (c == width - 1) return error.SingularMatrix;
            }
        }

        // Elimnation bellow pivot
        for (j..height) |i|{

            // Skip pivot
            if (j == i) continue;    

            target = augment.get(i,j);

            // Skip divide by 0.0
            if (target == 0.0) continue;

            correction = target / pivot;

            for (0..width) |k|{
                augment.set(i, k, augment.get(i,k) - (correction * augment.get(j,k)));
            }

        }

    }

    // Backwards difference
    var i: usize = solve.items.len;
    while (i > 0) {
        i -= 1;
        var sum: f64 = 0.0;
        for (i + 1..solve.items.len) |j| {
            sum += augment.get(i, j) * solve.items[j];
        }
        solve.items[i] = (augment.get(i, solve.items.len) - sum) / augment.get(i, i);
    }
}


test "ArrayMatrix" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    defer arena.deinit();
    var arr =  [_]f64{
        1.0, 3.0, 5.0,
        8.0, 5.0, 6.0,
        2.0, 3.0, 6.0   
    };
    var matrix = try ArrayMatrixf64.from_slice(allocator, arr[0..], 3);

    try std.testing.expectApproxEqRel(-26.0, try matrix.determinate(), 1e-7);

    const t = try transpose(matrix);

    try std.testing.expectApproxEqRel(1.0, t.array_list.items[0], 1e-6);
    try std.testing.expectApproxEqRel(8.0, t.array_list.items[1], 1e-6);
    try std.testing.expectApproxEqRel(2.0, t.array_list.items[2], 1e-6);
    try std.testing.expectApproxEqRel(3.0, t.array_list.items[3], 1e-6);
    try std.testing.expectApproxEqRel(5.0, t.array_list.items[4], 1e-6);
    try std.testing.expectApproxEqRel(3.0, t.array_list.items[5], 1e-6);
    try std.testing.expectApproxEqRel(5.0, t.array_list.items[6], 1e-6);
    try std.testing.expectApproxEqRel(6.0, t.array_list.items[7], 1e-6);
    try std.testing.expectApproxEqRel(6.0, t.array_list.items[8], 1e-6);


    var arr2 =  [_]f64{
        1.0, 2.0, 3.0,
        4.0, 5.0, 6.0,
        7.0, 8.0, 9.0,
    };
    const mat1 = try ArrayMatrixf64.from_slice(allocator, arr2[0..], 3);
    const mat2 = try ArrayMatrixf64.from_slice(allocator, arr2[0..], 3);
    const mult = try mat_mul(mat1, mat2);

    try std.testing.expectApproxEqRel(30.0, mult.array_list.items[0], 1e-6);
    try std.testing.expectApproxEqRel(36.0, mult.array_list.items[1], 1e-6);
    try std.testing.expectApproxEqRel(42.0, mult.array_list.items[2], 1e-6);
    try std.testing.expectApproxEqRel(66.0, mult.array_list.items[3], 1e-6);
    try std.testing.expectApproxEqRel(81.0, mult.array_list.items[4], 1e-6);
    try std.testing.expectApproxEqRel(96.0, mult.array_list.items[5], 1e-6);
    try std.testing.expectApproxEqRel(102.0, mult.array_list.items[6], 1e-6);
    try std.testing.expectApproxEqRel(126.0, mult.array_list.items[7], 1e-6);
    try std.testing.expectApproxEqRel(150.0, mult.array_list.items[8], 1e-6);

    // var arr3 =  [_]f64{
    //     2.0, 5.0, 8.0,
    //     3.0, 7.0, 7.0,
    //     4.0, 5.0, 5.0 
    // };
    // const mat3 = try ArrayMatrixf64.from_slice(allocator, arr3[0..], 3);
    // const inv = try inverse(mat3);

    // try std.testing.expectApproxEqRel(0.0, inv.array_list.items[0], 1e-6);
    // try std.testing.expectApproxEqRel(-5.0 / 13.0, inv.array_list.items[1], 1e-6);
    // try std.testing.expectApproxEqRel(7.0 / 13.0, inv.array_list.items[2], 1e-6);
    // try std.testing.expectApproxEqRel(-1.0 / 3.0, inv.array_list.items[3], 1e-6);
    // try std.testing.expectApproxEqRel(22.0 / 39.0, inv.array_list.items[4], 1e-6);
    // try std.testing.expectApproxEqRel(-10.0 / 39.0, inv.array_list.items[5], 1e-6);
    // try std.testing.expectApproxEqRel(1.0 / 3.0, inv.array_list.items[6], 1e-6);
    // try std.testing.expectApproxEqRel(-10.0 / 39.0, inv.array_list.items[7], 1e-6);
    // try std.testing.expectApproxEqRel(1.0 / 39.0, inv.array_list.items[8], 1e-6);

    var arr5 =  [_]f64{
        1.0, -1.0, 1.0,
        2.0, 3.0, -1.0,
        3.0, -2.0, -9.0 
    };
    var results = std.ArrayList(f64).init(allocator);
    try results.append(8.0);
    try results.append(-2.0);
    try results.append(9.0);

    const mat5 = try ArrayMatrixf64.from_slice(allocator, arr5[0..], 3);

    var gause_2 = std.ArrayList(f64).init(allocator);
    try gause_2.appendNTimes(std.math.nan(f64), results.items.len);

    try gaussian(mat5, &results, &gause_2);

    try std.testing.expectApproxEqRel(4.0, gause_2.items[0], 1e-7);
    try std.testing.expectApproxEqRel(-3.0, gause_2.items[1], 1e-7);
    try std.testing.expectApproxEqRel(1.0, gause_2.items[2], 1e-7);

    var arr6 =  [_]f64{
        0.0, 2.0, 3.0, 2.0,
        1.0, 5.0, 3.0, 2.0,
        5.0, 2.0, 11.0, 2.0,
        2.0, 4.0, 0.0, 1.0,
    };

    var results6 = std.ArrayList(f64).init(allocator);
    try results6.append(1.0);
    try results6.append(2.0);
    try results6.append(33.0);
    try results6.append(2.0);

    const mat6 = try ArrayMatrixf64.from_slice(allocator, arr6[0..], 4);

    var gause_6 = std.ArrayList(f64).init(allocator);
    try gause_6.appendNTimes(std.math.nan(f64), results6.items.len);

    try gaussian(mat6, &results6, &gause_6);

    try std.testing.expectApproxEqRel(104.0 / 31.0, gause_6.items[0], 1e-7);
    try std.testing.expectApproxEqRel(-73.0 / 93.0, gause_6.items[1], 1e-7);
    try std.testing.expectApproxEqRel(59.0 / 31.0, gause_6.items[2], 1e-7);
    try std.testing.expectApproxEqRel(-146.0 / 93.0, gause_6.items[3], 1e-7);
}
