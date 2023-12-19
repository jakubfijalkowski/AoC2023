const std = @import("std");
const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const ArrayHashMap = std.ArrayHashMap;
const Allocator = std.mem.Allocator;
const abs = std.math.absCast;

const Field = enum(u8) {
    Rock,
    Rolling,
    Empty,

    fn parse(c: u8) Field {
        return switch (c) {
            '#' => Field.Rock,
            'O' => Field.Rolling,
            else => Field.Empty,
        };
    }

    fn canRollTo(self: Field) bool {
        return self == Field.Empty;
    }

    fn toC(self: Field) u8 {
        return switch (self) {
            Field.Rock => '#',
            Field.Rolling => 'O',
            Field.Empty => '.',
        };
    }
};

const Game = struct {
    width: isize,
    height: isize,
    data: ArrayList(Field),

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);

        var height: isize = 0;
        var width: isize = 0;
        var data = ArrayList(Field).init(allocator);
        var lines = splitAny(u8, buffer, "\n");
        while (lines.next()) |l| {
            for (l, 0..) |c, x| {
                width = @max(width, @as(isize, @intCast(x + 1)));
                try data.append(Field.parse(c));
            }

            height += 1;
        }
        return Game{ .width = width, .height = height, .data = data };
    }

    fn rollNorth(self: *Game) void {
        var y: isize = 0;
        while (y < self.height) : (y += 1) {
            var x: isize = 0;
            while (x < self.width) : (x += 1) {
                if (self.at(x, y) == Field.Rolling) {
                    var to = y - 1;
                    while (to >= 0 and self.at(x, to).canRollTo()) : (to -= 1) {
                        self.set(x, to + 1, Field.Empty);
                        self.set(x, to, Field.Rolling);
                    }
                }
            }
        }
    }

    fn rollSouth(self: *Game) void {
        var y: isize = self.height - 1;
        while (y >= 0) : (y -= 1) {
            var x: isize = 0;
            while (x < self.width) : (x += 1) {
                if (self.at(x, y) == Field.Rolling) {
                    var to = y + 1;
                    while (to < self.height and self.at(x, to).canRollTo()) : (to += 1) {
                        self.set(x, to - 1, Field.Empty);
                        self.set(x, to, Field.Rolling);
                    }
                }
            }
        }
    }

    fn rollEast(self: *Game) void {
        var y: isize = 0;
        while (y < self.height) : (y += 1) {
            var x: isize = self.width - 1;
            while (x >= 0) : (x -= 1) {
                if (self.at(x, y) == Field.Rolling) {
                    var to = x + 1;
                    while (to < self.width and self.at(to, y).canRollTo()) : (to += 1) {
                        self.set(to - 1, y, Field.Empty);
                        self.set(to, y, Field.Rolling);
                    }
                }
            }
        }
    }

    fn rollWest(self: *Game) void {
        var y: isize = 0;
        while (y < self.height) : (y += 1) {
            var x: isize = 0;
            while (x < self.width) : (x += 1) {
                if (self.at(x, y) == Field.Rolling) {
                    var to = x - 1;
                    while (to >= 0 and self.at(to, y).canRollTo()) : (to -= 1) {
                        self.set(to + 1, y, Field.Empty);
                        self.set(to, y, Field.Rolling);
                    }
                }
            }
        }
    }

    fn rollAll(self: *Game) void {
        self.rollNorth();
        self.rollWest();
        self.rollSouth();
        self.rollEast();
    }

    fn sumAll(self: *const Game) isize {
        var result: isize = 0;
        var y: isize = 0;
        while (y < self.height) : (y += 1) {
            var x: isize = 0;
            while (x < self.width) : (x += 1) {
                if (self.at(x, y) == Field.Rolling) {
                    result += self.height - y;
                }
            }
        }
        return result;
    }

    fn at(self: *const Game, x: isize, y: isize) Field {
        var idx = y * self.width + x;
        return self.data.items[@as(usize, @intCast(idx))];
    }

    fn set(self: *const Game, x: isize, y: isize, value: Field) void {
        var idx = y * self.width + x;
        self.data.items[@as(usize, @intCast(idx))] = value;
    }

    fn print(self: *const Game) void {
        var y: isize = 0;
        while (y < self.height) : (y += 1) {
            var x: isize = 0;
            while (x < self.width) : (x += 1) {
                std.debug.print("{c}", .{self.at(x, y).toC()});
            }
            std.debug.print("\n", .{});
        }
    }

    fn deinit(self: *const Game) void {
        self.data.deinit();
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

    game.rollNorth();
    result = game.sumAll();

    std.debug.print("Part 1: {any}\n", .{result});
}

pub fn part2() !void {
    const CacheEntry = struct {
        sum: isize,
        iter: usize,
    };
    const CacheContext = struct {
        pub fn hash(_: @This(), key: []const Field) u32 {
            var h = std.hash.Wyhash.init(0);
            h.update(@as([]const u8, @ptrCast(key)));
            return @truncate(h.final());
        }

        pub fn eql(_: @This(), a: []const Field, b: []const Field, _: usize) bool {
            return std.mem.eql(Field, a, b);
        }
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var game = try Game.parseFile(file, allocator);
    defer game.deinit();

    var result: isize = 0;

    var cache = ArrayHashMap([]const Field, CacheEntry, CacheContext, true).init(allocator);
    defer {
        for (cache.keys()) |k| {
            allocator.free(k);
        }
        cache.deinit();
    }

    const Loops = 1000000000;
    outer: for (1..Loops) |i| {
        game.rollAll();

        var hit = try cache.getOrPut(game.data.items);
        if (hit.found_existing) {
            for (1..Loops) |j| {
                game.rollAll();

                if (std.mem.eql(Field, hit.key_ptr.*, game.data.items)) {
                    var left = (Loops - i) % j;
                    for (0..left) |_| {
                        game.rollAll();
                    }
                    result = game.sumAll();
                    break :outer;
                }
            }
            break;
        } else {
            hit.value_ptr.* = CacheEntry{ .sum = game.sumAll(), .iter = i };
            hit.key_ptr.* = try allocator.dupe(Field, game.data.items);
        }
    }

    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
