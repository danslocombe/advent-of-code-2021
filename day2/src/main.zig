const std = @import("std");
const dan_lib = @import("dan_lib");
const Lines = dan_lib.Lines;
const string_equals = dan_lib.string_equals;
const print = std.debug.print;

const CommandType = enum {
    Forwards,
    Up,
    Down,
};

const Command = struct {
    command_type: CommandType,
    magnitude : u32,

    pub fn parse(s : []const u8) ?Command {
        var splits = std.mem.split(u8, s, " ");

        const command_string = splits.next() orelse "";
        var command_type : ?CommandType = null;
        if (string_equals(command_string, "forward")) {
            command_type = CommandType.Forwards;
        }
        else if (string_equals(command_string, "up")) {
            command_type = CommandType.Up;
        }
        else if (string_equals(command_string, "down")) {
            command_type = CommandType.Down;
        }

        if (command_type == null) {
            return null;
        }

        const mag_string = splits.next() orelse "";
        if (std.fmt.parseUnsigned(u32, mag_string, 10) catch null) |magnitude| {
            return Command{.command_type = command_type.?, .magnitude = magnitude};
        }
        else {
            return null;
        }
    }
};

const Sub = struct {
    x : u32,
    y : u32,

    pub fn init() Sub {
        return .{.x = 0, .y = 0};
    }

    pub fn apply_command(self : *Sub, command : Command) void {
        switch (command.command_type) {
            CommandType.Forwards => {
                self.x += command.magnitude;
            },
            CommandType.Up => {
                self.y -= command.magnitude;
            },
            CommandType.Down => {
                self.y += command.magnitude;
            },
        }
    }
};

const AimingSub = struct {
    x : u32,
    y : u32,
    aim : u32,

    pub fn init() AimingSub {
        return .{.x = 0, .y = 0, .aim = 0};
    }

    pub fn apply_command(self : *AimingSub, command : Command) void {
        switch (command.command_type) {
            CommandType.Forwards => {
                self.x += command.magnitude;
                self.y += self.aim * command.magnitude;
            },
            CommandType.Up => {
                self.aim -= command.magnitude;
            },
            CommandType.Down => {
                self.aim += command.magnitude;
            },
        }
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var allocator = &gpa.allocator;
    var input = try Lines.from_file(allocator, std.fs.cwd(), "day2_input.txt");
    defer(input.deinit(allocator));

    var sub = Sub.init();
    var aimed_sub = AimingSub.init();

    var iter = Lines.Iterator.init(input);
    while (iter.next()) |line| {
        if (Command.parse(line)) |command| {
            sub.apply_command(command);
            aimed_sub.apply_command(command);
        }
    }

    print("Sub is at ({d}, {d}) Product = {d}\n", .{sub.x, sub.y, sub.x*sub.y});
    print("Aimed Sub is at ({d}, {d}) Product = {d}\n", .{aimed_sub.x, aimed_sub.y, aimed_sub.x*aimed_sub.y});
}