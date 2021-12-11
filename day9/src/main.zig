const std = @import("std");
const dan_lib = @import("dan_lib");
const dan_parsers = dan_lib.parsers;
const Allocator = std.mem.Allocator;

const Pos = dan_lib.utils.ByteGrid.Pos;
const ByteGrid = dan_lib.utils.ByteGrid;

const Heightmap = struct {
    grid : ByteGrid,

    pub fn init(grid : ByteGrid) Heightmap {
        return .{.grid = grid};
    }

    fn is_low_point(self : Heightmap, i : usize) bool {
        const cur_val = self.grid.values[i];
        const cur_pos = self.grid.i_to_pos(i);
        
        const neighbour_positions = [4] Pos{
            cur_pos.add(.{.x = -1, .y = 0}),
            cur_pos.add(.{.x = 1, .y = 0}),
            cur_pos.add(.{.x = 0, .y = -1}),
            cur_pos.add(.{.x = 0, .y = 1}),
        };

        for (neighbour_positions) |pos| {
            if (self.grid.pos_to_i(pos)) |neighbour_i| {
                const val = self.grid.values[neighbour_i];
                if (val <= cur_val) {
                    return false;
                }
            }
        }

        return true;
    }

    pub fn get_dangers(self : Heightmap) u32 {
        var sum : u32 = 0;
        for (self.grid.values) |val, i| {
            if (self.is_low_point(i)) {
                //std.log.info("{d} ({d}) is a low point", .{val, i});
                sum += @intCast(u32, 1 + val);
            }
        }

        return sum;
    }

    const Range = struct {
        start : usize,
        end : usize,
        area : u32,
        tag : usize,

        pub fn overlaps(self : Range, other : Range) bool {
            return self.start < other.end and self.end > other.start;
        }
    };

    const TagProvider = struct {
        next_tag : usize = 0,
        pub fn get(self : *TagProvider) usize {
            self.*.next_tag+=1;
            return self.*.next_tag;
        }
    };

    const BasinTracker = struct {
        basins : std.ArrayList(u32),

        pub fn init(allocator : Allocator) BasinTracker {
            return .{.basins = std.ArrayList(u32).init(allocator)};
        }

        pub fn update(self : *BasinTracker, x : u32) !void {
            try self.*.basins.append(x);
        }

        fn cmp(_: void, a: u32, b: u32) bool {
            return a >= b;
        }

        pub fn biggest_product(self : *BasinTracker) u32 {
            std.sort.sort(u32, self.*.basins.items, {}, cmp);

            return self.*.basins.items[0] *
                self.*.basins.items[1] *
                self.*.basins.items[2];
        }
    };

    const RangeSet = struct {
        ranges : std.ArrayList(Range),

        pub fn empty(allocator : Allocator) RangeSet {
            return .{.ranges = std.ArrayList(Range).init(allocator)};
        }

        pub fn init(allocator : Allocator, xs : []const u8, tagger: *TagProvider) !RangeSet {
            var cur_range : ?Range = null;
            var ranges = std.ArrayList(Range).init(allocator);
            for (xs) |x,i| {
                if (x == 9) {
                    if (cur_range) |*r| {
                        r.*.end = i;
                        try ranges.append(r.*);
                        cur_range = null;
                    }
                }
                else {
                    if (cur_range) |*r| {
                        r.*.area += 1;
                    }
                    else {
                        cur_range = Range{.start = i, .end = 0, .area = 1, .tag = tagger.get()};
                    }
                }
            }

            if (cur_range) |*r| {
                r.*.end = xs.len;
                try ranges.append(r.*);
            }

            return RangeSet{.ranges = ranges};
        }

        pub fn join(self : *RangeSet, previous : *RangeSet, basins : *BasinTracker) !void {
            for (previous.ranges.items) |*pr| {
                for (self.ranges.items) |*r| {
                    if (r.overlaps(pr.*)) {
                        r.area += pr.area;
                        pr.area = 0;
                        r.*.tag = @minimum(r.*.tag, pr.*.tag);
                    }
                }

                if (pr.*.area > 0) {
                    // There is still area untransferred
                    // First try and move sideways
                    for (self.ranges.items) |*r| {
                        if (r.*.tag == pr.tag) {
                            r.*.area += pr.*.area;
                            pr.*.area = 0;
                            break;
                        }
                    }

                    // Nowhere to move, complete basin
                    if (pr.*.area > 0) {
                        try basins.update(pr.*.area);
                    }
                }
            }
        }
    };


    fn scan(self : Heightmap, allocator : Allocator) !u32 {

        var basins = BasinTracker.init(allocator);

        var prev : ?RangeSet = null;
        var tagger = TagProvider{};
        for (dan_lib.range(self.grid.height)) |_, y| {
            const line = self.grid.get_line(y);
            var cur = try RangeSet.init(allocator, line, &tagger);

            if (prev) |*p| {
                try cur.join(p, &basins);
            }

            prev = cur;
        }

        try RangeSet.empty(allocator).join(&(prev.?), &basins);

        return basins.biggest_product();
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var input_file = try std.fs.cwd().openFile("input.txt", .{});
    const field = Heightmap.init(try ByteGrid.parse(@TypeOf(input_file), &input_file, arena.allocator()));

    const summed_dangers = field.get_dangers();

    std.log.info("Summed dangers: {d}", .{summed_dangers});

    std.log.info("Product: {d}", .{try field.scan(arena.allocator())});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}