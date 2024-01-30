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
    x: isize,
    y: isize,

    fn make(x: isize, y: isize) Vec2 {
        return .{ .x = x, .y = y };
    }

    fn add(self: Vec2, x: isize, y: isize) Vec2 {
        return .{ .x = self.x + x, .y = self.y + y };
    }

    fn eq(self: Vec2, other: Vec2) bool {
        return self.x == other.x and self.y == other.y;
    }
};

const Edge = struct {
    target: Vec2,
    weight: isize,

    fn make(t: Vec2, w: isize) Edge {
        return .{ .target = t, .weight = w };
    }
};

const Vertex = struct {
    pos: Vec2,
    edges: ArrayList(Edge),

    fn new(p: Vec2, allocator: Allocator) Vertex {
        return .{
            .pos = p,
            .edges = ArrayList(Edge).init(allocator),
        };
    }

    fn deinit(self: *const Vertex) void {
        self.edges.deinit();
    }
};

const Map = struct {
    width: isize,
    height: isize,
    data: []u8,

    fn parse(data: []u8) Map {
        const height = std.mem.count(u8, data, "\n") + 1;
        const width = std.mem.indexOf(u8, data, "\n").?;
        return .{
            .width = @intCast(width),
            .height = @intCast(height),
            .data = data,
        };
    }

    fn isValid(self: *const Map, p: Vec2) bool {
        return p.x >= 0 and p.x < self.width and p.y >= 0 and p.y < self.height;
    }

    fn idx(self: *const Map, p: Vec2) usize {
        assert(self.isValid(p));
        return @intCast(p.y * (self.width + 1) + p.x);
    }

    fn at(self: *const Map, p: Vec2) u8 {
        if (!self.isValid(p)) {
            return '#';
        } else {
            return self.data[self.idx(p)];
        }
    }

    fn canEnter(self: *const Map, from: Vec2, to: Vec2, prev: Vec2) bool {
        return switch (self.at(to)) {
            '.' => !to.eq(prev),
            '>' => to.x - from.x != -1,
            '<' => to.x - from.x != 1,
            '^' => to.y - from.y != 1,
            'v' => to.y - from.y != -1,
            else => false,
        };
    }

    fn next(self: *const Map, prev: Vec2, curr: Vec2, possibilities: *ArrayList(Vec2)) void {
        if (self.at(curr) == '.') {
            if (self.canEnter(curr, curr.add(-1, 0), prev)) {
                possibilities.appendAssumeCapacity(curr.add(-1, 0));
            }

            if (self.canEnter(curr, curr.add(1, 0), prev)) {
                possibilities.appendAssumeCapacity(curr.add(1, 0));
            }

            if (self.canEnter(curr, curr.add(0, 1), prev)) {
                possibilities.appendAssumeCapacity(curr.add(0, 1));
            }

            if (self.canEnter(curr, curr.add(0, -1), prev)) {
                possibilities.appendAssumeCapacity(curr.add(0, -1));
            }
        } else {
            switch (self.at(curr)) {
                '>' => possibilities.appendAssumeCapacity(curr.add(1, 0)),
                '<' => possibilities.appendAssumeCapacity(curr.add(-1, 0)),
                '^' => possibilities.appendAssumeCapacity(curr.add(0, -1)),
                'v' => possibilities.appendAssumeCapacity(curr.add(0, 1)),
                else => unreachable,
            }
        }
    }

    fn removeSlopes(self: *Map) void {
        std.mem.replaceScalar(u8, self.data, '<', '.');
        std.mem.replaceScalar(u8, self.data, '>', '.');
        std.mem.replaceScalar(u8, self.data, '^', '.');
        std.mem.replaceScalar(u8, self.data, 'v', '.');
    }
};

