const std = @import("std");
const lib = @import("dan_lib");

const Remapping = struct {
    state : [10]u8,

    pub fn set(self : *Remapping, segment: u8, order: u8) void {
        self.state[segment] = order;
    }
};

const WireStates = struct {
    states : u8,

    const one : u8 = 1;

    pub fn init(cs : []const u8) WireStates {
        var states : u8 = 0;
        for (cs) |c| {
            const x = @intCast(u3, c - 'a');
            states |= one << x;
        }

        std.log.info("Parsing {s} got {d}", .{cs, states});

        return .{.states = states};
    }

    pub fn get_state(self : WireStates, x:usize) bool {
        const mask : u8 = one << @intCast(u3, x);
        return (self.states & mask) != 0;
    }

    pub fn get_on_count(self : WireStates) usize {
        return @popCount(u8, self.states);

    }

    pub fn unique_value(self: WireStates) bool {
        const on_count = self.get_on_count();
        //return on_count == 1 or on_count == 4 or on_count == 7 or on_count == 8;
        return on_count == 2 or on_count == 4 or on_count == 3 or on_count == 7;
    }

    pub fn get_diff_single(self : WireStates, other : WireStates) u8 {
        for (lib.range(7)) |_, i| {
            if (self.get_state(i) != other.get_state(i)) {
                return @intCast(u8, i);
            }
        }

        @panic("Unreachable");
    }

    pub fn union_vals(self : WireStates, other : WireStates) WireStates {
        return WireStates {self.states | other.states};
    }
};

const SegmentValues = struct {
    digit_values : [10] WireStates,
    output_values : [4] WireStates,

    pub fn infer_remapping(self : SegmentValues) Remapping {
        const inferred_digits : [10]WireStates = undefined;

        var remapping = Remapping {.state = 0};


        for (self.digit_values) |value| {
            const on_count = value.get_on_count();
            if (on_count == 2) {
                inferred_digits[1] = value;
            }
            else if (on_count == 4) {
                inferred_digits[4] = value;
            }
            else if (on_count == 3) {
                inferred_digits[7] = value;
            }
            else if (on_count == 7) {
                inferred_digits[8] = value;
            }
        }

        // Set 'a'
        remapping.set(0, inferred_digits[1].get_diff_single(inferred_digits[7]));

    }

    pub fn parse(s : []const u8) SegmentValues {
        var digit_values : [10]WireStates = undefined;
        var output_values : [4]WireStates = undefined;
        
        var splits = std.mem.split(u8, s, "|");
        const all_values_strings = splits.next();
        const output_values_strings = splits.next();

        var digit_i : usize = 0;
        var whitespace_splits = std.mem.split(u8, all_values_strings.?, " ");
        while (whitespace_splits.next()) |x| {
            if (x.len > 0) {
                digit_values[digit_i] = WireStates.init(x);
                digit_i += 1;
            }
        }

        var output_i : usize = 0;
        whitespace_splits = std.mem.split(u8, output_values_strings.?, " ");
        while (whitespace_splits.next()) |x| {
            if (x.len > 0) {
                output_values[output_i] = WireStates.init(x);
                output_i += 1;
            }
        }

        return .{
            .digit_values = digit_values,
            .output_values = output_values,
        };
    }
};

const SubDisplayState = struct {
    segments : []const SegmentValues,

    pub fn init(segments : []const SegmentValues) SubDisplayState {
        return .{.segments = segments};
    }

    pub fn get_unique_value_count(self : SubDisplayState) usize {
        var sum : usize = 0;
        for (self.segments) |seg| {
            for (seg.output_values) |output| {
                std.log.info("On count: {d}", .{output.get_on_count()});
                if (output.unique_value()) {
                    sum += 1;
                }
            }
            std.log.info("Unique states {d}", .{sum});
        }

        return sum;
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();


    var allocator = arena.allocator();

    var lines = try lib.Lines.from_file(allocator, std.fs.cwd(), "day8_input.txt");
    var segment_values = try std.ArrayList(SegmentValues).initCapacity(allocator, lines.len());

    var lines_iter = lib.Lines.Iterator.init(lines);
    while (lines_iter.next()) |line| {
        try segment_values.append(SegmentValues.parse(line));
    }

    var sub_state = SubDisplayState.init(segment_values.items);

    std.log.info("Unique states {d}", .{sub_state.get_unique_value_count()});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
