const std = @import("std");
const dan_lib = @import("dan_lib");
const Allocator = std.mem.Allocator;

const CaveType = enum {
    start,
    end,
    big,
    small
};

fn all_lower(xs : [] const u8) bool {
    for (xs) |x| {
        if (x < 'a') {
            return false;
        }
    }

    return true;
}

const Cave = struct {
    cave_type : CaveType,
    name : []const u8,

    pub fn parse(s : []const u8) Cave {
        var t : ?CaveType = null;
        if (std.mem.eql(u8, s, "start")) {
            t = CaveType.start;
        }
        else if (std.mem.eql(u8, s, "end")) {
            t = CaveType.end;
        }
        else {
            if (all_lower(s)) {
                t = CaveType.small;
            }
            else {
                t = CaveType.big;
            }
        }

        const xx = .{.cave_type = t.?, .name = s};
        std.log.info("Parsed {any} {s}", .{xx, s});
        return xx;
    }
};

const Edge = struct {
    from : usize,
    to : usize,
};

const Path = struct {
    //prev : ?* const Path,
    value : usize,
    double_visit : bool,
    small_cave_seen_bits : u32,

    //fn contains(self : Path, cave_rank : usize) bool {
    //    return contains_inner(&self, cave_rank);
    //}

    //fn contains_inner(self : ?*const Path, cave_rank : usize) bool {
    //    var cur : ?*const Path = self;
    //    while (cur) |node| {
    //        if (node.*.value == cave_rank) {
    //            return true;
    //        }

    //        cur = node.*.prev;
    //    }

    //    return false;
    //}

    fn to_mask(cave_rank : usize) u32 {
        const one : u32 = 1;
        return one << @intCast(u5, cave_rank);
    }

    fn contains(self : Path, cave_rank : usize) bool {
        return (self.small_cave_seen_bits & (to_mask(cave_rank))) != 0;
    }

    pub fn try_append(self : *const Path, allocator : Allocator, system : CaveSystem, cave_rank : usize) !?*Path {
        const cave = system.caves[cave_rank];

        var double_visit = self.double_visit;
        var small_cave_seen_bits = self.small_cave_seen_bits;

        switch (cave.cave_type) {
            // Cant go back to the start
            CaveType.start => return null,
            CaveType.small => {
                // Check if we've already visited
                if (self.contains(cave_rank)) {
                    if (!double_visit) {
                        double_visit = true;
                    }
                    else {
                        return null;
                    }
                }

                small_cave_seen_bits |= to_mask(cave_rank);
            },
            else => {},
        }

        var new = &(try allocator.alloc(Path, 1))[0];
        //new.*.prev = self;
        new.*.double_visit = double_visit;
        new.*.value = cave_rank;
        new.*.small_cave_seen_bits = small_cave_seen_bits;
        return new;
    }
};

const CaveSystem = struct {
    start : usize,
    end : usize,
    caves : []const Cave,
    edges : []const Edge,

    //pub fn find_paths(self : CaveSystem, allocator : Allocator) !std.ArrayList(*const Path) {
    pub fn find_paths(self : CaveSystem, allocator : Allocator) !u32 {
        //var completed_paths = try std.ArrayList(*const Path).initCapacity(allocator, 512);
        var completed_count : u32 = 0;
        var path_stack = try std.ArrayList(*const Path).initCapacity(allocator, 512);

        //var init_path = Path {.prev = null, .double_visit = false, .value = self.start, .small_cave_seen_bits = 0};
        var init_path = Path {.double_visit = false, .value = self.start, .small_cave_seen_bits = 0};
        try path_stack.append(&init_path);

        while (path_stack.items.len > 0) {
            const top = path_stack.pop();

            const last_cave = top.*.value;

            // Is at end?
            if (last_cave == self.end) {
                //try completed_paths.append(top);
                completed_count+=1;
                continue;
            }

            for (self.edges) |edge| {
                if (edge.from == last_cave) {
                    if (try top.try_append(allocator, self, edge.to)) |new| {
                        try path_stack.append(new);
                    }
                }
                else if (edge.to == last_cave) {
                    if (try top.try_append(allocator, self, edge.from)) |new| {
                        try path_stack.append(new);
                    }
                }
            }
        }

        //return completed_paths;
        return completed_count;
    }

    pub fn parse(allocator : Allocator, filename : []const u8) !CaveSystem {
        var cave_name_to_rank = std.StringHashMap(usize).init(allocator);
        var caves = std.ArrayList(Cave).init(allocator);
        var edges = std.ArrayList(Edge).init(allocator);

        var lines = try dan_lib.Lines.from_file(allocator, std.fs.cwd(), filename);
        var iter = lines.iter();
        while (iter.next()) |line| {
            var splits = std.mem.split(u8, line, "-");
            const first = splits.next();
            var first_rank : usize = 0;
            if (cave_name_to_rank.get(first.?)) |rank| {
                first_rank = rank;
            }
            else {
                first_rank = caves.items.len;
                try cave_name_to_rank.put(first.?, first_rank);
                try caves.append(Cave.parse(first.?));
            }

            const second = splits.next();
            var second_rank : usize = 0;
            if (cave_name_to_rank.get(second.?)) |rank| {
                second_rank = rank;
            }
            else {
                second_rank = caves.items.len;
                try cave_name_to_rank.put(second.?, second_rank);
                try caves.append(Cave.parse(second.?));
            }

            const edge = .{.from = first_rank, .to = second_rank};
            std.log.info("{any}", .{edge});
            try edges.append(edge);
        }

        const start_rank = cave_name_to_rank.get("start").?;
        const end_rank = cave_name_to_rank.get("end").?;
        return CaveSystem{.caves = caves.items, .edges = edges.items, .start = start_rank, .end = end_rank};
    }
};

pub fn do_puzzle() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const cave = try CaveSystem.parse(arena.allocator(), "input.txt");
    const paths = try cave.find_paths(arena.allocator());
    //for (paths.items) |path| {
        //std.log.info("Found path {any}", .{path.cave_ranks.items});
    //}
    //std.log.err("Found {d} paths", .{paths.items.len});
    std.log.err("Found {d} paths", .{paths});
}

const RunArgs = struct {
    caves : CaveSystem
};

pub fn run(allocator : Allocator, args : RunArgs) callconv(.Inline) anyerror!usize {
    const paths = try args.caves.find_paths(allocator);
    return paths;
    //return paths.items.len;
}

pub fn benchmark() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var parse_arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer parse_arena.deinit();

    const caves = try CaveSystem.parse(parse_arena.allocator(), "input.txt");

    var count : u32 = 0;
    for (caves.caves) |_| {
        //if (c.cave_type == CaveType.small) {
            count += 1;
        //}
    }

    std.log.err("Small cave count {d}", .{count});

    var benchmarks = try dan_lib.benchmarking.Benchmarks(RunArgs, anyerror!usize).generate(gpa.allocator(), .{
        .f = run,
        .f_args = .{.caves = caves},
        .iters = 100,
    });

    benchmarks.print();
}

pub fn main() anyerror!void {
    //try do_puzzle();
    try benchmark();
}