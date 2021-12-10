const std = @import("std");
const lib = @import("dan_lib");
const Allocator = std.mem.Allocator;

const ChunkTokenType = enum {
    paren,
    square,
    curly,
    angular,

    pub fn get_syntax_cost(self : ChunkTokenType) u64 {
        return switch (self) {
            ChunkTokenType.paren => 3,
            ChunkTokenType.square => 57,
            ChunkTokenType.curly => 1197,
            ChunkTokenType.angular => 25137,
        };
    }

    pub fn get_completion_cost(self : ChunkTokenType) u64 {
        return switch (self) {
            ChunkTokenType.paren => 1,
            ChunkTokenType.square => 2,
            ChunkTokenType.curly => 3,
            ChunkTokenType.angular => 4,
        };
    }
};

const ChunkToken = struct {
    token_type : ChunkTokenType,
    opening : bool,

    pub fn parse(c : u8) ChunkToken {
        return switch (c) {
            '(' => .{.token_type = ChunkTokenType.paren, .opening = true},
            ')' => .{.token_type = ChunkTokenType.paren, .opening = false},
            '[' => .{.token_type = ChunkTokenType.square, .opening = true},
            ']' => .{.token_type = ChunkTokenType.square, .opening = false},
            '{' => .{.token_type = ChunkTokenType.curly, .opening = true},
            '}' => .{.token_type = ChunkTokenType.curly, .opening = false},
            '<' => .{.token_type = ChunkTokenType.angular, .opening = true},
            '>' => .{.token_type = ChunkTokenType.angular, .opening = false},
            else => @panic("Invalid input"),
        };
    }
};

const NavParser = struct {
    input : []const u8,
    allocator : Allocator,

    pub fn init(input : []const u8, allocator : Allocator) NavParser {
        return .{.input = input, .allocator = allocator};
    }

    pub fn check_syntax(self : NavParser) !?ChunkTokenType {
        var stack = std.ArrayList(ChunkToken).init(self.allocator);

        for (self.input) |c| {
            const token = ChunkToken.parse(c);
            if (token.opening) {
                try stack.append(token);
            }
            else {
                const popped = stack.pop();
                if (!popped.opening or popped.token_type != token.token_type) {
                    return token.token_type;
                }
            }
        }

        return null;
    }

    const Completion = struct {
        xs : std.ArrayList(ChunkToken),

        pub fn get_cost(self : Completion) u64 {
            var score : u64 = 0;
            for (self.xs.items) |x| {
                score *= 5;
                score += x.token_type.get_completion_cost();
            }

            return score;
        }

        pub fn from_parse_stack(allocator : Allocator, stack : []const ChunkToken) !Completion {
            var xs = std.ArrayList(ChunkToken).init(allocator);

            for (lib.range(stack.len)) |_, i| {
                const index = stack.len - i - 1;

                var x = ChunkToken { .token_type = stack[index].token_type, .opening = false};
                try xs.append(x);
            }

            return Completion {.xs = xs};
        }
    };

    pub fn get_completion(self : NavParser) !?Completion {
        var stack = std.ArrayList(ChunkToken).init(self.allocator);

        for (self.input) |c| {
            const token = ChunkToken.parse(c);
            if (token.opening) {
                try stack.append(token);
            }
            else {
                const popped = stack.pop();
                if (!popped.opening or popped.token_type != token.token_type) {
                    return null;
                }
            }
        }

        return try Completion.from_parse_stack(self.allocator,stack.items);
    }
};

const Nav = struct {
    lines : lib.Lines,
    allocator : Allocator,

    pub fn init(lines : lib.Lines, allocator : Allocator) Nav {
        return .{.lines = lines, .allocator = allocator};
    }

    pub fn syntax_error_cost(self : Nav) !u64 {
        var invalid_token_counts = std.AutoArrayHashMap(ChunkTokenType, usize).init(self.allocator);
        var lines_iter = lib.Lines.Iterator.init(self.lines);
        while (lines_iter.next()) |l| {
            var parser = NavParser.init(l, self.allocator);

            if (try parser.check_syntax()) |syntax_error| {
                if (invalid_token_counts.getPtr(syntax_error)) |existing| {
                    existing.* += 1;
                }
                else {
                    try invalid_token_counts.put(syntax_error, 1);
                }
            }
        }

        var score : u64 = 0;
        var iter = invalid_token_counts.iterator();
        while (iter.next()) |x| {
            score += x.key_ptr.*.get_syntax_cost() * @intCast(u64, x.value_ptr.*);
        }

        return score;
    }

    fn cmp(_: void, a: u64, b: u64) bool {
        return a < b;
    }

    pub fn completion_cost(self : Nav) !u64 {
        var completion_scores = std.ArrayList(u64).init(self.allocator);
        var lines_iter = lib.Lines.Iterator.init(self.lines);
        while (lines_iter.next()) |l| {
            var parser = NavParser.init(l, self.allocator);
            if (try parser.get_completion()) |completion| {
                try completion_scores.append(completion.get_cost());
            }
        }

        std.sort.sort(u64, completion_scores.items, {}, cmp);
        return completion_scores.items[completion_scores.items.len / 2];
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var lines = try lib.Lines.from_file(arena.allocator(), std.fs.cwd(), "input.txt");

    var nav = Nav.init(lines, arena.allocator());
    const syntax_cost = try nav.syntax_error_cost();
    std.log.info("Syntax cost {d}", .{syntax_cost});

    const completion_cost = try nav.completion_cost();
    std.log.info("Completion cost {d}", .{completion_cost});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
