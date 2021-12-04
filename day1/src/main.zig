const std = @import("std");
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

    const input = try std.fs.cwd().readFileAlloc(allocator, "day1_input.txt", u32_max);
    defer allocator.free(input);
    print("Read {d} bytes\n", .{input.len});

    var sonar = Sonar.new();

    var line_start : usize = 0;
    for (input) |c, i| {
        if (c == @intCast(u8, '\n')) {
            const parsed = try parse(input, line_start, i);
            if (parsed) |p| {
                sonar.bleep_ocean(p);
            }
            line_start = i+1;
        }
    }

    const last = try parse(input, line_start, input.len);
    if (last) |p| {
        sonar.bleep_ocean(p);
    }

    print("Measured {d} increases", .{sonar.increases});
}

fn parse(input : []u8, start : usize, end : usize) !?u32 {
    if (end-start == 0) {
        return null;
    }

    return try std.fmt.parseInt(u32, input[start..end], 10);
}