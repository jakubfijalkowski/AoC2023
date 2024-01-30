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

const Oasis = @import("./oasis.zig");

const Tile = enum {
    starting,
    plot,
    rock,
    fn parse(c: u8) Tile {
        return switch (c) {
            'S' => Tile.starting,
            '.' => Tile.plot,
            '#' => Tile.rock,
            else => unreachable,
        };
    }
};
const Pos = struct {
    x: isize,
    y: isize,
    fn move(self: Pos, x: isize, y: isize) Pos {
        return Pos{ .x = self.x + x, .y = self.y + y };
    }
    fn distTo(self: Pos, other: Pos) u64 {
        return @as(u64, std.math.absCast(self.x - other.x) + std.math.absCast(self.y - other.y));
    }
};

const Plot = struct {
    width: isize,
    height: isize,
    startIdx: isize,
    data: []const Tile,
    allocator: Allocator,

    fn parse(data: []const u8, allocator: Allocator) !Plot {
        var width: isize = 0;
        var height: isize = 0;
        var startIdx: isize = 0;
        var newLines = std.mem.count(u8, data, &[_]u8{'\n'});
        var plot = try allocator.alloc(Tile, data.len - newLines);

        var i: usize = 0;
        for (data) |c| {
            if (c == '\n') {
                height += 1;
            } else {
                if (height == 0) {
                    width += 1;
                }
                plot[i] = Tile.parse(c);
                if (plot[i] == Tile.starting) {
                    startIdx = @intCast(i);
                }
                i += 1;
            }
        }

        return Plot{
            .width = width,
            .height = height + 1,
            .startIdx = startIdx,
            .data = plot,
            .allocator = allocator,
        };
    }

    fn isValid(self: *const Plot, p: Pos) bool {
        return p.x >= 0 and p.y >= 0 and p.x < self.width and p.y < self.height;
    }

    fn idx(self: *const Plot, p: Pos) usize {
        assert(self.isValid(p));
        return @intCast(p.y * self.width + p.x);
    }

    fn wrappingIdx(self: *const Plot, p: Pos) usize {
        const wrapped = Pos{ .x = @mod(p.x, self.width), .y = @mod(p.y, self.height) };
        return self.idx(wrapped);
    }

    fn at(self: *const Plot, p: Pos) Tile {
        return self.data[self.idx(p)];
    }

    fn wrappingAt(self: *const Plot, p: Pos) Tile {
        return self.data[self.wrappingIdx(p)];
    }

    fn startingPos(self: *const Plot) Pos {
        return Pos{ .x = @rem(self.startIdx, self.width), .y = @divTrunc(self.startIdx, self.width) };
    }

    fn deinit(self: *const Plot) void {
        self.allocator.free(self.data);
    }
};

const Walk = struct {
    data: AutoArrayHashMap(Pos, i32),
    maxSteps: i32,
    plot: *const Plot,

    fn new(from: *const Plot, maxSteps: i32, allocator: Allocator) !Walk {
        return Walk{
            .data = AutoArrayHashMap(Pos, i32).init(allocator),
            .maxSteps = maxSteps,
            .plot = from,
        };
    }

    fn stepOn(self: *Walk, s: Step) !bool {
        var entry = try self.data.getOrPut(s.p);
        if (entry.found_existing) {
            return false;
        } else {
            entry.value_ptr.* = s.idx;
            return true;
        }
    }

    fn countSteps(self: *const Walk) u64 {
        var count: u64 = 0;
        const rem = @rem(self.maxSteps, 2);
        for (self.data.values()) |c| {
            if (@rem(c, 2) == rem) {
                count += 1;
            }
        }
        return count;
    }

    fn maxStep(self: *const Walk) u64 {
        var max: u64 = 0;
        for (self.data.values()) |c| {
            max = @max(max, @as(u64, @intCast(c)));
        }
        return max;
    }

    fn filled(self: *const Walk) u64 {
        return @intCast(self.data.count());
    }

    fn minCoords(self: *const Walk) Pos {
        var x: isize = std.math.maxInt(isize);
        var y: isize = std.math.maxInt(isize);
        for (self.data.keys()) |k| {
            x = @min(x, k.x);
            y = @min(y, k.y);
        }
        return .{ .x = x, .y = y };
    }

    fn maxCoords(self: *const Walk) Pos {
        var x: isize = 0;
        var y: isize = 0;
        for (self.data.keys()) |k| {
            x = @max(x, k.x);
            y = @max(y, k.y);
        }
        return .{ .x = x, .y = y };
    }

    fn maxDistanceTo(self: *const Walk, p: Pos) u64 {
        var d: u64 = 0;
        for (self.data.keys()) |k| {
            d = @max(d, k.distTo(p));
        }
        return d;
    }

    fn print(self: *const Walk) void {
        const min = self.minCoords();
        const max = self.maxCoords();
        var y: isize = min.y;
        while (y <= max.y) : (y += 1) {
            var x: isize = min.x;
            while (x <= max.x) : (x += 1) {
                var p = Pos{ .x = x, .y = y };
                if (self.plot.wrappingAt(p) != Tile.rock) {
                    var d = self.data.get(p);
                    if (d == null) {
                        std.debug.print(" ", .{});
                    } else {
                        std.debug.print(":", .{});
                    }
                } else {
                    std.debug.print("#", .{});
                }
            }

            std.debug.print("\n", .{});
        }
    }

    fn deinit(self: *Walk) void {
        self.data.deinit();
    }
};

