const std = @import("std");
const splitAny = std.mem.splitAny;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const abs = std.math.absCast;

const Pos = struct {
    y: isize,
    x: isize,
    fn move(self: Pos, y: isize, x: isize) Pos {
        return Pos{
            .y = self.y + y,
            .x = self.x + x,
        };
    }

    fn eq(self: Pos, other: Pos) bool {
        return self.x == other.x and self.y == other.y;
    }

    fn distanceTo(self: Pos, other: Pos) u64 {
        return abs(self.x - other.x) + abs(self.y - other.y);
    }
};

const Universe = struct {
    galaxies: ArrayList(Pos),
    width: isize,
    height: isize,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Universe {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);

        var lines = splitAny(u8, buffer, "\n");
        var galaxies = ArrayList(Pos).init(allocator);
        var width: isize = 0;
        var height: isize = 0;
        var y: isize = 0;
        while (lines.next()) |l| : (y += 1) {
            var x: isize = 0;
            for (l) |c| {
                if (c == '#') {
                    try galaxies.append(Pos{ .x = x, .y = y });
                    width = @max(width, x + 1);
                    height = @max(height, y + 1);
                }
                x += 1;
            }
        }
        return Universe{ .galaxies = galaxies, .width = width, .height = height };
    }

    fn expand(self: *Universe, d: isize) void {
        self.expandHorizontal(d);
        self.expandVertical(d);
    }

    fn expandVertical(self: *Universe, d: isize) void {
        var x = self.width - 1;
        while (x >= 0) : (x -= 1) {
            if (!self.hasAnyVertical(x)) {
                self.expandX(x, d);
            }
        }
    }

    fn expandHorizontal(self: *Universe, d: isize) void {
        var y = self.height - 1;
        while (y >= 0) : (y -= 1) {
            if (!self.hasAnyHorizontal(y)) {
                self.expandY(y, d);
            }
        }
    }

    fn expandX(self: *Universe, minX: isize, d: isize) void {
        for (0..self.galaxies.items.len) |i| {
            if (self.galaxies.items[i].x > minX) {
                self.galaxies.items[i].x += d;
            }
        }
    }

    fn expandY(self: *Universe, minY: isize, d: isize) void {
        for (0..self.galaxies.items.len) |i| {
            if (self.galaxies.items[i].y > minY) {
                self.galaxies.items[i].y += d;
            }
        }
    }

    fn hasAnyVertical(self: *const Universe, x: isize) bool {
        for (self.galaxies.items) |g| {
            if (g.x == x) {
                return true;
            }
        }
        return false;
    }

    fn hasAnyHorizontal(self: *const Universe, y: isize) bool {
        for (self.galaxies.items) |g| {
            if (g.y == y) {
                return true;
            }
        }
        return false;
    }

    fn calculateDistances(self: *const Universe) u64 {
        var result: u64 = 0;
        for (0..self.galaxies.items.len) |a| {
            for (a..self.galaxies.items.len) |b| {
                result += self.galaxies.items[a].distanceTo(self.galaxies.items[b]);
            }
        }
        return result;
    }

    fn deinit(self: *const Universe) void {
        self.galaxies.deinit();
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var universe = try Universe.parseFile(file, allocator);
    defer universe.deinit();

    universe.expand(1);

    var result = universe.calculateDistances();
    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var universe = try Universe.parseFile(file, allocator);
    defer universe.deinit();

    universe.expand(1000000 - 1);

    var result = universe.calculateDistances();
    std.debug.print("Part 1: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
