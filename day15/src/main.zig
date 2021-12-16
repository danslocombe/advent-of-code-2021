const std = @import("std");
const dan_lib = @import("dan_lib");
const ByteGrid = dan_lib.utils.ByteGrid;
const Allocator = std.mem.Allocator;
const UIntMap = dan_lib.utils.UIntMap;

const Path = struct {
    nodes : std.ArrayList(usize),
    cost : u64,
    dist_to_end : u64,

    pub fn last_node_index(self : Path) usize {
        return self.nodes.items[self.nodes.items.len - 1];
    }

    pub fn heuristic_cost(self : Path) u64 {
        return self.cost + self.dist_to_end;
        //return self.cost;
    }

    pub fn clone(self : Path) !Path {
        var nodes_copy = try std.ArrayList(usize).initCapacity(self.nodes.allocator, self.nodes.items.len + 1);
        try nodes_copy.appendSlice(self.nodes.items);
        return Path {
            .nodes = nodes_copy,
            .cost = self.cost,
            .dist_to_end = self.dist_to_end,
        };
    }

    pub fn clone_extend(self : Path, new_node_cost : u8, new_node_i : usize, new_dist : u64) !Path {
        var new = try self.clone();
        try new.nodes.append(new_node_i);
        new.cost += new_node_cost;
        new.dist_to_end = new_dist;
        return new;
    }
};

fn cmp_paths(x : Path, y : Path) std.math.Order {
    return std.math.order(x.cost, y.cost);
    //return std.math.order(x.heuristic_cost(), y.heuristic_cost());
    // UGH my A* isnt A*ing
    // Using cost + distance should be a heuristic function but something breaks.
    // only an optimisation so we can do without
}

const PathFinder = struct {
    //path_store : std.ArrayList(Path),
    grid : ByteGrid,
    seen : UIntMap(void),
    queue : std.PriorityQueue(Path, cmp_paths),

    pub fn init(allocator : Allocator, grid : ByteGrid) !PathFinder {
        std.log.err("Width {d} Height {d}", .{grid.width, grid.height});
        var queue = std.PriorityQueue(Path, cmp_paths).init(allocator);

        var initial_path_nodes = std.ArrayList(usize).init(allocator);
        try initial_path_nodes.append(0);
        try queue.add(Path {
            //.cost = grid.values[0],
            .cost = 0,
            .dist_to_end = manhatten_distance(.{.x = 0, .y = 0}, .{.x = @intCast(i32, grid.width-1), .y = @intCast(i32, grid.height-1)}),
            .nodes = initial_path_nodes,
        });

        return PathFinder {
            .grid = grid,
            .seen = UIntMap(void).init(allocator),
            .queue = queue,
        };
    }

    fn abs(x : anytype) @TypeOf(x) {
        return @maximum(x, -x);
    }

    fn manhatten_distance(p : ByteGrid.Pos, p2 : ByteGrid.Pos) u64 {
        return @intCast(u64, abs(p2.x - p.x)) + @intCast(u64, abs(p2.y - p.y));
    }

    fn manhatten_distance_to_end(self : PathFinder, p : ByteGrid.Pos) u64 {
        return manhatten_distance(p, ByteGrid.Pos {
            .x = @intCast(i32, self.grid.width-1),
            .y = @intCast(i32, self.grid.height-1),
        });
    }


    pub fn find(self : *PathFinder) !Path {
        var iters : usize = 0;
        while (self.*.queue.removeOrNull()) |popped| {

            if (popped.dist_to_end == 0) {
                std.log.err("DONE ITERS = {d}", .{iters});
                return popped;
            }

            iters += 1;

            const node_index = popped.last_node_index();
            const pos = self.grid.i_to_pos(node_index);
            const adjacent_poses = [4] ByteGrid.Pos {
                .{.x = 1, .y =  0},
                .{.x = -1, .y =  0},
                .{.x = 0, .y =  1},
                .{.x = 0,  .y = -1},
            };

            for (adjacent_poses) |adjacent| {
                const new_node_pos = pos.add(adjacent);
                if (self.grid.pos_to_i(new_node_pos)) |new_node_i| {
                    // In bounds
                    if (try self.seen.get_set(new_node_i, void{})) {
                        // Not been here before
                        const new_dist = manhatten_distance_to_end(self.*, new_node_pos);
                        const new_path = try popped.clone_extend(self.grid.values[new_node_i], new_node_i, new_dist);
                        try self.*.queue.add(new_path);
                    }
                }
            }
        }

        @panic("Ran out of paths");
    }
};

fn expand_grid(allocator : Allocator, grid : ByteGrid, factor : usize) !ByteGrid {
    var expanded = try ByteGrid.init(allocator, grid.width * factor, grid.height * factor);

    const width : i32 = @intCast(i32, grid.width);
    const height : i32 = @intCast(i32, grid.height);

    var i : usize = 0;
    for (dan_lib.utils.range(grid.height * factor)) |_, y| {
        for (dan_lib.utils.range(grid.width * factor)) |_, x| {
            var pos = ByteGrid.Pos.init(x, y);
            const original_grid_pos = ByteGrid.Pos.init(@mod(pos.x, width), @mod(pos.y, height));
            const original_grid_i = grid.pos_to_i(original_grid_pos);
            const original = @intCast(i32, grid.values[original_grid_i.?]);

            const incr = @intCast(i32, @divFloor(x, grid.width) + @divFloor(y, grid.height));
            const value = @mod((original + incr) - 1, 9) + 1;

            expanded.values[i] = @intCast(u8, value);

            i += 1;
        }
    }

    return expanded;
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var input_file = try std.fs.cwd().openFile("input.txt", .{});
    const grid = try ByteGrid.parse(@TypeOf(input_file), &input_file, arena.allocator());
    const big_grid = try expand_grid(arena.allocator(), grid, 5);
    //for (dan_lib.range(grid.height * 5)) |_, y| {
    //    std.log.err("{d}", .{big_grid.get_line(y)});
    //}
    var pathfinder = try PathFinder.init(arena.allocator(), big_grid);
    var path = try pathfinder.find();

    std.log.err("Path size {d}", .{path.nodes.items.len});
    std.log.err("{any}", .{path});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
