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

pub const ByteGrid = struct {
    values : []u8,
    width : usize,
    height : usize,

    pub const Pos = Pair(i32);

    pub fn init(allocator : std.mem.Allocator, width : usize, height : usize) !ByteGrid {
        return ByteGrid {
            .values = allocator.allocate(u8, width * height),
            .width = width,
            .height = height,
        };
    }

    pub fn parse(comptime Reader : type, reader : *Reader, allocator : std.mem.Allocator) !ByteGrid {
        const dan_parsers = @import("parsers.zig");
        const FBSType = std.io.FixedBufferStream([] const u8);

        var map = dan_parsers.Mapper(u8, u8, struct { pub fn map(x : u8) u8 {
            return x - '0';
        }}, FBSType).init(&dan_parsers.SingleChar(FBSType).init().parser);

        var parser = dan_parsers.LinesParser(std.ArrayList(u8), Reader).init(
            allocator,
            &dan_parsers.OneOrMany(u8, FBSType).init(allocator, &map.parser).parser);

        const parsed = (try parser.parser.parse(reader)).?;
        const width = parsed.items[0].?.items.len;
        const height = parsed.items.len;

        var flattened = try std.ArrayList(u8).initCapacity(allocator, width * height);
        for (parsed.items) |line| {
            if (line) |l| {
                try flattened.appendSlice(l.items);
            }
        }

        return ByteGrid{.values = flattened.items, .width = width, .height = height};
    }


    pub fn i_to_pos(self : ByteGrid, i : usize) Pos {
        return .{.x = @intCast(i32, @mod(i, self.width)), .y = @intCast(i32, @divFloor(i, self.width))};
    }

    pub fn pos_to_i(self : ByteGrid, pos : Pos) ?usize {
        if (pos.x < 0 or pos.y < 0 or pos.x == self.width or pos.y == self.height) {
            return null;
        }

        return @intCast(usize, pos.x + pos.y * @intCast(i32, self.width));
    }

    pub fn get_line(self : ByteGrid, y : usize) []u8 {
        return self.values[y*self.width..(y+1)*self.width];
    }
};