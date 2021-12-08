const std = @import("std");
const lib = @import("dan_lib");

const WireStates = struct {
    states : u8,

    const one : u8 = 1;

    pub fn init(cs : []const u8) WireStates {
        var states : u8 = 0;
        for (cs) |c| {
            const x = @intCast(u3, c - 'a');
            states |= one << x;
        }

        return .{.states = states};
    }

    pub fn get_count(self : WireStates) usize {
        return @popCount(u8, self.states);
    }

    pub fn is_unique_value(self: WireStates) bool {
        const on_count = self.get_count();
        return on_count == 2 or on_count == 4 or on_count == 3 or on_count == 7;
    }

    pub fn union_vals(self : WireStates, other : WireStates) WireStates {
        return WireStates {.states = self.states | other.states};
    }

    pub fn intersect(self : WireStates, other : WireStates) WireStates {
        return WireStates {.states = self.states & other.states};
    }

    pub fn is_superset(self : WireStates, other : WireStates) bool {
        return self.states == union_vals(self, other).states;
    }
};

const Remapping = struct {
    state : [10]WireStates,

    pub fn init(state : [10]WireStates) Remapping{
        return .{.state = state};
    }

    pub fn get(self : Remapping, x : WireStates) usize {
        for (self.state) |y, i| {
            if (x.states == y.states) {
                return i;
            }
        }

        @panic("Unreachable");
    }
};

const SegmentValues = struct {
    digit_values : [10] WireStates,
    output_values : [4] WireStates,

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

    fn find_superset_with_count_except(needle : WireStates, haystack : []const WireStates, except : ?WireStates, count: usize) WireStates {
        for (haystack) |x| {
            if (except != null and except.?.states == x.states) {
                continue;
            }

            if (x.get_count() == count and x.is_superset(needle)) {
                return x;
            }
        }

        @panic("unreachable");
    }

    fn find_with_count_except(haystack : []const WireStates, except : []const WireStates, count: usize) WireStates {
        for (haystack) |x| {
            if (lib.bit_structs.contains(WireStates, except, x)) {
                continue;
            }

            if (x.get_count() == count) {
                return x;
            }
        }

        @panic("unreachable");
    }

    pub fn infer_remapping(self : SegmentValues) Remapping {
        var inferred_digits : [10]WireStates = undefined;

        for (self.digit_values) |value| {
            const on_count = value.get_count();
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

        // Find with count 6
        inferred_digits[9] = find_superset_with_count_except(inferred_digits[4], self.digit_values[0..], null, 6);
        inferred_digits[0] = find_superset_with_count_except(inferred_digits[1], self.digit_values[0..], inferred_digits[9], 6);
        const exclusion_to_find_six = [2]WireStates{inferred_digits[9], inferred_digits[0]};
        inferred_digits[6] = find_with_count_except(self.digit_values[0..], exclusion_to_find_six[0..], 6);

        // Find with count 5
        inferred_digits[3] = find_superset_with_count_except(inferred_digits[1], self.digit_values[0..], null, 5);
        inferred_digits[5] = find_superset_with_count_except(inferred_digits[4].intersect(inferred_digits[6]), self.digit_values[0..], inferred_digits[3], 5);
        const exclusion_to_find_two = [2]WireStates{inferred_digits[3], inferred_digits[5]};
        inferred_digits[2] = find_with_count_except(self.digit_values[0..], exclusion_to_find_two[0..], 5);

        return Remapping.init(inferred_digits);
    }

    fn tenth_power(power : u32) u32 {
        var ret : u32 = 1;
        for (lib.range(@intCast(usize, power))) |_| {
            ret *= 10;
        }

        return ret;
    }

    pub fn get_digits(self : SegmentValues) u32 {
        var value : u32 = 0;
        const remapping = self.infer_remapping();
        for (self.output_values) |output, i| {
            const output_digit = @intCast(u32, remapping.get(output));
            value += output_digit * tenth_power(@intCast(u32, 3-i));
        }

        return value;
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
                if (output.is_unique_value()) {
                    sum += 1;
                }
            }
        }

        return sum;
    }

    pub fn get_digit_sum(self : SubDisplayState) u32 {
        var sum : u32 = 0;
        for (self.segments) |seg| {
            const digits = seg.get_digits();
            std.log.info("Digit {d}", .{digits});
            sum += digits;
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

    std.log.info("Sum {d}", .{sub_state.get_digit_sum()});
}