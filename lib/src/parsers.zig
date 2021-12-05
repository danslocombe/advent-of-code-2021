const std = @import("std");
const utils = @import("utils.zig");
const lines = @import("lines.zig");
const string_equals = utils.string_equals;
const Allocator = std.mem.Allocator;
const fixedBufferStream = std.io.fixedBufferStream;
const FixedBufferStream = std.io.FixedBufferStream;

fn print(comptime s : []const u8) void {
    std.debug.print(s, .{});
}

// Copied largely from here
// https://devlog.hexops.com/2021/zig-parser-combinators-and-why-theyre-awesome
pub const ParseError = error{
    EndOfStream,
    Utf8InvalidStartByte,
    StreamTooLong,
} || std.fs.File.ReadError
  || std.fs.File.SeekError
  || std.mem.Allocator.Error;

pub fn Parser(comptime Value: type, comptime Reader : type) type {
    return struct {
        const Self = @This();
        _parse : fn (self: *Self, src: *Reader) callconv(.Inline) ParseError!?Value,
        pub fn parse(self: *Self, src: *Reader) callconv(.Inline) ParseError!?Value {
            return self._parse(self, src);
        }
    };
}

pub fn Literal(comptime Token : type, comptime Reader: type) type {
    return struct {
        parser: Parser(Token, Reader) = .{
            ._parse = parse,
        },

        want: []const u8,
        buffer : [] u8,
        allocator : *Allocator,
        token_value : Token,

        const Self = @This();

        pub fn init(allocator : *Allocator, token_value : Token, want: []const u8) !Self {
            return Self{
                .want = want,
                .buffer = try allocator.alloc(u8, want.len),
                .allocator = allocator,
                .token_value = token_value,
            };
        }

        pub fn deinit(self : *Self) void {
            self.allocator.free(self.buffer);
        }

        fn parse(parser: *Parser(Token, Reader), src: *Reader) callconv(.Inline) ParseError!?Token {
            // Omg his is so hacky, how is this in a simple intro tutorial?
            // Think of a linked list in c, where you have some node embeded in a struct, then you want to get the overall struct.
            // Same thing here, we have the "parser" member in the literal struct and we want to get the literal struct.
            const self = @fieldParentPtr(Self, "parser", parser);
            const read_bytes = try src.reader().readAll(self.buffer);

            if (read_bytes < self.buffer.len or !utils.string_equals(self.want, self.buffer)) {
                // Not what we wanted, seek back stream.
                try src.seekableStream().seekBy(-@intCast(i64, read_bytes));
                return null;
            }

            return self.token_value;
        }
    };
}

pub fn Number(comptime NumberType : type, comptime Reader: type) type {
    return struct {
        parser: Parser(NumberType, Reader) = .{
            ._parse = parse,
        },

        allocator : *Allocator,

        const Self = @This();

        pub fn init(allocator : *Allocator) Self {
            return Self{
                .allocator = allocator,
            };
        }

        fn part_of_number(c: u8) bool {
            return c == '-' or (c >= '0' and c <= '9');
        }

        fn parse(parser: *Parser(NumberType, Reader), src: *Reader) callconv(.Inline) ParseError!?NumberType {
            const self = @fieldParentPtr(Self, "parser", parser);

            var reader = src.reader();
            // Not super efficient

            var read_bytes = std.ArrayList(u8).init(self.allocator);
            defer(read_bytes.deinit());

            var single_byte_buffer : [1]u8 = undefined;

            while ((try reader.read(&single_byte_buffer)) > 0) {
                const read_byte = single_byte_buffer[0];
                if (!part_of_number(read_byte)) {
                    // Read one byte too far
                    try src.seekableStream().seekBy(-@intCast(i64, 1));
                    break;
                }

                try read_bytes.append(read_byte);
            }

            //std.debug.print("parsing : {s} \n", .{read_bytes.items});

            return std.fmt.parseInt(NumberType, read_bytes.items, 10) catch {
                try src.seekableStream().seekBy(-@intCast(i64, read_bytes.items.len));
                return null;
            };
        }
    };
}

pub fn OneOf(comptime Value: type, comptime Reader: type) type {
    return struct {
        parser: Parser(Value, Reader) = .{
            ._parse = parse,
        },

        parsers: []*Parser(Value, Reader),

        const Self = @This();

        pub fn init(parsers: []*Parser(Value, Reader)) Self {
            return .{
                .parsers = parsers,
            };
        }

        fn parse(parser: *Parser(Value, Reader), src: *Reader) callconv(.Inline) ParseError!?Value {
            const self = @fieldParentPtr(Self, "parser", parser);
            for (self.parsers) |child_parser| {
                const result = try child_parser.parse(src);
                if (result != null) {
                    return result;
                }
            }

            return null;
        }
    };
}

