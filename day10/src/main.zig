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
};

const PosPair = struct {
    a: Pos,
    b: Pos,

    fn mk(a: Pos, b: Pos) PosPair {
        return PosPair{ .a = a, .b = b };
    }
};

const Field = enum {
    Vertical,
    Horizontal,
    NorthEast,
    NorthWest,
    SouthWest,
    SouthEast,
    Ground,
    Start,

    fn parse(c: u8) Field {
        return switch (c) {
            '|' => Field.Vertical,
            '-' => Field.Horizontal,
            'L' => Field.NorthEast,
            'J' => Field.NorthWest,
            '7' => Field.SouthWest,
            'F' => Field.SouthEast,
            'S' => Field.Start,
            else => Field.Ground,
        };
    }

    fn canEnter(self: Field, prev: Pos, curr: Pos) bool {
        return switch (self) {
            Field.Vertical => abs(curr.y - prev.y) == 1 and abs(curr.x - prev.x) == 0,
            Field.Horizontal => abs(curr.y - prev.y) == 0 and abs(curr.x - prev.x) == 1,
            Field.NorthEast => prev.eq(curr.move(-1, 0)) or prev.eq(curr.move(0, 1)),
            Field.NorthWest => prev.eq(curr.move(-1, 0)) or prev.eq(curr.move(0, -1)),
            Field.SouthWest => prev.eq(curr.move(1, 0)) or prev.eq(curr.move(0, -1)),
            Field.SouthEast => prev.eq(curr.move(1, 0)) or prev.eq(curr.move(0, 1)),
            else => false,
        };
    }

    fn next(self: Field, prev: Pos, curr: Pos) Pos {
        assert(self.canEnter(prev, curr));
        return switch (self) {
            Field.Vertical => curr.move(curr.y - prev.y, 0),
            Field.Horizontal => curr.move(0, curr.x - prev.x),
            Field.NorthEast => if (prev.eq(curr.move(-1, 0))) curr.move(0, 1) else curr.move(-1, 0),
            Field.NorthWest => if (prev.eq(curr.move(-1, 0))) curr.move(0, -1) else curr.move(-1, 0),
            Field.SouthWest => if (prev.eq(curr.move(1, 0))) curr.move(0, -1) else curr.move(1, 0),
            Field.SouthEast => if (prev.eq(curr.move(1, 0))) curr.move(0, 1) else curr.move(1, 0),
            else => unreachable,
        };
    }
};

const Line = ArrayList(Field);

const Distances = struct {
    width: usize,
    height: usize,
    dists: []i32,
    allocator: Allocator,

    fn make(maze: *const Maze, allocator: Allocator) !Distances {
        var height = maze.map.items.len;
        var width = maze.map.items[0].items.len;
        var dists = try allocator.alloc(i32, width * height);
        @memset(dists, -1);
        return Distances{
            .width = width,
            .height = height,
            .dists = dists,
            .allocator = allocator,
        };
    }

    fn update(self: *Distances, p: Pos, d: i32) i32 {
        var idx = @as(usize, @intCast(p.y)) * self.height + @as(usize, @intCast(p.x));
        if (self.dists[idx] == -1) {
            self.dists[idx] = d;
            return d;
        } else {
            var new_elem = @min(self.dists[idx], d);
            self.dists[idx] = new_elem;
            return new_elem;
        }
    }

    fn deinit(self: *const Distances) void {
        self.allocator.free(self.dists);
    }
};

const Maze = struct {
    map: ArrayList(Line),

    fn parseFile(file: std.fs.File, allocator: Allocator) !Maze {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);

        var lines = splitAny(u8, buffer, "\n");
        var maps = ArrayList(Line).init(allocator);
        while (lines.next()) |l| {
            var seq = Line.init(allocator);
            for (l) |c| {
                try seq.append(Field.parse(c));
            }
            try maps.append(seq);
        }
        return Maze{
            .map = maps,
        };
    }

    fn at(self: *const Maze, p: Pos) Field {
        if (p.y >= 0 and p.y < self.map.items.len) {
            var line = self.map.items[@as(usize, @intCast(p.y))];
            if (p.x >= 0 and p.x < line.items.len) {
                return line.items[@as(usize, @intCast(p.x))];
            }
        }
        return Field.Ground;
    }

    fn replace(self: *Maze, p: Pos, n: Field) void {
        self.map.items[@as(usize, @intCast(p.y))].items[@as(usize, @intCast(p.x))] = n;
    }

    fn findStart(self: *const Maze) Pos {
        for (0..self.map.items.len) |y| {
            for (0..self.map.items[y].items.len) |x| {
                const p = Pos{ .y = @as(isize, @intCast(y)), .x = @as(isize, @intCast(x)) };
                if (self.at(p) == Field.Start) {
                    return p;
                }
            }
        }
        unreachable;
    }

    fn replaceStart(self: *Maze, p: Pos) PosPair {
        if (self.tryPair(p.move(0, -1), p.move(0, 1), p)) {
            self.replace(p, Field.Vertical);
            return PosPair.mk(p.move(0, -1), p.move(0, 1));
        } else if (self.tryPair(p.move(-1, 0), p.move(1, 0), p)) {
            self.replace(p, Field.Horizontal);
            return PosPair.mk(p.move(-1, 0), p.move(1, 0));
        } else if (self.tryPair(p.move(-1, 0), p.move(0, 1), p)) {
            self.replace(p, Field.NorthEast);
            return PosPair.mk(p.move(-1, 0), p.move(0, 1));
        } else if (self.tryPair(p.move(-1, 0), p.move(0, -1), p)) {
            self.replace(p, Field.NorthWest);
            return PosPair.mk(p.move(-1, 0), p.move(0, -1));
        } else if (self.tryPair(p.move(1, 0), p.move(0, -1), p)) {
            self.replace(p, Field.SouthWest);
            return PosPair.mk(p.move(1, 0), p.move(0, -1));
        } else if (self.tryPair(p.move(1, 0), p.move(0, 1), p)) {
            self.replace(p, Field.SouthEast);
            return PosPair.mk(p.move(1, 0), p.move(0, 1));
        } else {
            unreachable;
        }
    }
    fn tryPair(self: *const Maze, a: Pos, b: Pos, p: Pos) bool {
        return self.at(a).canEnter(p, a) and self.at(b).canEnter(p, b);
    }

    fn deinit(self: *const Maze) void {
        for (self.map.items) |s| {
            s.deinit();
        }
        self.map.deinit();
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();
    var maze = try Maze.parseFile(file, allocator);
    defer maze.deinit();

    var dists = try Distances.make(&maze, allocator);
    defer dists.deinit();

    const start = maze.findStart();
    var curr = PosPair.mk(start, start);
    var next = maze.replaceStart(start);

    var result: i32 = 0;
    var i: i32 = 0;
    while (!next.a.eq(start) and !next.b.eq(start)) : (i += 1) {
        result = @max(dists.update(curr.a, i), result);
        result = @max(dists.update(curr.b, i), result);

        var newNext = PosPair.mk(maze.at(next.a).next(curr.a, next.a), maze.at(next.b).next(curr.b, next.b));
        curr = next;
        next = newNext;
    }

    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {}

pub fn main() !void {
    try part1();
    try part2();
}
