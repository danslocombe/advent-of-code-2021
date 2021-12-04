const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

pub const LineDef = struct {
    // Represents a line with [start..end]
    start : usize,
    end : usize,
};

pub const Lines = struct {
    backing: []const u8,
    lines: std.ArrayList(LineDef),
    backing_owned : bool,

    pub fn from_file(allocator: *Allocator, dir: std.fs.Dir, file_name : []const u8) !Lines {
        const u32_max = 4294967295;
        const backing = try dir.readFileAlloc(allocator, file_name, u32_max);
        print("Read {d} bytes\n", .{backing.len});
        var lines = try init(allocator, backing);
        lines.backing_owned = true;
        return lines;
    }

    pub fn init(allocator: *Allocator, backing: []const u8) !Lines {
        var line_defs = std.ArrayList(LineDef).init(allocator);

        var line_start : usize = 0;
        for (backing) |c, i| {

            var found_end  = false;

            if (c == @intCast(u8, '\r')) {
                if (i + 1 < backing.len and backing[i+1] == @intCast(u8, '\n')) {
                    found_end = true;
                }
            }
            else if (c == @intCast(u8, '\n')) {
                found_end = true;
            }

            if (found_end) {
                if (i > line_start) {
                    try line_defs.append(.{.start = line_start, .end = i});
                }

                line_start = i+1;
            }
        }

        if (backing.len > line_start) {
            try line_defs.append(.{.start = line_start, .end = backing.len});
        }

        print("Parsed {d} non-empty lines\n", .{line_defs.items.len});

        return Lines{.backing = backing, .lines = line_defs, .backing_owned = false};
    }

    pub fn deinit(self: Lines, allocator: *Allocator) void {
        if (self.backing_owned) {
            allocator.free(self.backing);
        }

        self.lines.deinit();
    }

    pub fn get(self : Lines, i: usize) ?[]const u8 {
        if (i >= self.lines.items.len) {
            return null;
        }

        const line_def = self.lines.items[i];
        return self.backing[line_def.start..line_def.end];
    }

    pub fn len(self : Lines) usize {
        return self.lines.items.len;
    }
};

// Not in stdlib for some readon :(
pub fn range(len: usize) []const u0 {
    return @as([*]u0, undefined)[0..len];
}

//const testing = std.testing;
//test "basic add functionality" {
    //try testing.expect(add(3, 7) == 10);
//}