// Note lines cant fail, always produces a value of at least one.
pub fn LinesParser(comptime Value: type, comptime Reader: type) type {
    return struct {
        parser: Parser(std.ArrayList(?Value), Reader) = .{
            ._parse = parse,
        },

        child: *Parser(Value, FixedBufferStream([] const u8)),
        allocator : *Allocator,

        const Self = @This();

        pub fn init(allocator : *Allocator, child: *Parser(Value, FixedBufferStream([] const u8))) Self {
            return .{
                .child = child, 
                .allocator = allocator,
            };
        }

        pub fn deinit(self : *Self) void {
            self.lines_backing.deinit();
        }

        fn parse(parser: *Parser(std.ArrayList(?Value), Reader), src: *Reader) callconv(.Inline) ParseError!?std.ArrayList(?Value) {
            const self = @fieldParentPtr(Self, "parser", parser);

            // In theory could read one by one, but is easier to just allocat into Lines block.
            var read_lines = try lines.lines_from_reader(Reader, self.allocator, src);
            defer(read_lines.deinit(self.allocator));

            var results = std.ArrayList(?Value).init(self.allocator);

            var iter = lines.Lines.Iterator.init(read_lines);
            while (iter.next()) |line| {
                var stream = fixedBufferStream(line);
                try results.append(try self.child.parse(&stream));
            }

            return results;
        }
    };
}

pub fn Chain(comptime Value: type, comptime Reader: type) type {
    return struct {
        parser: Parser(std.ArrayList(Value), Reader) = .{
            ._parse = parse,
        },

        parsers: []*Parser(Value, Reader),
        allocator : *Allocator,

        const Self = @This();

        pub fn init(allocator : *Allocator, parsers: []*Parser(Value, Reader)) Self {
            return .{
                .allocator = allocator,
                .parsers = parsers,
            };
        }

        fn parse(parser: *Parser(std.ArrayList(Value), Reader), src: *Reader) callconv(.Inline) ParseError!?std.ArrayList(Value) {
            const self = @fieldParentPtr(Self, "parser", parser);

            var results = std.ArrayList(Value).init(self.allocator);

            for (self.parsers) |child_parser| {
                const result = try child_parser.parse(src);
                if (result == null) {
                    return null;
                }

                try results.append(result.?);
            }

            return results;
        }
    };
}

pub fn OneOrMany(comptime Value: type, comptime Reader: type) type {
    return struct {
        parser: Parser(std.ArrayList(Value), Reader) = .{
            ._parse = parse,
        },

        inner: *Parser(Value, Reader),
        allocator : *Allocator,

        const Self = @This();

        pub fn init(allocator : *Allocator, inner: *Parser(Value, Reader)) Self {
            return .{
                .allocator = allocator,
                .inner = inner,
            };
        }

        fn parse(parser: *Parser(std.ArrayList(Value), Reader), src: *Reader) callconv(.Inline) ParseError!?std.ArrayList(Value) {
            const self = @fieldParentPtr(Self, "parser", parser);

            var results = std.ArrayList(Value).init(self.allocator);

            while (try self.inner.parse(src)) |result| {
                try results.append(result);
            }

            return results;
        }
    };
}

pub fn Whitespace(comptime Value: type, comptime Reader: type) type {
    return struct {
        parser: Parser(Value, Reader) = .{
            ._parse = parse,
        },

        allocator : *Allocator,

        token : Value,

        const Self = @This();

        pub fn init(allocator : *Allocator, token : Value) !Self {
            return Self {
                .allocator = allocator,
                .token = token,
            };
        }

        fn parse(parser: *Parser(Value, Reader), src: *Reader) callconv(.Inline) ParseError!?Value {
            const self = @fieldParentPtr(Self, "parser", parser);

            var space_literal_parser = try Literal(void, Reader).init(self.allocator, .{}, " ");
            defer(space_literal_parser.deinit());
            var one_or_many = OneOrMany(void, Reader).init(self.allocator, &space_literal_parser.parser);

            const result = try one_or_many.parser.parse(src);
            defer(result.?.deinit());
            return self.token;
        }
    };
}

pub fn Mapper(comptime Source: type, comptime Target: type, comptime MapperType: type, comptime Reader: type) type {
    return struct {
        parser: Parser(Target, Reader) = .{
            ._parse = parse,
        },

        inner: *Parser(Source, Reader),

        const Self = @This();

        pub fn init(inner : *Parser(Source, Reader)) Self {
            return Self {
                .inner = inner,
            };
        }

        fn parse(parser: *Parser(Target, Reader), src: *Reader) callconv(.Inline) ParseError!?Target {
            const self = @fieldParentPtr(Self, "parser", parser);
            const result = try self.inner.parse(src);
            if (result == null) {
                return null;
            }

            return MapperType.map(result.?);
        }
    };
}


const testing = std.testing;
test "test parse literal" {
    var allocator = std.testing.allocator; 
    var stream = fixedBufferStream("hello there");

    var literal_parser = try Literal(u32, @TypeOf(stream)).init(allocator, 49, "hello");
    defer(literal_parser.deinit());
    var p = &literal_parser.parser;
    const result = try p.parse(&stream);

    try testing.expect(result != null);
    try testing.expect(result.? == 49);

    const rest = try stream.reader().readAllAlloc(allocator, 1000);
    defer(allocator.free(rest));
    try testing.expect(string_equals(" there", rest));
}

