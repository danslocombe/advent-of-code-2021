const std = @import("std");
const dan_lib = @import("dan_lib");
const Allocator = std.mem.Allocator;

const RewriteRuleState = struct {
    //from : [2]u8,
    from : [] const u8,
    to : u8,
    count : u64,
};

const Mapping = struct {
    one : usize,
    two : usize,
};

const PolymerState = struct {
    states : []RewriteRuleState,
    mappings : []Mapping,

    pub fn init(allocator : Allocator, parsed : std.StringHashMap(u8), start_string : []const u8) !PolymerState {
        const size = @intCast(usize, parsed.count());
        var states = try allocator.alloc(RewriteRuleState, size);
        var mappings = try allocator.alloc(Mapping, size);

        {
            var iter = parsed.iterator();

            var i : usize = 0;
            while (iter.next()) |kv| {
                const state = .{
                    //.from = .{kv.key_ptr.*[0], kv.key_ptr.*[1]},
                    .from = kv.key_ptr.*,
                    .to = kv.value_ptr.*,
                    .count = 0,
                };

                states[i] = state;
                i += 1;
            }
        }

        for (states) |state, j| {
            var target_one_s = [2]u8 {state.from[0], state.to};
            var target_two_s = [2]u8 {state.to, state.from[1]};

            var mapping = Mapping{.one = 0, .two = 0};

            for (states) |s_target, i| {
                if (std.mem.eql(u8, s_target.from[0..], target_one_s[0..])) {
                    mapping.one = i;
                }
                else if (std.mem.eql(u8, s_target.from[0..], target_two_s[0..])) {
                    mapping.two = i;
                }
            }

            mappings[j] = mapping;
        }

        for (dan_lib.range(start_string.len - 1)) |_, i| {
            var pair = start_string[i..i+2];
            for (states) |*state| {
                if (std.mem.eql(u8, state.*.from[0..], pair)) {
                    state.*.count += 1;
                    std.log.info("Increasing count on {s}", .{state.*.from[0..]});
                }
            }
        }

        return PolymerState{
            .states = states,
            .mappings = mappings,
        };
    }

    pub fn tick(self : *PolymerState, allocator : Allocator) !void {
        var new_counts = try allocator.alloc(u64, self.states.len);
        for (new_counts) |*c| {
            c.* = 0;
        }

        for (self.states) |*s, i| {
            const cur_count = s.*.count;
            const index_one = self.mappings[i].one;
            const index_two = self.mappings[i].two;

            new_counts[index_one] += cur_count;
            new_counts[index_two] += cur_count;
        }

        for (self.states) |*s, i| {
            s.*.count = new_counts[i];
        }

        allocator.free(new_counts);
    }

    pub fn count(self : PolymerState) u64 {
        var c : u64 = 0;
        for (self.states) |s| {
            //std.log.info("Found count {d}", .{s.count});
            c += s.count;
        }
        return c+1;
    }

    pub fn score(self : PolymerState, allocator : Allocator) !u64 {
        var counter = dan_lib.utils.BucketCounter(u8).init(allocator);
        for (self.states) |s| {
            try counter.add(s.from[0], s.count);
            try counter.add(s.from[1], s.count);
        }

        var buckets = try counter.get_buckets();

        const ret = buckets.items[buckets.items.len-1].sum - buckets.items[0].sum;
        // We've counted everything twice
        return ret / 2;
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var parse_arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer parse_arena.deinit();
    const filename = "input_test.txt";

    var allocator = parse_arena.allocator();

    var lines = try dan_lib.Lines.from_file(allocator, std.fs.cwd(), filename);
    var iter = lines.iter();

    var start_string = iter.next().?;
    var rewrite_rules = std.StringHashMap(u8).init(allocator);
    while (iter.next()) |l| {
        var splits = std.mem.tokenize(u8, l, " ->");
        var from = splits.next().?;
        var to = splits.next().?;
        std.log.err("Putting rule '{s}' {s}", .{from, to});
        try rewrite_rules.put(from, to[0]);
    }

    var poly_state = try PolymerState.init(allocator, rewrite_rules, start_string);
    std.log.err("{d}", .{poly_state.count()});

    for (dan_lib.range(40)) |_, i| {
      try poly_state.tick(allocator);
      std.log.err("{d} {d} Score {d}", .{i, poly_state.count(), try poly_state.score(allocator)});
    }
}