const std = @import("std");
const Allocator = std.mem.Allocator;

// Part 1 done on paper.

fn abs(x : anytype) @TypeOf(x) {
    return @maximum(x, -x);
}

fn shift_towards_zero(x : anytype) @TypeOf(x) {
    const shifted = @maximum(abs(x) - 1, 0);
    if (x > 0) {
        return shifted;
    }
    else {
        return -shifted;
    }
}

const Sim = struct {
    x : i32,
    y : i32,
    xvel : i32,
    yvel : i32,

    pub fn init(xvel : i32, yvel : i32) Sim {
        return .{
            .x = 0,
            .y = 0,
            .xvel = xvel,
            .yvel = yvel,
        };
    }

    pub fn tick(self : *Sim) void {
        self.*.x += self.*.xvel;
        self.*.y += self.*.yvel;
        self.*.xvel = shift_towards_zero(self.*.xvel);
        self.*.yvel -= 1;
    }
};

pub fn possible_x_vels(allocator : Allocator, x : i32) !std.ArrayList(i32) {
    var xvels = std.ArrayList(i32).init(allocator);

    var cur = x;
    outer: while (cur > 0) {
        var sim_x : i32 = 0;
        var sim_xvel : i32 = cur;

        while (sim_x < x) {
            if (sim_xvel == 0) {
                // Never gonna get there
                cur -= 1;
                continue :outer;
            }

            sim_x += sim_xvel;
            sim_xvel = shift_towards_zero(sim_xvel);
        }

        if (sim_x == x) {
            try xvels.append(cur);
        }

        cur -= 1;
    }

    return xvels;
}

const Pair = struct {
    x : i32,
    y : i32,
};

pub fn possible_vels(allocator : Allocator, x: i32, y : i32, xvels : []const i32) !std.ArrayList(Pair) {
    var vels = std.ArrayList(Pair).init(allocator);

    for (xvels) |xvel| {
        {
            var try_yvel : i32 = @minimum(-y, y);
            while (try_yvel <= @maximum(-y, y)) {
                var sim = Sim.init(xvel, try_yvel);

                while (sim.y >= y) {
                    sim.tick();

                    if (sim.x == x and sim.y == y) {
                        try vels.append(.{
                            .x = xvel,
                            .y = try_yvel,
                        });
                    }
                }

                try_yvel += 1;
            }
        }
    }

    return vels;
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var vels = std.ArrayList(Pair).init(arena.allocator());

    //const x_min = 20;
    //const x_max = 30;
    //const y_min = -10;
    //const y_max = -5;
    const x_min = 48;
    const x_max = 70;
    const y_min = -189;
    const y_max = -148;

    var xx : i32 = x_min;
    while (xx <= x_max) {
        var xvels = try possible_x_vels(arena.allocator(), xx);

        var yy : i32 = y_min;
        while (yy <= y_max) {
            var to_add = try possible_vels(arena.allocator(), xx, yy, xvels.items);

            for (to_add.items) |v| {
                var add = true;
                for (vels.items) |existing| {
                    if (existing.x == v.x and existing.y == v.y) {
                        add = false;
                        break;
                    }
                }

                if (add) {
                    try vels.append(v);
                    //std.log.info("{any}", .{v});
                    //std.log.info("Added from{d}{d} - {d},{d}", .{xx, yy, v.x, v.y});
                }
            }
            yy += 1;
        }
        xx += 1;
    }

    std.log.info("Distinct : {d}", .{vels.items.len});
}
