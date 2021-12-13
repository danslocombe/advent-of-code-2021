const std = @import("std");
const dan_lib = @import("dan_lib");
const fixedBufferStream = std.io.fixedBufferStream;
const FixedBufferStream = std.io.FixedBufferStream;
const Pair = dan_lib.utils.Pair(u32);
const Allocator = std.mem.Allocator;

const Axis = enum {
    x,
    y,
};

const Fold = struct {
    axis : Axis,
    line : u32,

    pub fn parse(s : []const u8) ?Fold {
        const fold_along_x = "fold along x=";
        const fold_along_y = "fold along y=";
        var axis : ?Axis = null;
        if (std.mem.startsWith(u8, s, fold_along_x)) {
            axis = Axis.x;
        }
        else if (std.mem.startsWith(u8, s, fold_along_y)) {
            axis = Axis.y;
        }
        else {
            return null;
        }

        var num = std.fmt.parseUnsigned(u32, s[fold_along_y.len..], 10) catch { return null; };

        return Fold{.axis = axis.?, .line = num};
    }
};

const  PointSet = struct {
    points : std.ArrayList(Pair),

    fn ffold(x : u32, line : u32) u32 {
        if (x <= line) {
            return x;
        }

        const dist = x - line;
        return line - dist;
    }

    pub fn apply_fold(self : *PointSet, allocator : Allocator, fold : Fold) !void {
        for (self.*.points.items) |*p| {
            switch (fold.axis) {
                Axis.x => {
                    p.*.x = ffold(p.*.x, fold.line);
                },
                Axis.y => {
                    p.*.y = ffold(p.*.y, fold.line);
                },
            }
        }

        // Ugh no way to easily do distinct
        // Ugly af
        var deduped = try std.ArrayList(Pair).initCapacity(allocator, self.*.points.items.len);
        outer: for (self.*.points.items) |p| {
            for (deduped.items) |dd| {
                if (p.equal(dd)) {
                    //std.log.info("Deduped {d}", .{p});
                    continue :outer;
                }
            }

            try deduped.append(p);
        }

        self.*.points.deinit();
        self.*.points = deduped;
    }

    pub fn contains(self : PointSet, px : Pair) bool {
        for (self.points.items) |p| {
            if (p.equal(px)) {
                return true;
            }
        }

        return false;
    }

    pub fn print(self : PointSet, allocator : Allocator) !void {
        var max_x : u32 = 0;
        var max_y : u32 = 0;
        for (self.points.items) |p| {
            max_x = @maximum(p.x, max_x);
            max_y = @maximum(p.y, max_y);
        }

        var line = std.ArrayList(u8).init(allocator);
        for (dan_lib.utils.range(max_y+1)) |_, y| {
            try line.resize(0);
            for (dan_lib.utils.range(max_x+1)) |_, x| {
                if (self.contains(Pair{.x=@intCast(u32, x), .y=@intCast(u32, y)})) {
                    try line.append('x');
                }
                else {
                    try line.append('.');
                }
            }

            std.log.info("{s}", .{line.items});
        }
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var parse_arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer parse_arena.deinit();
    const filename = "input.txt";

    var allocator = parse_arena.allocator();

    var lines = try dan_lib.Lines.from_file(allocator, std.fs.cwd(), filename);

    var pair_parser = dan_lib.parsers.PairParser(u32, FixedBufferStream([] const u8)).init(allocator);

    var pairs = std.ArrayList(Pair).init(allocator);
    var folds = std.ArrayList(Fold).init(allocator);

    var iter = lines.iter();
    while (iter.next()) |line| {
        var stream = fixedBufferStream(line);
        if (try pair_parser.parser.parse(&stream)) |parsed_pair| {
            try pairs.append(parsed_pair);
        }
        else if (Fold.parse(line)) |fold| {
            try folds.append(fold);
        }

    }

    var points = PointSet{.points = pairs};
    //std.log.info("Count {d}", .{points.points.items.len});
    //try points.apply_fold(allocator, folds.items[0]);
    //std.log.info("Count {d}", .{points.points.items.len});

    //try points.print(allocator);

    for (folds.items) |f| {
        try points.apply_fold(allocator, f);
        //try points.print(allocator);
    }

    try points.print(allocator);
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
