const std = @import("std");
const dan_lib = @import("dan_lib");
const Lines = dan_lib.Lines;
const print = std.debug.print;

// TODO somewhere in the stdlib?
const u32_max = 4294967295;

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

    for (dan_lib.range(input.len())) |_, i| {
        const line = input.get(i);
        if (line) |l| {
            const parsed = try std.fmt.parseInt(u32, l, 10);
            sonar.bleep_ocean(parsed);
        }
    }

    print("Measured {d} increases", .{sonar.increases});
}