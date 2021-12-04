const std = @import("std");
const dan_lib = @import("dan_lib");
const Lines = dan_lib.Lines;
const string_equals = dan_lib.string_equals;
const print = std.debug.print;
const Allocator = std.mem.Allocator;

pub fn main() !void {
    //part_one();
    return part_two();
}

fn get_mask(i : usize) u32 {
    const one : u32 = 1;
    return one << @intCast(u5, i);
}

const DiagnosticParser = struct{
    counts : std.ArrayList(u32),
    dimension : usize,
    samples : usize,

    pub fn init(allocator : *Allocator, dimension : usize) !DiagnosticParser {
        var counts = std.ArrayList(u32).init(allocator);
        for (dan_lib.range(dimension)) |_| {
            try counts.append(0);
        }

        return DiagnosticParser{.counts = counts, .dimension = dimension, .samples = 0};
    }

    pub fn deinit(self : *DiagnosticParser) void {
        self.counts.deinit();
    }

    pub fn sample(self : *DiagnosticParser, x : u32) void {
        for (dan_lib.range(self.dimension)) |_, i| {
            if (x & get_mask(i) != 0) {
                self.counts.items[i] += 1;
            }
        }

        self.samples += 1;
    }

    pub fn gamma_rate(self : DiagnosticParser) u32 {
        var gamma : u32 = 0;

        for (dan_lib.range(self.dimension)) |_, i| {
            if (self.counts.items[i] > self.samples / 2) {
                gamma |= get_mask(i);
            }
        }

        return gamma;
    }

    pub fn epsilon_rate(self : DiagnosticParser) u32 {
        const gamma = self.gamma_rate();

        var mask : u32 = 0;
        for (dan_lib.range(self.dimension)) |_, i| {
            mask |= get_mask(i);
        }

        return ~gamma & mask;
    }
};

pub fn part_one() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = &gpa.allocator;
    var input = try Lines.from_file(allocator, std.fs.cwd(), "day3_input.txt");
    defer(input.deinit(allocator));

    // Get the dimension from the length of the first input
    const dimension = input.get(0).?.len;

    var parser = try DiagnosticParser.init(allocator, dimension);
    defer(parser.deinit());

    var iter = Lines.Iterator.init(input);
    while (iter.next()) |line| {
        const diagnostic = try std.fmt.parseInt(u32, line, 2);
        parser.sample(diagnostic);
    }

    const gamma_rate = parser.gamma_rate();
    const epsilon_rate = parser.epsilon_rate();
    print("Gamma rate {b} - {d}\n", .{gamma_rate, gamma_rate});
    print("Epsilon rate {b} - {d}\n", .{epsilon_rate, epsilon_rate});
    print("Product {d}\n", .{gamma_rate * epsilon_rate});
}

const NumberBank = struct {
    xs : std.ArrayList(u32),
    dimension : usize,
    allocator : *Allocator,

    pub fn init(allocator : *Allocator, dimension : usize) !NumberBank {
        var xs = std.ArrayList(u32).init(allocator);
        return NumberBank{.xs = xs, .allocator = allocator, .dimension = dimension};
    }

    pub fn clone(other: NumberBank) !NumberBank {
        var xs = std.ArrayList(u32).init(other.allocator);
        for (other.xs.items) |x| {
            try xs.append(x);
        }

        return NumberBank{.xs = xs, .allocator = other.allocator, .dimension = other.dimension};
    }

    pub fn deinit(self : *NumberBank) void {
        self.xs.deinit();
    }

    pub fn append(self  : *NumberBank, x : u32) !void {
        return self.xs.append(x);
    }

    pub fn filter(self : *NumberBank, bit_id : usize, filter_value : bool) !void {
        var new_xs = std.ArrayList(u32).init(self.allocator);

        for (self.xs.items) |x| {
            if ((x & get_mask(bit_id) != 0) == filter_value) {
                try new_xs.append(x);
            }
        }

        self.xs.deinit();
        self.xs = new_xs;
    }

    pub fn get_majority(self : NumberBank, bit_id : usize) u1 {
        var count : u32 = 0;
        for (self.xs.items) |x| {
            if (x & get_mask(bit_id) != 0) {
                count += 1;
            }
        }

        if (2*count >= self.xs.items.len) {
            return 1;
        }

        return 0;
    }

    pub fn filter_down(self : NumberBank, majority : bool) !u32 {
        var cloned = try self.clone();
        defer(cloned.deinit());

        var cur_bit : usize = 0;

        while (cloned.xs.items.len > 1) {
            const cur_bit_inverted = cloned.dimension - cur_bit - 1;
            const filter_value = cloned.get_majority(cur_bit_inverted);
            try cloned.filter(cur_bit_inverted, majority == (filter_value != 0));
            cur_bit = @mod(cur_bit + 1, cloned.dimension);
        }

        return cloned.xs.items[0];
    }

    pub fn get_oxygen(self : NumberBank) !u32 {
        return filter_down(self, true);
    }

    pub fn get_co2(self : NumberBank) !u32 {
        return filter_down(self, false);
    }
};

pub fn part_two() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = &gpa.allocator;
    var input = try Lines.from_file(allocator, std.fs.cwd(), "day3_input.txt");
    defer(input.deinit(allocator));

    // Get the dimension from the length of the first input
    const dimension = input.get(0).?.len;

    var bank = try NumberBank.init(allocator, dimension);
    defer(bank.deinit());

    var iter = Lines.Iterator.init(input);
    while (iter.next()) |line| {
        try bank.append(try std.fmt.parseInt(u32, line, 2));
    }

    const o2 = try bank.get_oxygen();
    const co2 = try bank.get_co2();
    print("o2 = {d} co2 = {d} product = {d} \n", .{o2, co2, o2*co2});
}
