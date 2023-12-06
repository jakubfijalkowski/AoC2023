const std = @import("std");
const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const Game = struct {
    times: ArrayList(i64),
    distances: ArrayList(i64),

    fn parseFile(file: std.fs.File, skipSpaces: bool, allocator: Allocator) !Game {
        const stat = try file.stat();
        var orgBuffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(orgBuffer);

        assert(try file.readAll(orgBuffer) == stat.size);

        var buffer = orgBuffer;
        if (skipSpaces) {
            var replaced = std.mem.replace(u8, buffer, " ", "", buffer);
            buffer = buffer[0..(stat.size - replaced)];
        }

        var lines = splitAny(u8, buffer, "\n");
        var times = lines.next().?;
        var distances = lines.next().?;
        return Game{
            .times = try Game.parseNumbers(times, allocator),
            .distances = try Game.parseNumbers(distances, allocator),
        };
    }

    fn parseNumbers(line: []const u8, allocator: Allocator) !ArrayList(i64) {
        var data = splitAny(u8, line, ":");
        _ = data.next().?;
        var result = ArrayList(i64).init(allocator);
        var numbers = splitAny(u8, data.next().?, " ");

        while (numbers.next()) |n| {
            if (n.len > 0) {
                try result.append(try parseInt(i64, n, 10));
            }
        }

        return result;
    }

    pub fn deinit(self: *const Game) void {
        self.times.deinit();
        self.distances.deinit();
    }
};

pub fn play(skipSpaces: bool) !i64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    const game = try Game.parseFile(file, skipSpaces, allocator);
    defer game.deinit();

    var result: i64 = 1;

    var i: usize = 0;
    while (i < game.times.items.len) : (i += 1) {
        const T = @as(f64, @floatFromInt(game.times.items[i]));
        const D = @as(f64, @floatFromInt(game.distances.items[i]));

        const d = std.math.pow(f64, T, 2) - 4 * D;
        const sd = std.math.sqrt(d);
        const x1 = std.math.floor((-T - sd) / (-2) - 0.0001);
        const x2 = std.math.ceil((-T + sd) / (-2) + 0.0001);
        const p = @as(i64, @intFromFloat(x1 - x2)) + 1;
        result *= p;
    }

    return result;
}

pub fn part1() !void {
    var result = try play(false);
    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var result = try play(true);
    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