const Game = struct {
    map: Map,
    start: Vec2,
    end: Vec2,

    graph: AutoArrayHashMap(Vec2, Vertex),

    buffer: []const u8,
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        assert(try file.readAll(buffer) == stat.size);

        var map = Map.parse(buffer);

        return Game{
            .map = map,
            .start = Vec2.make(1, 0),
            .end = Vec2.make(map.width - 2, map.height - 1),
            .graph = AutoArrayHashMap(Vec2, Vertex).init(allocator),
            .buffer = buffer,
            .allocator = allocator,
        };
    }

    fn removeSlopes(self: *Game) void {
        self.map.removeSlopes();
    }

    fn findLongestPath(self: *const Game) !usize {
        var visited = AutoArrayHashSet(Vec2).init(self.allocator);
        defer visited.deinit();

        return try self.findPath(&visited, Vec2{ .x = 1, .y = -1 }, Vec2{ .x = 1, .y = 0 });
    }

    fn findPath(self: *const Game, visited: *AutoArrayHashSet(Vec2), _prev: Vec2, _curr: Vec2) !usize {
        // Assumption - the "exit" does not look like this:
        // #.###
        // #..v#
        // ###.#

        var curr = _curr;
        var prev = _prev;

        var possibilities = try ArrayList(Vec2).initCapacity(self.allocator, 3);
        defer possibilities.deinit();
        while (!curr.eq(self.end)) {
            if (visited.contains(curr)) {
                return 0;
            }
            try visited.put(curr, {});

            self.map.next(prev, curr, &possibilities);
            if (possibilities.items.len == 1) {
                prev = curr;
                curr = possibilities.pop();
            } else {
                const savedLen = visited.count();
                var maxPath: usize = 0;

                for (possibilities.items) |p| {
                    const nextLen = try self.findPath(visited, curr, p);
                    maxPath = @max(maxPath, nextLen);
                    visited.shrinkRetainingCapacity(savedLen);
                }

                return maxPath;
            }
        }

        return visited.count();
    }

    fn buildGraph(self: *Game) !void {
        const Entry = struct { curr: Vec2, prev: Vec2, lastCrossroad: Vec2, distance: isize };

        var visited = AutoArrayHashSet(Vec2).init(self.allocator);
        defer visited.deinit();

        var toVisit = try ArrayList(Entry).initCapacity(self.allocator, 4);
        defer toVisit.deinit();

        var possibilities = try ArrayList(Vec2).initCapacity(self.allocator, 3);
        defer possibilities.deinit();

        try toVisit.append(.{ .curr = self.start, .prev = self.start, .lastCrossroad = self.start, .distance = 0 });
        try self.graph.put(self.start, Vertex.new(self.start, self.allocator));

        while (toVisit.popOrNull()) |e| {
            if (visited.contains(e.curr)) {
                continue;
            }

            try visited.put(e.curr, {});

            possibilities.clearRetainingCapacity();
            self.map.next(e.prev, e.curr, &possibilities);

            var lastCrossroad = e.lastCrossroad;
            var distance = e.distance;
            if (e.curr.eq(self.end) or possibilities.items.len > 1) {
                var entry = try self.graph.getOrPut(e.curr);
                if (!entry.found_existing) {
                    entry.value_ptr.* = Vertex.new(e.curr, self.allocator);
                }

                try self.graph.getPtr(e.lastCrossroad).?.edges.append(Edge.make(e.curr, e.distance));
                try entry.value_ptr.edges.append(Edge.make(e.lastCrossroad, e.distance));
                lastCrossroad = e.curr;
                distance = 0;

                _ = visited.swapRemove(e.curr);
            }

            if (!e.curr.eq(self.end)) {
                for (possibilities.items) |p| {
                    try toVisit.append(.{ .curr = p, .prev = e.curr, .lastCrossroad = lastCrossroad, .distance = distance + 1 });
                }
            }
        }
    }

    fn findLongestPathGraph(self: *Game) !isize {
        var longest: isize = 0;
        var visited = AutoArrayHashSet(Vec2).init(self.allocator);
        defer visited.deinit();
        try self.findLongestPathGraphFrom(self.start, &visited, 0, &longest);
        return longest;
    }

    fn findLongestPathGraphFrom(self: *Game, p: Vec2, visited: *AutoArrayHashSet(Vec2), currDistance: isize, longest: *isize) !void {
        if (visited.contains(p)) {
            return;
        }

        if (self.end.eq(p)) {
            longest.* = @max(longest.*, currDistance);
        } else {
            try visited.put(p, {});

            const vertex = self.graph.getPtr(p).?;
            for (vertex.edges.items) |e| {
                try self.findLongestPathGraphFrom(e.target, visited, currDistance + e.weight, longest);
            }

            _ = visited.swapRemove(p);
        }
    }

    fn deinit(self: *Game) void {
        self.allocator.free(self.buffer);

        for (self.graph.values()) |k| {
            k.edges.deinit();
        }
        self.graph.deinit();
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

    std.debug.print("Part 1: {}\n", .{try g.findLongestPath()});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var g = try Game.parseFile(file, allocator);
    defer g.deinit();

    g.removeSlopes();
    try g.buildGraph();

    std.debug.print("Part 2: {}\n", .{try g.findLongestPathGraph()});
}

pub fn main() !void {
    try part1();
    try part2();
}
