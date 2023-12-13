const std = @import("std");
const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const abs = std.math.absCast;

const Field = enum {
    Ash,
    Rock,
    Empty,

    fn parse(c: u8) Field {
        return switch (c) {
            '.' => Field.Ash,
            else => Field.Rock,
        };
    }

    fn matches(self: Field, other: Field) bool {
        return self == other or self == Field.Empty or other == Field.Empty;
    }
};

const Pattern = struct {
    width: isize,
    height: isize,
    data: ArrayList(Field),

    fn parse(data: []const u8, allocator: Allocator) !Pattern {
        var result = ArrayList(Field).init(allocator);
        var lines = splitAny(u8, data, "\n");
        var height: isize = 0;
        var width: isize = 0;
        while (lines.next()) |l| {
            for (l, 0..) |c, x| {
                try result.append(Field.parse(c));
                width = @max(width, @as(isize, @intCast(x + 1)));
            }
            height += 1;
        }
        return Pattern{ .data = result, .width = width, .height = height };
    }

    fn summarizeSmudges(self: *const Pattern) isize {
        var result: isize = 0;

        var x: isize = 1;
        while (x < self.width) : (x += 1) {
            if (self.reflectsVertical(x) == 1) {
                result += x;
            }
        }

        var y: isize = 1;
        while (y < self.height) : (y += 1) {
            if (self.reflectsHorizontal(y) == 1) {
                result += y * 100;
            }
        }

        return result;
    }

    fn summarizeNoSmudges(self: *const Pattern) isize {
        var result: isize = 0;

        var x: isize = 1;
        while (x < self.width) : (x += 1) {
            if (self.reflectsVertical(x) == 0) {
                result += x;
            }
        }

        var y: isize = 1;
        while (y < self.height) : (y += 1) {
            if (self.reflectsHorizontal(y) == 0) {
                result += y * 100;
            }
        }

        return result;
    }

    fn reflectsVertical(self: *const Pattern, column: isize) isize {
        var diffs: isize = 0;
        var x1 = column - 1;
        var x2 = column;
        while (x1 >= 0 and x2 < self.width) {
            var y: isize = 0;
            while (y < self.height) : (y += 1) {
                if (!self.at(x1, y).matches(self.at(x2, y))) {
                    diffs += 1;
                }
            }
            x1 -= 1;
            x2 += 1;
        }
        return diffs;
    }

    fn reflectsHorizontal(self: *const Pattern, row: isize) isize {
        var diffs: isize = 0;
        var y1 = row - 1;
        var y2 = row;
        while (y1 >= 0 and y2 < self.height) {
            var x: isize = 0;
            while (x < self.width) : (x += 1) {
                if (!self.at(x, y1).matches(self.at(x, y2))) {
                    diffs += 1;
                }
            }
            y1 -= 1;
            y2 += 1;
        }
        return diffs;
    }

    fn at(self: *const Pattern, x: isize, y: isize) Field {
        if (x >= 0 and x < self.width and y >= 0 and y < self.height) {
            var idx = y * self.width + x;
            return self.data.items[@as(usize, @intCast(idx))];
        } else {
            return Field.Empty;
        }
    }

    fn deinit(self: *const Pattern) void {
        self.data.deinit();
    }
};

const Game = struct {
    patterns: ArrayList(Pattern),

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);

        var lines = splitSequence(u8, buffer, "\n\n");
        var pattern = ArrayList(Pattern).init(allocator);
        while (lines.next()) |l| {
            try pattern.append(try Pattern.parse(l, allocator));
        }
        return Game{ .patterns = pattern };
    }

    fn deinit(self: *const Game) void {
        for (self.patterns.items) |i| {
            i.deinit();
        }
        self.patterns.deinit();
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var game = try Game.parseFile(file, allocator);
    defer game.deinit();

    var result: isize = 0;
    for (game.patterns.items) |p| {
        result += p.summarizeNoSmudges();
    }

    std.debug.print("Part 1: {any}\n", .{result});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var game = try Game.parseFile(file, allocator);
    defer game.deinit();

    var result: isize = 0;
    for (game.patterns.items) |p| {
        result += p.summarizeSmudges();
    }

    std.debug.print("Part 2: {any}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
