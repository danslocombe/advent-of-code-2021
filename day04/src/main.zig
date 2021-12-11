const std = @import("std");
const dan_lib = @import("dan_lib");
const Lines = dan_lib.Lines;
const string_equals = dan_lib.string_equals;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const BingoBoard = struct {
    board : [25] u8,
    marked : [25] bool,

    pub fn parse(lines : *Lines.Iterator) ?BingoBoard {
        var parsed_count : u8 = 0;
        var board = BingoBoard {.board = undefined, .marked = std.mem.zeroes([25] bool)};
        while (lines.next()) |line| {
            var line_split = std.mem.split(u8, line, " ");
            while (line_split.next()) |split| {
                const parsed = std.fmt.parseUnsigned(u8, split, 10) catch {
                    continue;
                };

                board.board[@as(usize, parsed_count)] = parsed;
                parsed_count += 1;
            }

            if (parsed_count >= 25) {
                return board;
            }
        }

        return null;
    }

    pub fn mark(self : *BingoBoard, x : u8) bool {
        for (self.board) |board_value, i| {
            if (board_value == x) {
                self.marked[i] = true;
                return true;
            }
        }

        return false;
    }

    fn get_index(x : usize, y : usize) usize {
        return y*5 + x;
    }

    fn won_hoz(self : *BingoBoard) bool {
        for (dan_lib.range(5)) |_, y| {
            var row = true;
            for (dan_lib.range(5)) |_, x| {
                if (!self.marked[get_index(x, y)]) {
                    row = false;
                    break;
                }
            }

            if (row) {
                return true;
            }
        }

        return false;
    }

    fn won_vert(self : *BingoBoard) bool {
        for (dan_lib.range(5)) |_, x| {
            var row = true;
            for (dan_lib.range(5)) |_, y| {
                if (!self.marked[get_index(x, y)]) {
                    row = false;
                    break;
                }
            }

            if (row) {
                return true;
            }
        }

        return false;
    }

    pub fn won(self : *BingoBoard) bool {
        return self.won_hoz() or self.won_vert();
    }

    pub fn get_unmarked_sum(self : BingoBoard) u32 {
        var sum : u32 = 0;

        for (self.marked) |mark_value, i| {
            if (!mark_value) {
                sum += @as(u32, self.board[i]);
            }
        }

        return sum;
    }
};

const BingoGame = struct {
    call_order : std.ArrayList(u8),
    boards : std.ArrayList(BingoBoard),

    pub fn init(call_order : std.ArrayList(u8), boards : std.ArrayList(BingoBoard)) BingoGame {
        return .{.call_order = call_order, .boards = boards};
    }

    pub fn deinit(self : BingoGame) void {
        self.call_order.deinit();
        self.boards.deinit();
    }

    pub fn run(self : BingoGame) void {
        var won_count : u32 = 0;
        for (self.call_order.items) |call, i| {
            //print("Calling {d}\n", .{call});
            for (self.boards.items) |*board, j| {
                if (board.won()) {
                    continue;
                }

                if (board.mark(call)) {
                    //print("Hit on board {d}\n", .{j});
                }

                if (board.won()) {
                    won_count += 1;
                    //const unmarked = board.get_unmarked_sum();
                    //print("WON t={d}, unmarked={d}, product={d}\n", .{i, unmarked, call * unmarked});
                    //return;

                    if (won_count == self.boards.items.len) {
                        const unmarked = board.get_unmarked_sum();
                        print("FINAL WON t={d}, board id = {d}, unmarked={d}, product={d}\n", .{i, j, unmarked, call * unmarked});
                        return;
                    }
                }
            }
        }
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = &gpa.allocator;
    var input = try Lines.from_file(allocator, std.fs.cwd(), "day4_input.txt");
    defer(input.deinit(allocator));

    var call_order = std.ArrayList(u8).init(allocator);
    var splits = std.mem.split(u8, input.get(0).?, ",");
    while (splits.next()) |split| {
        try call_order.append(try std.fmt.parseUnsigned(u8, split, 10));
    }

    var iter = Lines.Iterator.init(input);

    // Skip first
    _ = iter.next();

    var boards = std.ArrayList(BingoBoard).init(allocator);
    while (BingoBoard.parse(&iter)) |board| {
        try boards.append(board);
    }

    const game = BingoGame.init(call_order, boards);
    defer(game.deinit());
    game.run();
}