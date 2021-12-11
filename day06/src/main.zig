const std = @import("std");

fn RingBuffer(comptime Type : type, comptime Size : usize) type {
    return struct {
        buffer : [Size]Type,
        head_ptr : usize,


        const Self = @This();

        pub fn init(init_value : [Size]Type) Self {
            return Self {
                .buffer = init_value,
                .head_ptr = 0,
            };
        }

        pub fn head(self : Self) Type {
            return self.buffer[self.head_ptr];
        }

        pub fn tail(self : Self) Type {
            const tail_ptr_val = self.tail_offset();
            return self.buffer[tail_ptr_val];
        }

        pub fn push(self : *Self, x: Type) void {
            self.buffer[self.head_ptr] = x;
            self.move_head();
        }

        fn tail_offset(self : Self) usize {
            return @mod(self.head_ptr + 1, Size);
        }

        fn move_head(self: *Self) void {
            self.head_ptr = @mod(self.head_ptr + 1, Size);
        }

        pub fn sum(self : Self) Type {
            var res : Type = 0;
            for (self.buffer) |x| {
                res += x;
            }

            res -= self.head();

            return res;
        }
    };
}

const Simulation = struct {
    adults : RingBuffer(u64, 8),
    children : RingBuffer(u64, 10),

    pub fn init(input : []const usize) Simulation {

        var init_adults = std.mem.zeroes([8]u64);
        for (input) |x| {
            init_adults[x] += 1;
        }

        return .{
            .adults = RingBuffer(u64, 8).init(init_adults),
            .children = RingBuffer(u64, 10).init(std.mem.zeroes([10]u64)),
        };
    }

    pub fn tick(self : *Simulation) void {
        const x = self.adults.tail() + self.children.tail();
        self.adults.push(x);
        self.children.push(x);
    }

    pub fn how_many_fish_in_the_sea(self : Simulation) u64 {
        return self.adults.sum() + self.children.sum();
    }
};

const initial_state = [_]usize { 3,4,3,1,2 };
const initial_state_large = [_]usize {5,1,1,4,1,1,4,1,1,1,1,1,1,1,1,1,1,1,4,2,1,1,1,3,5,1,1,1,5,4,1,1,1,2,2,1,1,1,2,1,1,1,2,5,2,1,2,2,3,1,1,1,1,1,1,1,1,5,1,1,4,1,1,1,5,4,1,1,3,3,2,1,1,1,5,1,1,4,1,1,5,1,1,5,1,2,3,1,5,1,3,2,1,3,1,1,4,1,1,1,1,2,1,2,1,1,2,1,1,1,4,4,1,5,1,1,3,5,1,1,5,1,4,1,1,1,1,1,1,1,1,1,2,2,3,1,1,1,1,1,2,1,1,1,1,1,1,2,1,1,1,5,1,1,1,1,4,1,1,1,1,4,1,1,1,1,3,1,2,1,2,1,3,1,3,4,1,1,1,1,1,1,1,5,1,1,1,1,1,1,1,1,4,1,1,2,2,1,2,4,1,1,3,1,1,1,5,1,3,1,1,1,5,5,1,1,1,1,2,3,4,1,1,1,1,1,1,1,1,1,1,1,1,5,1,4,3,1,1,1,2,1,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,3,3,1,2,2,1,4,1,5,1,5,1,1,1,1,1,1,1,2,1,1,1,1,1,1,1,1,1,1,1,5,1,1,1,4,3,1,1,4};

fn cmp(_: void, a: u64, b: u64) bool {
    return a < b;
}

pub fn get_percentile_ns(times: []const u64, percentage : usize) u64 {
    const index = percentage * (times.len / 100);
    //std.log.info("Indexing at {d}", .{index});
    return times[index];// / 1000;
}

pub fn benchmark() !void {
    var allocator = std.heap.page_allocator;

    const target : usize = 500;
    var iters : usize = 500000;
    var times = try std.ArrayList(u64).initCapacity(allocator, iters);

    while (iters > 0) {
        if (@mod(iters, 100000) == 0) {
            std.log.err("Benchmark iter {d}", .{iters});
        }

        var timer = try std.time.Timer.start();

        std.mem.doNotOptimizeAway(run_basic(target));

        var nanos_duration = timer.read();
        try times.append(nanos_duration);

        iters -= 1;
    }

    std.sort.sort(u64, times.items, {}, cmp);

    std.log.err("BENCHMARK DONE, p50 {d}ns p75 {d}ns p90 {d}ns", .{get_percentile_ns(times.items, 50), get_percentile_ns(times.items, 75), get_percentile_ns(times.items, 90)});
}

pub fn main() anyerror!void {
    try benchmark();
    //try run();
}

pub fn run_basic(target : usize) u64 {
    var i : usize = 0;
    var sim = Simulation.init(initial_state_large[0..]);
    while (i < target)
    {
        sim.tick();
        i += 1;
    }

    return sim.how_many_fish_in_the_sea();
}

pub fn run() anyerror!void {
    std.log.info("Starting", .{});

    const iters = 80;
    const fish = run_basic(iters);

    std.log.info("After {} steps, total = {}", .{iters, fish});
}