const Step = struct {
    p: Pos,
    idx: i32,

    fn next(self: Step, x: isize, y: isize) Step {
        return Step{ .p = self.p.move(x, y), .idx = self.idx + 1 };
    }
};

const Game = struct {
    plot: Plot,
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);
        assert(try file.readAll(buffer) == stat.size);

        return Game{
            .plot = try Plot.parse(buffer, allocator),
            .allocator = allocator,
        };
    }

    fn takeAWalk(self: *const Game, maxSteps: i32, canWrap: bool) !Walk {
        var queue = ArrayList(Step).init(self.allocator);
        defer queue.deinit();

        var walk = try Walk.new(&self.plot, maxSteps, self.allocator);

        try queue.append(Step{ .p = self.plot.startingPos(), .idx = 0 });

        while (queue.items.len > 0) {
            const p = queue.orderedRemove(0);
            if ((!canWrap and !self.plot.isValid(p.p)) or p.idx > maxSteps or self.plot.wrappingAt(p.p) == Tile.rock) {
                continue;
            }

            if (try walk.stepOn(p)) {
                try queue.append(p.next(-1, 0));
                try queue.append(p.next(1, 0));
                try queue.append(p.next(0, -1));
                try queue.append(p.next(0, 1));
            }
        }

        return walk;
    }

    fn countWalk(self: *const Game, maxSteps: i32, canWrap: bool) !u64 {
        var walk = try self.takeAWalk(maxSteps, canWrap);
        defer walk.deinit();
        return walk.countSteps();
    }

    fn deinit(self: *Game) void {
        self.plot.deinit();
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

    var walk = try g.takeAWalk(64, false);
    defer walk.deinit();

    std.debug.print("Part 1: {}\n", .{walk.countSteps()});
}

const Stage = struct { count: u64, steps: usize };

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var g = try Game.parseFile(file, allocator);
    defer g.deinit();

    // I failed :( https://www.reddit.com/r/adventofcode/comments/18orn0s/2023_day_21_part_2_links_between_days/
    var seq = try Oasis.OasisSequence.initCapacity(allocator, 202301);
    seq.appendAssumeCapacity(try g.countWalk(65 + 131 * 0, true));
    seq.appendAssumeCapacity(try g.countWalk(65 + 131 * 1, true));
    seq.appendAssumeCapacity(try g.countWalk(65 + 131 * 2, true));
    seq.appendAssumeCapacity(try g.countWalk(65 + 131 * 3, true));
    var triangle = try Oasis.OasisTriangle.build(seq, allocator, 202301);
    defer triangle.deinit();

    var solution: u64 = 0;
    for (0..(202300 - 3)) |_| {
        solution = triangle.appendNext();
    }

    std.debug.print("Part 2: {}\n", .{solution});
}

pub fn main() !void {
    try part1();
    try part2();
}
