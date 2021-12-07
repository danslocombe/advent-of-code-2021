const std = @import("std");
const dan_lib = @import("dan_lib");
const Lines = dan_lib.Lines;
const string_equals = dan_lib.string_equals;
const print = std.debug.print;
const Allocator = std.mem.Allocator;
const Point = dan_lib.utils.Pair(i32);
const Parser = dan_lib.parsers.Parser;
const Literal = dan_lib.parsers.Literal;
const Chain = dan_lib.parsers.Chain;
const ParseError = dan_lib.parsers.ParseError;
const Mapper = dan_lib.parsers.Mapper;


const Line = struct {
    start : Point,
    end : Point,

    pub fn is_straight(self : Line) bool {
        return self.start.x == self.end.x or self.start.y == self.end.y;
    }

    pub fn get_incr(self : Line) Point {
        var incr = Point{.x = 0, .y = 0};

        if (self.start.x != self.end.x) {
            if (self.start.x < self.end.x) {
                incr.x = 1;
            } 
            else {
                incr.x = -1;
            }
        }
        if (self.start.y != self.end.y) {
            if (self.start.y < self.end.y) {
                incr.y = 1;
            } 
            else {
                incr.y = -1;
            }
        }

        return incr;
    }
};

const OceanFloor = struct {
    floor : [] u16,
    width : usize,
    height : usize,
    points_at_least_two : u32 = 0,

    const Self = @This();

    pub fn init(allocator : Allocator, width : usize, height : usize) !Self {
        var floor = try allocator.alloc(u16, width * height);
        for (floor) |_, i| {
            floor[i] = 0;
        }

        return Self {.floor = floor, .width = width, .height = height};
    }

    pub fn deinit(self : Self, allocator : Allocator) void {
        allocator.free(self.floor);
    }

    fn get_index(self : Self, x : u16, y : u16) usize {
        return x + y * self.width;
    }

    pub fn apply_point(self: *Self, point: Point) void {
        //print("applying {d},{d}\n", .{point.x, point.y});
        const index = self.get_index(@intCast(u16, point.x), @intCast(u16, point.y));
        self.floor[index] += 1;
        //print("gbeg{d}\n", .{self.floor[index]});
        if (self.floor[index] == 2) {
            self.points_at_least_two += 1;
        }
    }

    pub fn apply_line(self : *Self, line : Line) void {
        const incr = line.get_incr();
        var p = line.start;

        while (!p.equal(line.end)) {
            self.apply_point(p);
            p.x += incr.x;
            p.y += incr.y;
        }

        self.apply_point(p);
    }
};

pub fn OceanFloorLineParser(comptime Reader: type) type {
    return struct {
        parser: Parser(Line, Reader) = .{
            ._parse = parse,
        },

        allocator : Allocator,

        const Self = @This();

        pub fn init(allocator : Allocator) Self {
            return Self {
                .allocator = allocator,
            };
        }

        fn parse(parser: *Parser(Line, Reader), src: *Reader) callconv(.Inline) ParseError!?Line {
            const self = @fieldParentPtr(Self, "parser", parser);

            const LiftType = enum {
                read_point,
                read_garbage,
            };

            const Lift = union(LiftType) {
                read_point: Point,
                read_garbage: void,
            };

            var pair_parser = dan_lib.parsers.PairParser(i32, Reader).init(self.allocator);
            const PairMapperType = struct {
                pub fn map(x : *Point) Lift {
                    return Lift{.read_point = .{.x = x.x, .y = x.y}};
                }
            };
            var pair_parser_lifted = dan_lib.parsers.Mapper(Point, Lift, PairMapperType, Reader).init(&pair_parser.parser);

            var whitespace_parser = dan_lib.parsers.Whitespace(Lift, Reader).init(self.allocator, Lift{.read_garbage = .{}});
            var arrow_parser = try Literal(Lift, Reader).init(self.allocator, Lift{.read_garbage = .{}}, "->");
            defer(arrow_parser.deinit());

            var chain = Chain(Lift, Reader).init(self.allocator, &.{
                &pair_parser_lifted.parser,
                &whitespace_parser.parser,
                &arrow_parser.parser,
                &whitespace_parser.parser,
                &pair_parser_lifted.parser,
            });

            const MapperType = struct {
                pub fn map(x: *std.ArrayList(Lift)) Line {
                    defer(x.deinit());
                    return .{.start = x.items[0].read_point, .end = x.items[4].read_point};
                }
            };

            var mapper = Mapper(std.ArrayList(Lift), Line, MapperType, Reader).init(&chain.parser);
            return mapper.parser.parse(src);
        }
    };
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = gpa.allocator();

    var input_file = try std.fs.cwd().openFile("day5_input.txt", .{});
    var line_parser = OceanFloorLineParser(std.io.FixedBufferStream([]const u8)).init(allocator);
    var input_parser = dan_lib.parsers.LinesParser(Line, @TypeOf(input_file)).init(allocator, &line_parser.parser);

    var result = try input_parser.parser.parse(&input_file);

    var testfn = 2;

    var max_width : i32 = 0;
    var max_height : i32 = 0;
    for (result.?.items) |line| {
        if (line) |l| {
            max_width = std.math.max(max_width, std.math.max(l.start.x, l.end.x));
            max_height = std.math.max(max_height, std.math.max(l.start.y, l.end.y));
        }
    }

    var floor = try OceanFloor.init(allocator, @intCast(usize, max_width + 1), @intCast(usize, max_height + 1));

    for (result.?.items) |line| {
        if (line) |l| {
            print("{d} {d} -> {d} {d}\n", .{l.start.x, l.start.y, l.end.x, l.end.y});
            //if (l.is_straight())
            {
                floor.apply_line(l);
            }
        }
    }

    print("Points at least 2 {d}\n", .{floor.points_at_least_two});

    defer(result.?.deinit());
}