test "test parse one of" {
    var allocator = std.testing.allocator; 

    var stream = fixedBufferStream("hello there");

    var cat_parser = try Literal(u32, @TypeOf(stream)).init(allocator, 25, "cat");
    defer(cat_parser.deinit());
    var hello_parser = try Literal(u32, @TypeOf(stream)).init(allocator, 49, "hello");
    defer(hello_parser.deinit());

    var one_of_parser = OneOf(u32, @TypeOf(stream)).init(&.{
        &cat_parser.parser,
        &hello_parser.parser,
    });

    var p = &one_of_parser.parser;
    const result = try p.parse(&stream);

    try testing.expect(result.? == 49);

    const rest = try stream.reader().readAllAlloc(allocator, 1000);
    defer(allocator.free(rest));
    try testing.expect(string_equals(" there", rest));
}

test "test parse lines" {
    var allocator = std.testing.allocator; 

    var stream = fixedBufferStream("hello there\nhello there\r\nno hello");

    var hello_parser = try Literal(u32, FixedBufferStream([] const u8)).init(allocator, 49, "hello");
    defer(hello_parser.deinit());

    var lines_parser = LinesParser(u32, @TypeOf(stream)).init(allocator, &hello_parser.parser);
    var p = &lines_parser.parser;
    const result = try p.parse(&stream);

    try testing.expect(result != null);

    defer(result.?.deinit());

    try testing.expect(result.?.items.len == 3);
    try testing.expect(result.?.items[0].? == 49);
    try testing.expect(result.?.items[1].? == 49);
    try testing.expect(result.?.items[2] == null);

    const rest = try stream.reader().readAllAlloc(allocator, 1000);
    defer(allocator.free(rest));
    try testing.expect(rest.len == 0);
}

test "test parse chain" {
    var allocator = std.testing.allocator; 

    var stream = fixedBufferStream("hellothere");

    var hello_parser = try Literal(u32, @TypeOf(stream)).init(allocator, 49, "hello");
    defer(hello_parser.deinit());

    var there_parser = try Literal(u32, @TypeOf(stream)).init(allocator, 10, "there");
    defer(there_parser.deinit());

    var chain = Chain(u32, @TypeOf(stream)).init(allocator, &.{&hello_parser.parser, &there_parser.parser});
    var p = &chain.parser;
    const result = try p.parse(&stream);

    try testing.expect(result != null);

    defer(result.?.deinit());

    try testing.expect(result.?.items.len == 2);
    try testing.expect(result.?.items[0] == 49);
    try testing.expect(result.?.items[1] == 10);

    const rest = try stream.reader().readAllAlloc(allocator, 1000);
    defer(allocator.free(rest));
    try testing.expect(rest.len == 0);
}

test "test whitespace" {
    var allocator = std.testing.allocator; 

    var stream = fixedBufferStream("  hello");

    var whitespace = try Whitespace(u32, @TypeOf(stream)).init(allocator, 10);
    var p = &whitespace.parser;
    const result = try p.parse(&stream);

    try testing.expect(result != null);
    try testing.expect(result.? == 10);

    const rest = try stream.reader().readAllAlloc(allocator, 1000);
    defer(allocator.free(rest));
    try testing.expect(string_equals(rest, "hello"));
}

test "test read numbers" {
    var allocator = std.testing.allocator; 

    var stream = fixedBufferStream("10  30");

    const ReadTagType = enum {
        read_whitespace,
        read_number,
    };

    const ReadType = union(ReadTagType) {
        read_whitespace: void,
        read_number: u32,
    };

    var number_parser = Number(u32, @TypeOf(stream)).init(allocator);

    const NumberToReadType = struct {
        pub fn map(x: u32) ReadType {
            return ReadType{.read_number = x};
        }
    };

    var lift = Mapper(u32, ReadType, NumberToReadType, @TypeOf(stream)).init(&number_parser.parser);
    var whitespace = try Whitespace(ReadType, @TypeOf(stream)).init(allocator, ReadType.read_whitespace);

    var chain = Chain(ReadType, @TypeOf(stream)).init(allocator, &.{
        &lift.parser,
        &whitespace.parser,
        &lift.parser,
        });

    var p = &chain.parser;
    const result = try p.parse(&stream);

    try testing.expect(result != null);
    defer(result.?.deinit());

    try testing.expect(result.?.items[0] == ReadType.read_number);
    try testing.expect(result.?.items[0].read_number == 10);
    try testing.expect(result.?.items[1] == ReadType.read_whitespace);
    try testing.expect(result.?.items[2].read_number == 30);

    const rest = try stream.reader().readAllAlloc(allocator, 1000);
    defer(allocator.free(rest));
    try testing.expect(rest.len == 0);
}