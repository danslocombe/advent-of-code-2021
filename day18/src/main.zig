const std = @import("std");
const Allocator = std.mem.Allocator;
const dan_lib = @import("dan_lib");

const SnailNumType = enum {
    snail_lit,
    snail_pair,
};

const SnailPair = struct {
    first : SnailNum,
    second : SnailNum,

    pub fn do_explode(self : *SnailPair, allocator : Allocator) !*SnailNumLit {
        // Assume a pair of literals otherwise would have already exploded.
        var left_ptr = self.*.first.snail_lit.explode_left();
        var right_ptr = self.*.second.snail_lit.explode_right();

        var new = &(try allocator.alloc(SnailNumLit, 1))[0];
        new.*.val = 0;
        new.*.left = left_ptr;
        new.*.right = right_ptr;

        if (left_ptr) |l| {
            l.right = new;
        }

        if (right_ptr) |r| {
            r.left = new;
        }

        return new;
    }
};


const SnailNumLit = struct {
    val : u8,
    left : ?*SnailNumLit, 
    right : ?*SnailNumLit,

    pub fn explode_left(self : *SnailNumLit) ?*SnailNumLit {
        if (self.*.left) |left_ptr| {
            left_ptr.*.val += self.*.val;
        }

        return self.*.left;
    }

    pub fn explode_right(self : *SnailNumLit) ?*SnailNumLit {
        if (self.*.right) |right_ptr| {
            right_ptr.*.val += self.*.val;
        }

        return self.*.right;
    }

    pub fn do_split(self : SnailNumLit, allocator : Allocator) !*SnailPair {
        var alloced = try allocator.alloc(SnailNumLit, 2);
        var new_left = &alloced[0];
        var new_right = &alloced[1];

        new_left.*.val = @divFloor(self.val, 2);
        new_left.*.left = self.left;
        new_left.*.right = new_right;

        new_right.*.val = @divFloor(self.val + 1, 2);
        new_right.*.left = new_left;
        new_right.*.right = self.right;

        if (self.left) |l| {
            l.right = new_left;
        }

        if (self.right) |r| {
            r.left = new_right;
        }

        var new_pair = &(try allocator.alloc(SnailPair, 1))[0];
        new_pair.*.first = SnailNum{.snail_lit = new_left};
        new_pair.*.second = SnailNum{.snail_lit = new_right};

        return new_pair;
    }
};

