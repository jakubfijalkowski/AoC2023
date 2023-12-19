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

const GridEntry = enum {
    Empty,
    RMirror,
    LMirror,
    HSplitter,
    VSplitter,

    fn parse(c: u8) ?GridEntry {
        return switch (c) {
            '/' => GridEntry.RMirror,
            '\\' => GridEntry.LMirror,
            '-' => GridEntry.HSplitter,
            '|' => GridEntry.VSplitter,
            else => null,
        };
    }
};

const Direction = enum {
    North,
    East,
    South,
    West,
};

const Pos = struct {
    x: isize,
    y: isize,

    fn isValid(self: Pos, g: *const Game) bool {
        return self.x >= 0 and self.y >= 0 and self.x < g.width and self.y < g.height;
    }

    fn add(self: Pos, x: isize, y: isize) Pos {
        return Pos{ .x = self.x + x, .y = self.y + y };
    }

    fn move(self: Pos, dir: Direction) Pos {
        return switch (dir) {
            Direction.North => self.add(0, -1),
            Direction.East => self.add(1, 0),
            Direction.South => self.add(0, 1),
            Direction.West => self.add(-1, 0),
        };
    }
};

const NextMove = struct {
    p: Pos,
    dir: Direction,
    fn move(self: NextMove) NextMove {
        return NextMove{
            .p = self.p.move(self.dir),
            .dir = self.dir,
        };
    }
    fn redirect(self: NextMove, newDir: Direction) NextMove {
        var nm = NextMove{
            .p = self.p,
            .dir = newDir,
        };
        return nm.move();
    }
};

const Game = struct {
    width: isize,
    height: isize,
    map: AutoHashMap(Pos, GridEntry),

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);

        var map = AutoHashMap(Pos, GridEntry).init(allocator);
        var lines = splitAny(u8, buffer, "\n");

        var width: usize = 0;
        var height: isize = 0;
        while (lines.next()) |l| : (height += 1) {
            for (l, 0..) |c, x| {
                width = @max(width, x + 1);
                var p = GridEntry.parse(c);
                if (p != null) {
                    try map.put(Pos{ .x = @intCast(x), .y = height }, p.?);
                }
            }
        }

        return Game{
            .width = @intCast(width),
            .height = height,
            .map = map,
        };
    }

    fn deinit(self: *Game) void {
        self.map.deinit();
    }
};

const Simulation = struct {
    game: *const Game,
    energized: AutoArrayHashMap(Pos, void),
    movesDone: AutoHashMap(NextMove, void),
    allocator: Allocator,

    fn prepare(game: *const Game, allocator: Allocator) Simulation {
        return Simulation{
            .game = game,
            .energized = AutoArrayHashMap(Pos, void).init(allocator),
            .movesDone = AutoHashMap(NextMove, void).init(allocator),
            .allocator = allocator,
        };
    }

    fn run(self: *Simulation, initialPos: Pos, dir: Direction) !usize {
        var toVisit = try ArrayList(NextMove).initCapacity(self.allocator, 8);
        defer toVisit.deinit();

        toVisit.appendAssumeCapacity(NextMove{ .p = initialPos, .dir = dir });

        while (toVisit.popOrNull()) |m| {
            if (!m.p.isValid(self.game) or self.movesDone.contains(m)) {
                continue;
            }

            try self.energized.put(m.p, {});
            try self.movesDone.put(m, {});

            var field = self.game.map.get(m.p) orelse GridEntry.Empty;
            switch (field) {
                GridEntry.Empty => {
                    toVisit.appendAssumeCapacity(m.move());
                },
                GridEntry.VSplitter => {
                    switch (m.dir) {
                        Direction.West, Direction.East => {
                            toVisit.appendAssumeCapacity(m.redirect(Direction.North));
                            try toVisit.append(m.redirect(Direction.South));
                        },
                        else => {
                            toVisit.appendAssumeCapacity(m.move());
                        },
                    }
                },
                GridEntry.HSplitter => {
                    switch (m.dir) {
                        Direction.North, Direction.South => {
                            toVisit.appendAssumeCapacity(m.redirect(Direction.West));
                            try toVisit.append(m.redirect(Direction.East));
                        },
                        else => {
                            toVisit.appendAssumeCapacity(m.move());
                        },
                    }
                },
                GridEntry.RMirror => {
                    const newDir = switch (m.dir) {
                        Direction.North => Direction.East,
                        Direction.East => Direction.North,
                        Direction.South => Direction.West,
                        Direction.West => Direction.South,
                    };
                    toVisit.appendAssumeCapacity(m.redirect(newDir));
                },
                GridEntry.LMirror => {
                    const newDir = switch (m.dir) {
                        Direction.North => Direction.West,
                        Direction.East => Direction.South,
                        Direction.South => Direction.East,
                        Direction.West => Direction.North,
                    };
                    toVisit.appendAssumeCapacity(m.redirect(newDir));
                },
            }
        }

        return self.energized.unmanaged.entries.len;
    }

    fn deinit(self: *Simulation) void {
        self.energized.deinit();
        self.movesDone.deinit();
    }

    fn simulate(game: *const Game, initial: Pos, dir: Direction, allocator: Allocator) !usize {
        var sim = Simulation.prepare(game, allocator);
        defer sim.deinit();
        return try sim.run(initial, dir);
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

    var sim = Simulation.prepare(&game, allocator);
    defer sim.deinit();
    var result = try sim.run(Pos{ .x = 0, .y = 0 }, Direction.East);

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

    var result: usize = 0;

    for (0..@intCast(game.height)) |y| {
        result = @max(result, try Simulation.simulate(&game, Pos{ .x = 0, .y = @intCast(y) }, Direction.East, allocator));
        result = @max(result, try Simulation.simulate(&game, Pos{ .x = game.width - 1, .y = @intCast(y) }, Direction.West, allocator));
    }

    for (0..@intCast(game.width)) |x| {
        result = @max(result, try Simulation.simulate(&game, Pos{ .x = @intCast(x), .y = 0 }, Direction.South, allocator));
        result = @max(result, try Simulation.simulate(&game, Pos{ .x = @intCast(x), .y = game.height - 1 }, Direction.North, allocator));
    }

    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
