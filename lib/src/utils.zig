const std = @import("std");

pub fn string_equals(xs: []const u8, ys: [] const u8) bool {
    return std.mem.eql(u8, xs, ys);
}

// Not in stdlib for some readon :(
pub fn range(len: usize) []const u0 {
    return @as([*]u0, undefined)[0..len];
}