const std = @import("std");

const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const indexOf = std.mem.indexOf;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const AutoArrayHashMap = std.AutoArrayHashMap;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

fn AutoArrayHashSet(comptime K: type) type {
    return AutoArrayHashMap(K, void);
}

const Vec2 = struct {
    x: i64,
    y: i64,
};

const Vec2f = struct {
    x: f80,
    y: f80,

    fn same(v: f80) Vec2f {
        return .{ .x = v, .y = v };
    }
};

const Rectangle2f = struct {
    min: Vec2f,
    max: Vec2f,

    fn isInside(self: Rectangle2f, pt: Vec2f) bool {
        return self.min.x <= pt.x and pt.x <= self.max.x and self.min.y <= pt.y and pt.y <= self.max.y;
    }
};

const Vec3 = struct {
    x: i64,
    y: i64,
    z: i64,

    fn parse(data: []const u8) !Vec3 {
        var parts = splitAny(u8, data, ",");
        return Vec3{
            .x = try parseInt(i64, trim(u8, parts.next().?, " "), 10),
            .y = try parseInt(i64, trim(u8, parts.next().?, " "), 10),
            .z = try parseInt(i64, trim(u8, parts.next().?, " "), 10),
        };
    }

    fn toVec2(self: Vec3) Vec2 {
        return .{ .x = self.x, .y = self.y };
    }

    fn toVec2f(self: Vec3) Vec2f {
        return .{ .x = @floatFromInt(self.x), .y = @floatFromInt(self.y) };
    }

    fn add(self: Vec3, other: Vec3) Vec3 {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }
};

const Hailstone = struct {
    position: Vec3,
    velocity: Vec3,

    fn parse(line: []const u8) !Hailstone {
        var parts = splitAny(u8, line, "@");
        return .{
            .position = try Vec3.parse(parts.next().?),
            .velocity = try Vec3.parse(parts.next().?),
        };
    }

    fn intersection2D(self: Hailstone, other: Hailstone) ?Vec2f {
        const p1 = self.position.toVec2f();
        const p2 = self.position.add(self.velocity).toVec2f();
        const p3 = other.position.toVec2f();
        const p4 = other.position.add(other.velocity).toVec2f();

        const denom = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x);
        if (std.math.fabs(denom) < 0.000000001) {
            return null;
        } else {
            return .{
                .x = ((p1.x * p2.y - p1.y * p2.x) * (p3.x - p4.x) - (p1.x - p2.x) * (p3.x * p4.y - p3.y * p4.x)) / denom,
                .y = ((p1.x * p2.y - p1.y * p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x * p4.y - p3.y * p4.x)) / denom,
            };
        }
    }

    fn isInFuture2D(self: *const Hailstone, pt: Vec2f) bool {
        assert(self.velocity.x != 0);
        const steps = (self.position.toVec2f().x - pt.x) / self.velocity.toVec2f().x;
        return steps < 0;
    }
};

const Game = struct {
    stones: ArrayList(Hailstone),
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);
        assert(try file.readAll(buffer) == stat.size);

        var lines = splitAny(u8, buffer, "\n");
        var stones = ArrayList(Hailstone).init(allocator);
        while (lines.next()) |l| {
            try stones.append(try Hailstone.parse(l));
        }
        return Game{
            .stones = stones,
            .allocator = allocator,
        };
    }

    fn calcCollisions(self: *const Game, range: Rectangle2f) usize {
        var result: usize = 0;
        for (0..self.stones.items.len) |i| {
            for (i + 1..self.stones.items.len) |j| {
                const a = self.stones.items[i];
                const b = self.stones.items[j];
                const pt = a.intersection2D(b);
                if (pt != null and a.isInFuture2D(pt.?) and b.isInFuture2D(pt.?) and range.isInside(pt.?)) {
                    result += 1;
                }
            }
        }
        return result;
    }

    fn deinit(self: *Game) void {
        self.stones.deinit();
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var g = try Game.parseFile(file, allocator);
    defer g.deinit();

    const result = g.calcCollisions(
        Rectangle2f{
            .min = Vec2f.same(200000000000000),
            .max = Vec2f.same(400000000000000),
        },
    );

    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    std.debug.print("Part 2: exec `python part2.py`\n", .{});
}

pub fn main() !void {
    try part1();
    try part2();
}
