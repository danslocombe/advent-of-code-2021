const std = @import("std");
const utils = @import("utils.zig");

pub fn Benchmarks(comptime Args: type, comptime RetType : type) type {
    return struct {
        samples : []const u64,

        fn cmp(_ : void, x : u64, y : u64) bool {
            return x < y;
        }

        const Self = @This();

        pub fn generate(allocator : std.mem.Allocator, args : struct {f : fn (Args) callconv(.Inline) RetType, f_args : Args, iters : usize = 10000}) !Self {
            var samples = try allocator.alloc(u64, args.iters);

            var timer = try std.time.Timer.start();
            std.log.err("Starting benchmark run, {d} iters", .{args.iters});
            for (utils.range(args.iters)) |_, i| {
                timer.reset();
                std.mem.doNotOptimizeAway(args.f(args.f_args));
                samples[i] = timer.read();
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