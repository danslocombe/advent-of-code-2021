const std = @import("std");
const Allocator = std.mem.Allocator;

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

        pub fn init(x : anytype, y : anytype) Self {
            return .{
                .x = @intCast(NumType, x),
                .y = @intCast(NumType, y),
            };
        }

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

    pub fn init(allocator : Allocator, width : usize, height : usize) !ByteGrid {
        return ByteGrid {
            .values = try allocator.alloc(u8, width * height),
            .width = width,
            .height = height,
        };
    }

    pub fn parse(comptime Reader : type, reader : *Reader, allocator : Allocator) !ByteGrid {
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

    pub fn clone(self : ByteGrid, allocator : Allocator) !ByteGrid {
        var copied = try allocator.alloc(u8, self.values.len);
        std.mem.copy(u8, copied, self.values);
        return ByteGrid {
            .values = copied,
            .width = self.width,
            .height = self.height,
        };
    }
};

pub fn copy_list(comptime T : type, allocator : Allocator, xs : std.ArrayList(T)) !std.ArrayList(T) {
    var new = try std.ArrayList(T).initCapacity(allocator, xs.items.len);
    for (xs.items) |x| {
        try new.append(x);
    }

    return new;
}

pub fn PrimativeComparer(comptime T : type) type {
    return struct {
        pub fn cmp(_ : void, x : T, y : T) bool {
            return x < y;
        }
    };
}

pub fn BucketCounter(comptime T : type) type {
    return struct {
        hashmap : std.AutoHashMap(T, u64),
        allocator : Allocator,

        const Self = @This();

        pub fn init(allocator : Allocator) Self {
            return .{
                .allocator = allocator,
                .hashmap = std.AutoHashMap(T, u64).init(allocator),
            };
        }

        pub fn add(self : *Self, x : T, count : u64) !void {
            if (self.*.hashmap.getPtr(x)) |existing| {
                existing.* += count;
            }
            else {
                try self.*.hashmap.put(x, count);
            }
        }

        pub const Bucket = struct {
            value : T,
            sum : u64,
        };

        fn sum_cmp (_ : void, x : Bucket, y : Bucket) bool {
            return x.sum < y.sum;
        }

        pub fn get_buckets(self : Self) !std.ArrayList(Bucket) {
            var buckets = std.ArrayList(Bucket).init(self.allocator);
            var iter = self.hashmap.iterator();
            while (iter.next()) |kv| {
                try buckets.append(Bucket{
                    .value = kv.key_ptr.*,
                    .sum = kv.value_ptr.*,
                });
            }

            std.sort.sort(Bucket, buckets.items, void{}, sum_cmp);
            return buckets;
        }
    };
}

pub fn UIntMap(comptime T : type) type {
    return struct {
        xs : std.ArrayList(?T),
        const Self  = @This();
        pub fn init(allocator : Allocator) Self {
            return .{.xs = std.ArrayList(?T).init(allocator)};
        }

        pub fn set(self : *Self, k : usize, v : T) !void {
            while (k >= self.*.xs.items.len) {
                // TODO replace with appendNTimes
                try self.*.xs.append(null);
            }

            self.*.xs.items[k] = v;
        }

        pub fn get(self : Self, k : usize) ?T {
            if (k < self.xs.items.len) {
                return self.xs.items[k];
            }

            return null;
        }

        pub fn get_set(self : *Self, k : usize, v : T) !bool {
            if (self.get(k)) |_| {
                return false;
            }

            try self.set(k, v);
            return true;
        }
    };
}