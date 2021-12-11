const std = @import("std");
const dan_lib = @import("dan_lib");
const ByteGrid = dan_lib.utils.ByteGrid;
const Allocator = std.mem.Allocator;

const DumboOctoField = struct {
    grid : ByteGrid,

    pub fn init(grid : ByteGrid, _ : Allocator) DumboOctoField {
        return .{.grid = grid};
    }

    pub fn tick(self : *DumboOctoField) u32 {
        for (self.grid.values) |*val, i| {
            val.* += 1;
            if (val.* == 10) {
                self.flash(i);
            }
        }

        var flashes : u32 = 0;
        for (self.grid.values) |*val| {
            if (val.* > 9) {
                val.* = 0;
                flashes += 1;
            }
        }

        return flashes;
    }

    fn flash(self : *DumboOctoField, i : usize) void {
        const cur_pos = self.grid.i_to_pos(i);
        const adjacent_poses = [_] ByteGrid.Pos {
            .{.x = -1, .y =  -1},
            .{.x = -1, .y =  0},
            .{.x = -1, .y =  1},
            .{.x = 0,  .y = -1},
            .{.x = 0,.y = 1},
            .{.x = 1,.y = -1},
            .{.x = 1,.y = 0},
            .{.x = 1,.y = 1},
        };

        for (adjacent_poses) |delta_pos| {
            if (self.*.grid.pos_to_i(cur_pos.add(delta_pos))) |index| {
                self.*.grid.values[index] += 1;
                if (self.*.grid.values[index] == 10) {
                    // LIttle bit scared of stack overflows
                    self.flash(index);
                }
            }
        }
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var input_file = try std.fs.cwd().openFile("input.txt", .{});
    const grid = try ByteGrid.parse(@TypeOf(input_file), &input_file, arena.allocator());
    var field = DumboOctoField.init(grid, arena.allocator());

    var total_flashes : u32 = 0;
    for (dan_lib.range(10000)) |_, i| {
        const flashes = field.tick();
        total_flashes += flashes;
        std.log.info("{d} Flashes {d}, total {d}", .{i, flashes, total_flashes});

        if (flashes == 100) {
            break;
        }
    }
}
