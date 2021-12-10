const std = @import("std");
const dan_lib = @import("dan_lib");
const dan_parsers = dan_lib.parsers;
const Allocator = std.mem.Allocator;
const Pos = dan_lib.utils.Pair(i32);

pub fn parse(comptime Reader : type, reader : *Reader, allocator : Allocator) !std.ArrayList(?std.ArrayList(u8)) {
    const FBSType = std.io.FixedBufferStream([] const u8);

    var map = dan_parsers.Mapper(u8, u8, struct { pub fn map(x : u8) u8 {
        return x - '0';
    }}, FBSType).init(&dan_parsers.SingleChar(FBSType).init().parser);

    var parser = dan_parsers.LinesParser(std.ArrayList(u8), Reader).init(
        allocator,
        &dan_parsers.OneOrMany(u8, FBSType).init(allocator, &map.parser).parser);

    return (try parser.parser.parse(reader)).?;
}

const Heightmap = struct {
    values : []const u8,
    width : usize,
    height : usize,

    pub fn init(values : []const u8, width : usize, height : usize) Heightmap {
        return .{.values = values, .width = width, .height = height};
    }

    fn i_to_pos(self : Heightmap, i : usize) Pos {
        return .{.x = @intCast(i32, @mod(i, self.width)), .y = @intCast(i32, @divFloor(i, self.width))};
    }

    fn pos_to_i(self : Heightmap, pos : Pos) ?usize {
        if (pos.x < 0 or pos.y < 0 or pos.x == self.width or pos.y == self.height) {
            return null;
        }

        return @intCast(usize, pos.x + pos.y * @intCast(i32, self.width));
    }

    fn is_low_point(self : Heightmap, i : usize) bool {
        const cur_val = self.values[i];
        const cur_pos = self.i_to_pos(i);
        
        const neighbour_positions = [4] Pos{
            cur_pos.add(.{.x = -1, .y = 0}),
            cur_pos.add(.{.x = 1, .y = 0}),
            cur_pos.add(.{.x = 0, .y = -1}),
            cur_pos.add(.{.x = 0, .y = 1}),
        };

        for (neighbour_positions) |pos| {
            if (self.pos_to_i(pos)) |neighbour_i| {
                const val = self.values[neighbour_i];
                if (val <= cur_val) {
                    return false;
                }
            }
        }

        return true;
    }

    pub fn get_dangers(self : Heightmap) u32 {
        var sum : u32 = 0;
        for (self.values) |val, i| {
            if (self.is_low_point(i)) {
                std.log.info("{d} ({d}) is a low point", .{val, i});
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
            }

            for (previous.ranges.items) |*pr| {
                if (pr.*.area > 0) {
                    for (self.ranges.items) |*r| {
                        if (r.*.tag == pr.tag) {
                            r.*.area += pr.*.area;
                            pr.*.area = 0;
                            break;
                        }
                    }

                    if (pr.*.area > 0) {
                        try basins.update(pr.*.area);
                    }
                }
            }
        }
    };

    fn get_line(self : Heightmap, y : usize) []const u8 {
        return self.values[y*self.width..(y+1)*self.width];
    }

    fn scan(self : Heightmap, allocator : Allocator) !u32 {

        var basins = BasinTracker.init(allocator);

        var prev : ?RangeSet = null;
        var tagger = TagProvider{};
        for (dan_lib.range(self.height)) |_, y| {
            const line = self.get_line(y);
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
    const parsed = try parse(@TypeOf(input_file), &input_file, arena.allocator());

    // Assume first non empty
    const width = parsed.items[0].?.items.len;
    const height = parsed.items.len;

    var flattened = try std.ArrayList(u8).initCapacity(arena.allocator(), width * height);
    for (parsed.items) |line| {
        if (line) |l| {
            try flattened.appendSlice(l.items);
        }
    }

    const field = Heightmap.init(flattened.items, width, height);

    const summed_dangers = field.get_dangers();

    std.log.info("Summed dangers: {d}", .{summed_dangers});

    std.log.info("Product: {d}", .{try field.scan(arena.allocator())});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}