const SnailNum = union(SnailNumType) {
    snail_lit : *SnailNumLit,
    snail_pair : *SnailPair,

    pub fn explode(self : *SnailNum, allocator : Allocator) anyerror!bool {
        const StackElem = struct {
            ptr : *SnailNum,
            container : ?*SnailPair,
            first : bool,
            depth : usize,
        };

        var stack = try std.ArrayList(StackElem).initCapacity(allocator, 5);
        try stack.append(.{.ptr = self, .first = true, .depth = 0, .container = null});

        while (stack.items.len > 0) {
            //std.log.info("stack iter {d}",.{stack.items.len});
            var cur = stack.pop();
            switch (cur.ptr.*) {
                SnailNumType.snail_lit => {},
                SnailNumType.snail_pair => {
                    var pair = cur.ptr.*.snail_pair;
                    if (cur.depth >= 4) {
                        // Create new element to place back into expression
                        var new_elem = try pair.do_explode(allocator);

                        if (cur.first) {
                            cur.container.?.first = SnailNum {
                                .snail_lit = new_elem,
                            };
                        }
                        else {
                            cur.container.?.second = SnailNum {
                                .snail_lit = new_elem,
                            };
                        }

                        return true;
                    }
                    else {
                        try stack.append(.{.ptr = &pair.*.second, .first = false, .depth = cur.depth + 1, .container = pair});
                        try stack.append(.{.ptr = &pair.*.first, .first = true, .depth = cur.depth + 1, .container = pair});
                    }
                },
            }
        }

        return false;
    }

    pub fn split(self : *SnailNum, allocator : Allocator) !bool {
        const StackElem = struct {
            ptr : *SnailNum,
            container : ?*SnailPair,
            first : bool,
        };

        var stack = try std.ArrayList(StackElem).initCapacity(allocator, 5);
        try stack.append(.{.ptr = self, .first = true, .container = null});

        while (stack.items.len > 0) {
            //std.log.info("stack iter {d}",.{stack.items.len});
            var cur = stack.pop();
            switch (cur.ptr.*) {
                SnailNumType.snail_lit => {
                    const lit = cur.ptr.*.snail_lit.*;
                    if (lit.val > 9) {
                        var new_pair = try lit.do_split(allocator);

                        if (cur.first) {
                            cur.container.?.first = SnailNum {
                                .snail_pair = new_pair,
                            };
                        }
                        else {
                            cur.container.?.second = SnailNum {
                                .snail_pair = new_pair,
                            };
                        }


                        return true;
                    }
                },
                SnailNumType.snail_pair => {
                    var pair = cur.ptr.*.snail_pair;
                    try stack.append(.{.ptr = &pair.*.second, .first = false, .container = pair});
                    try stack.append(.{.ptr = &pair.*.first, .first = true, .container = pair});
                },
            }
        }

        return false;
    }

    pub fn reduce(self : *SnailNum, allocator : Allocator) anyerror!void {
        while (true) {
            //std.log.info("{s}", .{try self.to_string(allocator, true)});
            //std.log.info("{s}", .{try self.to_string(allocator, false)});

            if (try self.explode(allocator)) {
                //std.log.info("Exploded", .{});
                continue;
            }

            if (try self.split(allocator)) {
                //std.log.info("Reduced", .{});
                continue;
            }

            return;
        }
    }

    pub fn get_mag(self : SnailNum) u32 {
        switch (self) {
            SnailNumType.snail_lit => {
                return self.snail_lit.*.val;
            },
            SnailNumType.snail_pair => {
                return 3*self.snail_pair.*.first.get_mag() + 2 * self.snail_pair.*.second.get_mag();
            },
        }
    }

    pub fn get_first_literal(self : SnailNum) *SnailNumLit {
        switch (self) {
            SnailNumType.snail_lit => {
                return self.snail_lit;
            },
            SnailNumType.snail_pair => {
                return get_first_literal(self.snail_pair.*.first);
            },
        }
    }

    pub fn add(self : *SnailNum, allocator : Allocator, other : *SnailNum) !SnailNum{
        var self_ll = self.get_first_literal();
        while (self_ll.right) |r| {
            self_ll = r;
        }

        var self_rightmost_lit = self_ll;
        var other_leftmost_lit = other.get_first_literal();

        self_rightmost_lit.right = other_leftmost_lit;
        other_leftmost_lit.left = self_rightmost_lit;

        var new = &(try allocator.alloc(SnailPair, 1))[0];

        new.*.first = self.*;
        new.*.second = other.*;

        return SnailNum {
            .snail_pair = new,
        };
    }

    pub fn parse_line(allocator : Allocator, cs : []const u8) !?SnailNum {
        var i : usize = 0;
        var prev : ?*SnailNumLit = null;
        return try SnailNum.parse(allocator, cs, &i, &prev);
    }

    pub fn parse(allocator : Allocator, cs : []const u8, cur : *usize, prev : *?*SnailNumLit) anyerror!?SnailNum {
        if (cur.* >= cs.len) {
            return null;
        }

        const top = cs[cur.*];
        cur.* += 1;

        if (is_digit(top)) {
            var lit = &(try allocator.alloc(SnailNumLit, 1))[0];
            lit.*.val = top - '0';
            lit.*.left = prev.*;
            lit.*.right = null;

            if (prev.*) |prev_ptr| {
                prev_ptr.*.right = lit;
            }

            prev.* = lit;

            return SnailNum {
                .snail_lit = lit,
            };
        }
        else {
            var first = try parse(allocator, cs, cur, prev);
            if (first == null) {
                return null;
            }
            // Skip over comma (should return null if this is not valid)
            cur.* += 1;
            var second = try parse(allocator, cs, cur, prev);
            if (second == null) {
                return null;
            }
            // Skip over closing
            cur.* += 1;

            var pair = &(try allocator.alloc(SnailPair, 1))[0];
            pair.*.first = first.?;
            pair.*.second = second.?;

            return SnailNum {
                .snail_pair = pair,
            };
        }
    }

    fn to_string(self : SnailNum, allocator : Allocator, draw_ptrs : bool) anyerror![]const u8 {
        var cs = std.ArrayList(u8).init(allocator);
        switch(self) {
            SnailNumType.snail_lit => {
                const lit = self.snail_lit.*;
                try cs.appendSlice("(");
                if (draw_ptrs) {
                    if (lit.left) |left_ptr| {
                        try cs.append(left_ptr.*.val + '0');
                        try cs.appendSlice(" <- ");
                    }
                }
                try cs.append(lit.val + '0');
                if (draw_ptrs) {
                    if (lit.right) |right_ptr| {
                        try cs.appendSlice(" -> ");
                        try cs.append(right_ptr.*.val + '0');
                    }
                }
                try cs.appendSlice(")");
            },
            SnailNumType.snail_pair => {
                const pair = self.snail_pair.*;
                try cs.appendSlice("[");
                try cs.appendSlice(try pair.first.to_string(allocator, draw_ptrs));
                try cs.appendSlice(",");
                try cs.appendSlice(try pair.second.to_string(allocator, draw_ptrs));
                try cs.appendSlice("]");
            },
        }

        return cs.items;
    }
};


