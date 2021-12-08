const std = @import("std");

pub fn string_equals(xs: []const u8, ys: [] const u8) bool {
    return std.mem.eql(u8, xs, ys);
}

// Not in stdlib for some readon :(
pub fn range(len: usize) []const u0 {
    return @as([*]u0, undefined)[0..len];
}

pub fn Pair(comptime NumType: type) type {
    return struct {
        x : NumType,
        y : NumType,

        const Self = @This();

        pub fn add(self : Self, other : Self) Self {
            return .{.x = self.x + other.x, .y = self.y + other.y};
        }

        pub fn equal(self : Self, other : Self) bool {
            return self.x == other.x and self.y == other.y;
        }
    };
}
