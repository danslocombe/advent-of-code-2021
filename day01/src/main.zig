const std = @import("std");
const dan_lib = @import("dan_lib");
const Lines = dan_lib.Lines;
const print = std.debug.print;

const Sonar = struct {
    prev_value : ?u32,
    increases : u32,

    pub fn new() Sonar {
        return .{ .prev_value = null, .increases = 0};
    }

    pub fn bleep_ocean(self: *Sonar, reading : u32) void {
        //print("Bleeping {d}\n", .{reading});
        if (self.prev_value) |prev| {
            if (reading > prev) {
                self.increases+=1;
            }
        }

        self.prev_value = reading;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = &gpa.allocator;

    var input = try Lines.from_file(allocator, std.fs.cwd(), "day1_input.txt");
    defer(input.deinit(allocator));

    var sonar = Sonar.new();

    var iter = Lines.Iterator.init(input);
    while (iter.next()) |line| {
        const parsed = try std.fmt.parseInt(u32, line, 10);
        sonar.bleep_ocean(parsed);
    }

    print("Part 1 Measured {d} increases\n", .{sonar.increases});

    sonar = Sonar.new();

    var prev_1 : ?u32 = null;
    var prev_2 : ?u32 = null;
    iter = Lines.Iterator.init(input);
    while (iter.next()) |line| {
        const parsed = try std.fmt.parseInt(u32, line, 10);
        if (prev_1 != null and prev_2 != null) {
            sonar.bleep_ocean(parsed + prev_1.? + prev_2.?);
        }

        prev_2 = prev_1;
        prev_1 = parsed;
    }

    print("Part 2 Measured {d} increases", .{sonar.increases});
}