const std = @import("std");
const dan_lib = @import("dan_lib");
const Allocator = std.mem.Allocator;

const BitReader = struct {
    backing : []const u8,
    index : usize,

    fn mask(x : u3) u8 {
        const one : u8 = 1;
        return one << (7-x);
    }

    fn cur_mask(self : BitReader) u8 {
        return mask(self.get_bit_index());
    }

    fn get_byte_index(self : BitReader) usize {
        return @divFloor(self.index, 8);
    }

    fn get_bit_index(self : BitReader) u3 {
        return @intCast(u3, @mod(self.index, 8));
    }

    fn read_bit_adv(self: *BitReader) ?bool {
        const byte = self.*.backing[self.*.get_byte_index()];
        const value = self.*.cur_mask() & byte != 0;
        self.*.index += 1;
        return value;
    }

    pub fn read(self: *BitReader, comptime T : type) T {
        if (self.m_read(T)) |x| {
            return x;
        }
        else {
            @panic("Tried to read past stream end");
        }
    }

    pub fn m_read(self: *BitReader, comptime T : type) ?T {
        const bit_size : usize = @bitSizeOf(T);
        var bits_read : usize = 0;
        var x : usize = 0;

        while (bits_read < bit_size) {
            if (self.read_bit_adv()) |b| {
                var bb = @intCast(usize, @boolToInt(b));

                const shift = @intCast(u6, (bit_size - bits_read - 1));
                x |= bb << shift;
            }
            else {
                @setCold(true);
                return null;
            }

            bits_read += 1;
        }

        return @intCast(T, x);
    }
};

pub fn create_bit_reader(allocator : Allocator, input : []const u8) !BitReader {
    var parsed = try allocator.alloc(u8, input.len / 2);
    for (dan_lib.utils.range(parsed.len)) |_, i| {
        const parsed_major = try std.fmt.parseUnsigned(u8, input[2*i..2*i+1], 16);
        const parsed_minor = try std.fmt.parseUnsigned(u8, input[2*i+1..2*i+2], 16);

        parsed[i] = parsed_major << 4;
        parsed[i] |= parsed_minor;
    }

    return BitReader {
        .backing = parsed,
        .index = 0,
    };
}

const PacketType = enum {
    literal,
    operator,
};

const Literal = struct {
    val : u64,
    pub fn parse(reader : *BitReader) Literal {
        var val : u64 = 0;
        while (true) {
            const keep_reading = reader.read(u1) != 0;
            val = val << 4;
            val |= @intCast(u64, reader.read(u4));

            if (!keep_reading) {
                return .{
                    .val = val,
                };
            }
        }
    }
};

const OperatorType = enum {
    sum,
    product,
    min,
    max,
    greater,
    less,
    equal,
};

const Operator = struct {
    operator : OperatorType,
    subpackets : std.ArrayList(Packet),

    pub fn parse(allocator : Allocator, type_id : u3, reader : *BitReader) anyerror!Operator {
        const operator = switch (type_id) {
            0 => OperatorType.sum,
            1 => OperatorType.product,
            2 => OperatorType.min,
            3 => OperatorType.max,
            4 => @panic("Unreachable"),
            5 => OperatorType.greater,
            6 => OperatorType.less,
            7 => OperatorType.equal,
        };

        var subpackets = std.ArrayList(Packet).init(allocator);
        if (reader.read(u1) == 0) {
            const total_length = reader.read(u15);
            //std.log.info("Parsing operator with inner length {d}", .{total_length});
            const start_pos = reader.index;
            while (true) {
                try subpackets.append(try Packet.parse(allocator, reader));
                if (reader.index >= start_pos + total_length) {
                    break;
                }
            }
        }
        else {
            var sub_packet_count = reader.read(u11);
            //std.log.info("Parsing operator with count {d}", .{sub_packet_count});
            for (dan_lib.range(@intCast(usize, sub_packet_count))) |_| {
                try subpackets.append(try Packet.parse(allocator, reader));
            }
        }

        return Operator {
            .subpackets = subpackets,
            .operator = operator,
        };
    }

    pub fn evaluate(self : Operator) u64 {
        switch (self.operator) {
            OperatorType.sum => {
                var val : u64 = 0;
                for (self.subpackets.items) |sub| {
                    val += sub.evaluate();
                }
                return val;
            },
            OperatorType.product => {
                var val : u64 = 1;
                for (self.subpackets.items) |sub| {
                    val *= sub.evaluate();
                }
                return val;
            },
            OperatorType.min => {
                var val : u64 = self.subpackets.items[0].evaluate();
                for (self.subpackets.items[1..]) |sub| {
                    val = @minimum(val, sub.evaluate());
                }
                return val;
            },
            OperatorType.max => {
                var val : u64 = self.subpackets.items[0].evaluate();
                for (self.subpackets.items[1..]) |sub| {
                    val = @maximum(val, sub.evaluate());
                }
                return val;
            },
            OperatorType.greater => {
                return @boolToInt(self.subpackets.items[0].evaluate() > self.subpackets.items[1].evaluate());
            },
            OperatorType.less => {
                return @boolToInt(self.subpackets.items[0].evaluate() < self.subpackets.items[1].evaluate());
            },
            OperatorType.equal => {
                return @boolToInt(self.subpackets.items[0].evaluate() == self.subpackets.items[1].evaluate());
            },
        }
    }
};

const PacketInner = union(PacketType) {
    literal : Literal,
    operator : Operator,
};

const Packet = struct {
    version : u3,
    type_id : u3,
    inner : PacketInner,

    pub fn parse(allocator : Allocator, reader : *BitReader) anyerror!Packet {
        const version = reader.read(u3);
        const type_id = reader.read(u3);
        const inner = switch (type_id) {
            4 => PacketInner{.literal = Literal.parse(reader)},
            else => PacketInner{.operator = try Operator.parse(allocator, type_id, reader), },
        };

        //const inner = .{.literal = Literal.parse(reader)};
        //const inner = @panic("AFW");

        return Packet {
            .version = version,
            .type_id = type_id,
            .inner = inner,
        };
    }

    pub fn sum_versions(self : Packet) u32 {
        var sum = @intCast(u32, self.version);
        switch (self.inner) {
            PacketType.operator => {
                for (self.inner.operator.subpackets.items) |sub| {
                    sum += sub.sum_versions();
                }
            },
            else => {},
        }

        return sum;
    }

    pub fn evaluate(self : Packet) u64 {
        return switch (self.inner) {
            PacketType.operator => self.inner.operator.evaluate(),
            else => self.inner.literal.val,
        };
    }
};


pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const input = try std.fs.cwd().readFileAlloc(arena.allocator(), "input.txt", 100000);
    var reader = try create_bit_reader(arena.allocator(), input);

    var parsed = try Packet.parse(arena.allocator(), &reader);
    std.log.info("{}", .{parsed});
    std.log.info("Summed versions {d}", .{parsed.sum_versions()});
    std.log.info("Evaluated {d}", .{parsed.evaluate()});
}
