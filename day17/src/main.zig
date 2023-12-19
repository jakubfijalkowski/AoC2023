const std = @import("std");
const splitAny = std.mem.splitAny;
const indexOf = std.mem.indexOf;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const AutoArrayHashMap = std.AutoArrayHashMap;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;
const PriorityDequeue = std.PriorityDequeue;

const PossibleOffsetsHorizontal = [_]Vertex{
    Vertex{ .x = -3, .y = 0, .dir = Direction.None },
    Vertex{ .x = -2, .y = 0, .dir = Direction.None },
    Vertex{ .x = -1, .y = 0, .dir = Direction.None },
    Vertex{ .x = 3, .y = 0, .dir = Direction.None },
    Vertex{ .x = 2, .y = 0, .dir = Direction.None },
    Vertex{ .x = 1, .y = 0, .dir = Direction.None },
};

const PossibleOffsetsVertical = [_]Vertex{
    Vertex{ .y = -3, .x = 0, .dir = Direction.None },
    Vertex{ .y = -2, .x = 0, .dir = Direction.None },
    Vertex{ .y = -1, .x = 0, .dir = Direction.None },
    Vertex{ .y = 3, .x = 0, .dir = Direction.None },
    Vertex{ .y = 2, .x = 0, .dir = Direction.None },
    Vertex{ .y = 1, .x = 0, .dir = Direction.None },
};

const PossibleOffsetsStart = [_]Vertex{
    Vertex{ .x = 3, .y = 0, .dir = Direction.None },
    Vertex{ .x = 2, .y = 0, .dir = Direction.None },
    Vertex{ .x = 1, .y = 0, .dir = Direction.None },
    Vertex{ .y = 3, .x = 0, .dir = Direction.None },
    Vertex{ .y = 2, .x = 0, .dir = Direction.None },
    Vertex{ .y = 1, .x = 0, .dir = Direction.None },
};

const PossibleOffsetsHorizontalUltra = [_]Vertex{
    Vertex{ .x = 4, .y = 0, .dir = Direction.None },
    Vertex{ .x = 5, .y = 0, .dir = Direction.None },
    Vertex{ .x = 6, .y = 0, .dir = Direction.None },
    Vertex{ .x = 7, .y = 0, .dir = Direction.None },
    Vertex{ .x = 8, .y = 0, .dir = Direction.None },
    Vertex{ .x = 9, .y = 0, .dir = Direction.None },
    Vertex{ .x = 10, .y = 0, .dir = Direction.None },

    Vertex{ .x = -4, .y = 0, .dir = Direction.None },
    Vertex{ .x = -5, .y = 0, .dir = Direction.None },
    Vertex{ .x = -6, .y = 0, .dir = Direction.None },
    Vertex{ .x = -7, .y = 0, .dir = Direction.None },
    Vertex{ .x = -8, .y = 0, .dir = Direction.None },
    Vertex{ .x = -9, .y = 0, .dir = Direction.None },
    Vertex{ .x = -10, .y = 0, .dir = Direction.None },
};

const PossibleOffsetsVerticalUltra = [_]Vertex{
    Vertex{ .y = 4, .x = 0, .dir = Direction.None },
    Vertex{ .y = 5, .x = 0, .dir = Direction.None },
    Vertex{ .y = 6, .x = 0, .dir = Direction.None },
    Vertex{ .y = 7, .x = 0, .dir = Direction.None },
    Vertex{ .y = 8, .x = 0, .dir = Direction.None },
    Vertex{ .y = 9, .x = 0, .dir = Direction.None },
    Vertex{ .y = 10, .x = 0, .dir = Direction.None },

    Vertex{ .y = -4, .x = 0, .dir = Direction.None },
    Vertex{ .y = -5, .x = 0, .dir = Direction.None },
    Vertex{ .y = -6, .x = 0, .dir = Direction.None },
    Vertex{ .y = -7, .x = 0, .dir = Direction.None },
    Vertex{ .y = -8, .x = 0, .dir = Direction.None },
    Vertex{ .y = -9, .x = 0, .dir = Direction.None },
    Vertex{ .y = -10, .x = 0, .dir = Direction.None },
};

const PossibleOffsetsStartUltra = [_]Vertex{
    Vertex{ .x = 4, .y = 0, .dir = Direction.None },
    Vertex{ .x = 5, .y = 0, .dir = Direction.None },
    Vertex{ .x = 6, .y = 0, .dir = Direction.None },
    Vertex{ .x = 7, .y = 0, .dir = Direction.None },
    Vertex{ .x = 8, .y = 0, .dir = Direction.None },
    Vertex{ .x = 9, .y = 0, .dir = Direction.None },
    Vertex{ .x = 10, .y = 0, .dir = Direction.None },

    Vertex{ .y = 4, .x = 0, .dir = Direction.None },
    Vertex{ .y = 5, .x = 0, .dir = Direction.None },
    Vertex{ .y = 6, .x = 0, .dir = Direction.None },
    Vertex{ .y = 7, .x = 0, .dir = Direction.None },
    Vertex{ .y = 8, .x = 0, .dir = Direction.None },
    Vertex{ .y = 9, .x = 0, .dir = Direction.None },
    Vertex{ .y = 10, .x = 0, .dir = Direction.None },
};

const Direction = enum { Horizontal, Vertical, None };

