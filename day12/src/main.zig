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
    cave_ranks : std.ArrayList(usize),
    double_visit : ?usize,

    pub fn try_append(self : Path, allocator : Allocator, system : CaveSystem, cave_rank : usize) !?Path {
        const cave = system.caves[cave_rank];

        var double_visit : ?usize = self.double_visit;

        switch (cave.cave_type) {
            // Cant go back to the start
            CaveType.start => return null,
            CaveType.small => {
                // Check if we've already visited
                for (self.cave_ranks.items) |prev_cave_rank| {
                    if (prev_cave_rank == cave_rank) {
                        if (double_visit == null) {
                            double_visit = cave_rank;
                            break;
                        }
                        else {
                            return null;
                        }
                    }
                }
            },
            else => {},
        }

        // Clone and append
        var new = try dan_lib.utils.copy_list(usize, allocator, self.cave_ranks);
        try new.append(cave_rank);
        return Path {.cave_ranks = new, .double_visit = double_visit};
    }
};

const CaveSystem = struct {
    start : usize,
    end : usize,
    caves : []const Cave,
    edges : []const Edge,

    pub fn find_paths(self : CaveSystem, allocator : Allocator) !std.ArrayList(Path) {
        var completed_paths = std.ArrayList(Path).init(allocator);
        var path_stack = std.ArrayList(Path).init(allocator);

        var init_path = Path {.cave_ranks = std.ArrayList(usize).init(allocator), .double_visit = null};
        try init_path.cave_ranks.append(self.start);
        try path_stack.append(init_path);

        while (path_stack.items.len > 0) {
            const top = path_stack.pop();

            const last_cave = top.cave_ranks.items[top.cave_ranks.items.len - 1];

            // Is at end?
            if (last_cave == self.end) {
                try completed_paths.append(top);
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

            top.cave_ranks.deinit();
        }

        return completed_paths;
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

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const cave = try CaveSystem.parse(arena.allocator(), "input.txt");
    const paths = try cave.find_paths(arena.allocator());
    for (paths.items) |path| {
        std.log.info("Found path {any}", .{path.cave_ranks.items});
    }
    std.log.err("Found {d} paths", .{paths.items.len});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
