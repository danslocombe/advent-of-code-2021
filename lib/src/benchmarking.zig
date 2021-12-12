const std = @import("std");
const utils = @import("utils.zig");

pub fn Benchmarks(comptime Args: type, comptime RetType : type) type {
    return struct {
        samples : []const u64,

        fn cmp(_ : void, x : u64, y : u64) bool {
            return x < y;
        }

        const Self = @This();

        pub fn generate(gpa_allocator : std.mem.Allocator, args : struct {f : fn (std.mem.Allocator, Args) callconv(.Inline) RetType, f_args : Args, iters : usize = 10000}) !Self {
            var samples = try gpa_allocator.alloc(u64, args.iters);

            var timer = try std.time.Timer.start();
            std.log.err("Starting benchmark run, {d} iters", .{args.iters});
            for (utils.range(args.iters)) |_, i| {
                var run_arena = std.heap.ArenaAllocator.init(gpa_allocator);
                timer.reset();
                std.mem.doNotOptimizeAway(args.f(run_arena.allocator(), args.f_args));
                samples[i] = timer.read();
                run_arena.deinit();
            }

            std.sort.sort(u64, samples, void{}, cmp);
            return Self {
                .samples = samples,
            };
        }

        pub fn get_percentile(self : Self, x : usize) u64 {
            const index = (self.samples.len * x) / 100;
            return self.samples[index];
        }

        pub fn print(self : Self) void {
            const percentiles : [4] usize = .{
                50, 75, 90, 95,
            };

            for (percentiles) |p| {
                const percentile = self.get_percentile(p);
                std.log.err("P{d} - {d}us", .{p, percentile / 1000});
            }
        }
    };
}