const Vertex = struct {
    dir: Direction,
    x: isize,
    y: isize,

    fn isValid(self: Vertex, g: *const Game) bool {
        return self.x >= 0 and self.y >= 0 and self.x < g.width and self.y < g.height;
    }

    fn offset(self: Vertex, o: Vertex) Vertex {
        return Vertex{
            .dir = if (o.x != 0) Direction.Horizontal else Direction.Vertical,
            .x = self.x + o.x,
            .y = self.y + o.y,
        };
    }

    fn offsets(self: *const Vertex, useUltra: bool) []const Vertex {
        if (useUltra) {
            return switch (self.dir) {
                Direction.None => &PossibleOffsetsStartUltra,
                Direction.Horizontal => &PossibleOffsetsVerticalUltra,
                Direction.Vertical => &PossibleOffsetsHorizontalUltra,
            };
        } else {
            return switch (self.dir) {
                Direction.None => &PossibleOffsetsStart,
                Direction.Horizontal => &PossibleOffsetsVertical,
                Direction.Vertical => &PossibleOffsetsHorizontal,
            };
        }
    }

    fn eq(self: Vertex, other: Vertex) bool {
        return self.x == other.x and self.y == other.y and self.dir == other.dir;
    }

    fn eqPos(self: Vertex, other: Vertex) bool {
        return self.x == other.x and self.y == other.y;
    }
};

const QState = struct {
    vertex: Vertex,
    weight: usize,

    fn make(vertex: Vertex, weight: usize) QState {
        return QState{
            .vertex = vertex,
            .weight = weight,
        };
    }

    fn compare(_: void, a: QState, b: QState) std.math.Order {
        return std.math.order(a.weight, b.weight);
    }
};

const SearchQueue = PriorityDequeue(QState, void, QState.compare);

const SearchState = struct {
    game: *const Game,
    distances: []u64,
    allocator: Allocator,

    fn make(game: *const Game, allocator: Allocator) !SearchState {
        var distances = try allocator.alloc(u64, @intCast(game.width * game.height * 2));
        @memset(distances, std.math.maxInt(u64));
        return SearchState{
            .game = game,
            .distances = distances,
            .allocator = allocator,
        };
    }

    fn index(self: *const SearchState, v: Vertex) usize {
        std.debug.assert(v.isValid(self.game));

        var z: isize = if (v.dir == Direction.Horizontal) 1 else 0;
        var idx = v.x + self.game.width * (v.y + self.game.height * z);
        return @intCast(idx);
    }

    fn setAt(self: *SearchState, from: Vertex, to: Vertex, dist: u64) void {
        std.debug.assert(from.isValid(self.game));
        std.debug.assert(to.isValid(self.game));

        var idx = self.index(to);
        self.distances[idx] = dist;
    }

    fn distAt(self: *SearchState, v: Vertex) u64 {
        std.debug.assert(v.isValid(self.game));

        return self.distances[self.index(v)];
    }

    fn prevAt(self: *SearchState, v: Vertex) Vertex {
        std.debug.assert(v.isValid(self.game));

        return self.previous[self.index(v)].?;
    }

    fn deinit(self: *const SearchState) void {
        self.allocator.free(self.distances);
    }
};

const Game = struct {
    width: isize,
    height: isize,
    map: []const u8,
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));

        assert(try file.readAll(buffer) == stat.size);
        var width: isize = 0;
        var height: isize = 0;
        for (buffer) |*c| {
            if (c.* == '\n') {
                c.* = 255;
                height += 1;
            } else {
                c.* -= '0';
                if (height == 0) {
                    width += 1;
                }
            }
        }

        return Game{
            .width = width,
            .height = height + 1,
            .map = buffer,
            .allocator = allocator,
        };
    }

    fn at(self: *const Game, v: Vertex) u8 {
        std.debug.assert(v.isValid(self));

        var idx = v.y * (self.width + 1) + v.x;
        return self.map[@intCast(idx)];
    }

    fn findPath(self: *const Game, useUltra: bool) !u64 {
        const source = Vertex{ .x = 0, .y = 0, .dir = Direction.None };
        const target1 = Vertex{ .x = self.width - 1, .y = self.height - 1, .dir = Direction.Horizontal };
        const target2 = Vertex{ .x = self.width - 1, .y = self.height - 1, .dir = Direction.Vertical };

        var state = try SearchState.make(self, self.allocator);
        defer state.deinit();

        state.setAt(source, source, 0);

        var queue = SearchQueue.init(self.allocator, {});
        defer queue.deinit();

        try queue.add(QState.make(source, 0));

        while (queue.removeMinOrNull()) |e| {
            const u = e.vertex;

            // We've seen shorter path here, skip it
            if (state.distAt(u) < e.weight) {
                continue;
            }

            for (u.offsets(useUltra)) |o| {
                var v = u.offset(o);

                if (!v.isValid(self)) {
                    continue;
                }

                var alt = state.distAt(u) + self.calcDist(u, v);
                if (alt < state.distAt(v)) {
                    state.setAt(u, v, alt);
                    var newQ = QState.make(v, alt);
                    try queue.add(newQ);
                }
            }
        }

        return @min(state.distAt(target1), state.distAt(target2));
    }

    fn calcDist(self: *const Game, from: Vertex, to: Vertex) u64 {
        var result: u64 = 0;
        var ox = std.math.clamp(to.x - from.x, -1, 1);
        var oy = std.math.clamp(to.y - from.y, -1, 1);
        var current = from;
        while (!current.eqPos(to)) {
            current.x += ox;
            current.y += oy;
            result += self.at(current);
        }
        return result;
    }

    fn estimate(self: *const Game, v: Vertex) u64 {
        return self.width - 1 - v.x + self.height - 1 - v.y;
    }

    fn deinit(self: *Game) void {
        self.allocator.free(self.map);
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

    var result = try game.findPath(false);

    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var game = try Game.parseFile(file, allocator);
    defer game.deinit();

    var result = try game.findPath(true);

    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
