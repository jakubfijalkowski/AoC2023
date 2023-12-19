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

const Direction = enum {
    Up,
    Right,
    Down,
    Left,
    fn parse(c: u8) Direction {
        return switch (c) {
            'U' => Direction.Up,
            'R' => Direction.Right,
            'D' => Direction.Down,
            'L' => Direction.Left,
            '0' => Direction.Right,
            '1' => Direction.Down,
            '2' => Direction.Left,
            else => Direction.Up,
        };
    }
};

const Instruction = struct {
    dir: Direction,
    len: isize,

    fn parse(line: []const u8, fromColor: bool) !Instruction {
        var openParen = std.mem.indexOf(u8, line, "(").?;

        if (fromColor) {
            var len = try parseInt(u32, line[(openParen + 2)..(line.len - 2)], 16);
            var dir = Direction.parse(line[line.len - 2]);
            return Instruction{
                .dir = dir,
                .len = len,
            };
        } else {
            var dir = Direction.parse(line[0]);
            var len = try parseInt(isize, line[2..(openParen - 1)], 10);
            return Instruction{
                .dir = dir,
                .len = len,
            };
        }
    }
};

const Pos = struct {
    x: isize,
    y: isize,

    fn mk(x: isize, y: isize) Pos {
        return Pos{ .x = x, .y = y };
    }

    fn offset(self: Pos, x: isize, y: isize) Pos {
        return Pos{ .x = self.x + x, .y = self.y + y };
    }

    fn move(self: Pos, dir: Direction) Pos {
        return switch (dir) {
            Direction.Up => self.offset(0, -1),
            Direction.Right => self.offset(1, 0),
            Direction.Down => self.offset(0, 1),
            Direction.Left => self.offset(-1, 0),
        };
    }

    fn moveBy(self: Pos, dir: Direction, len: isize) Pos {
        return switch (dir) {
            Direction.Up => self.offset(0, -len),
            Direction.Right => self.offset(len, 0),
            Direction.Down => self.offset(0, len),
            Direction.Left => self.offset(-len, 0),
        };
    }
};

const Instructions = struct {
    instructions: ArrayList(Instruction),

    fn parseFile(fromColor: bool, file: std.fs.File, allocator: Allocator) !Instructions {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);

        var instr = ArrayList(Instruction).init(allocator);

        var lines = splitAny(u8, buffer, "\n");
        while (lines.next()) |l| {
            try instr.append(try Instruction.parse(l, fromColor));
        }

        return Instructions{
            .instructions = instr,
        };
    }

    fn deinit(self: *Instructions) void {
        self.instructions.deinit();
    }
};

const Map = struct {
    minX: isize,
    minY: isize,
    maxX: isize,
    maxY: isize,
    map: AutoArrayHashMap(Pos, void),

    fn paint(instr: *const Instructions, allocator: Allocator) !Map {
        var map = AutoArrayHashMap(Pos, void).init(allocator);

        var minX: isize = std.math.maxInt(isize);
        var maxX: isize = std.math.minInt(isize);
        var minY: isize = std.math.maxInt(isize);
        var maxY: isize = std.math.minInt(isize);

        var curr = Pos.mk(0, 0);

        for (instr.instructions.items) |i| {
            var left = i.len;
            while (left > 0) : (left -= 1) {
                try map.put(curr, {});
                curr = curr.move(i.dir);
            }

            minX = @min(minX, curr.x);
            maxX = @max(maxX, curr.x);
            minY = @min(minY, curr.y);
            maxY = @max(maxY, curr.y);
        }

        return Map{
            .minX = minX,
            .minY = minY,
            .maxX = maxX,
            .maxY = maxY,
            .map = map,
        };
    }

    fn findStart(self: *const Map) Pos {
        // Nasty assumption - on the first line, the lake will look (at the leftmost side) like this:
        // ###
        // #.#
        // I.e. there will be this U-shape that connects to the rest of the lake. It will fail if it looks like this:
        // ##
        // ##
        var x = self.minX;
        while (x <= self.maxX) : (x += 1) {
            if (self.map.contains(Pos.mk(x, self.minY))) {
                return Pos.mk(x + 1, self.minY + 1);
            }
        }

        unreachable;
    }

    fn fillTheLake(self: *Map, allocator: Allocator) !void {
        var toCheck = try ArrayList(Pos).initCapacity(allocator, 128);
        defer toCheck.deinit();

        toCheck.appendAssumeCapacity(self.findStart());

        while (toCheck.popOrNull()) |l| {
            try self.map.put(l, {});

            if (!self.map.contains(l.offset(-1, 0))) {
                try toCheck.append(l.offset(-1, 0));
            }
            if (!self.map.contains(l.offset(1, 0))) {
                try toCheck.append(l.offset(1, 0));
            }
            if (!self.map.contains(l.offset(0, -1))) {
                try toCheck.append(l.offset(0, -1));
            }
            if (!self.map.contains(l.offset(0, 1))) {
                try toCheck.append(l.offset(0, 1));
            }
        }
    }

    fn print(self: *const Map) void {
        var y = self.minY;
        while (y <= self.maxY) : (y += 1) {
            var x = self.minX;
            while (x <= self.maxX) : (x += 1) {
                if (self.map.contains(Pos.mk(x, y))) {
                    std.debug.print("#", .{});
                } else {
                    std.debug.print(".", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }

    fn deinit(self: *Map) void {
        self.map.deinit();
    }
};

const Polygon = struct {
    vertices: ArrayList(Pos),
    totalLen: isize,

    fn build(instr: *const Instructions, allocator: Allocator) !Polygon {
        var vertices = try ArrayList(Pos).initCapacity(allocator, instr.instructions.items.len);

        var curr = Pos.mk(0, 0);
        var totalLen: isize = 0;

        for (instr.instructions.items) |i| {
            curr = curr.moveBy(i.dir, i.len);
            vertices.appendAssumeCapacity(curr);
            totalLen += i.len;
        }

        return Polygon{
            .vertices = vertices,
            .totalLen = totalLen,
        };
    }

    fn area(self: *const Polygon) u64 {
        var sum: i64 = 0;
        for (1..(self.vertices.items.len + 1)) |i| {
            var v1 = self.vertices.items[i - 1];
            var v2 = self.vertices.items[i % self.vertices.items.len];

            sum += v1.x * v2.y - v1.y * v2.x;
        }
        return std.math.absCast(@divTrunc(sum + self.totalLen, 2)) + 1;
    }

    fn deinit(self: *Polygon) void {
        self.vertices.deinit();
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var instr = try Instructions.parseFile(false, file, allocator);
    defer instr.deinit();

    var map = try Map.paint(&instr, allocator);
    defer map.deinit();

    try map.fillTheLake(allocator);

    std.debug.print("Part 1: {}\n", .{map.map.count()});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var instr = try Instructions.parseFile(true, file, allocator);
    defer instr.deinit();

    var polygon = try Polygon.build(&instr, allocator);
    defer polygon.deinit();

    std.debug.print("Part 2: {any}\n", .{polygon.area()});
}

pub fn main() !void {
    try part1();
    try part2();
}