fn is_digit(c : u8) bool {
    return c >= '0' and c <= '9';
}

pub fn test_small() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    //const input = "[[[[[9,8],1],2],3],4]";
    const input = "[[[[7,7],[7,7]],[[8,7],[8,7]]],[[[7,0],[7,7]],9]]";
    var snail_num = (try SnailNum.parse_line(arena.allocator(), input)).?;
    const input_2 = "[[[[4,2],2],6],[8,7]]";
    var snail_num_2 = (try SnailNum.parse_line(arena.allocator(), input_2)).?;

    snail_num = try snail_num.add(arena.allocator(), &snail_num_2);
    try snail_num.reduce(arena.allocator());

    std.log.info("{s}", .{try snail_num.to_string(arena.allocator(), true)});
    std.log.info("{s}", .{try snail_num.to_string(arena.allocator(), false)});
}

pub fn part_one() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var allocator = arena.allocator();
    var lines = try dan_lib.Lines.from_file(allocator, std.fs.cwd(), "input.txt");
    var line_iter = lines.iter();

    var cur : ?SnailNum = null;

    while (line_iter.next()) |line| {
        var parsed = (try SnailNum.parse_line(allocator, line)).?;
        if (cur) |*existing| {
            cur = try existing.add(allocator, &parsed);
        }
        else {
            cur = parsed;
        }

        try cur.?.reduce(allocator);
    }

    const mag = cur.?.get_mag();

    std.log.err("End magnitude {d}", .{mag});
}

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var allocator = arena.allocator();
    var lines = try dan_lib.Lines.from_file(allocator, std.fs.cwd(), "input.txt");

    var largest_mag : u32 = 0;

    for (dan_lib.range(lines.len())) |_, i| {
        for (dan_lib.range(lines.len())) |_, j| {
            if (i == j) {
                continue;
            }

            var parsed_i = try SnailNum.parse_line(allocator, lines.get(i).?);
            var parsed_j = try SnailNum.parse_line(allocator, lines.get(j).?);

            var summed = try parsed_i.?.add(allocator, &parsed_j.?);
            try summed.reduce(allocator);

            const mag = summed.get_mag();
            if (mag > largest_mag) {
                largest_mag = mag;
            }
        }
    }

    std.log.err("Largest mag {d}", .{largest_mag});
}
