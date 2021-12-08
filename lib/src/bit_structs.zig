const std = @import("std");

pub fn eq(comptime T : type, x : T, y : T) bool {
    return std.mem.eql(u8, std.mem.asBytes(&x), std.mem.asBytes(&y));
}

pub fn contains(comptime T : type, haystack : []const T, needle : T) bool {
    for (haystack) |x| {
        if (eq(T, x, needle)) {
            return true;
        }
    }

    return false;
}