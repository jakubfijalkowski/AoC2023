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
    x: i32,
    y: i32,

    fn move(self: Vec2, dx: i32, dy: i32) Vec2 {
        return Vec2{ .x = self.x + dx, .y = self.y + dy };
    }

    fn lessThanOrEqual(a: Vec2, b: Vec2) bool {
        return a.x <= b.x and a.y <= b.y;
    }
};

const Vec3 = struct {
    x: i32,
    y: i32,
    z: i32,

    fn zero() Vec3 {
        return Vec3{ .x = 0, .y = 0, .z = 0 };
    }

    fn parse(data: []const u8) !Vec3 {
        var parts = splitAny(u8, data, ",");
        return Vec3{
            .x = try parseInt(i32, parts.next().?, 10),
            .y = try parseInt(i32, parts.next().?, 10),
            .z = try parseInt(i32, parts.next().?, 10),
        };
    }

    fn formMin(a: Vec3, b: Vec3) Vec3 {
        return Vec3{
            .x = @min(a.x, b.x),
            .y = @min(a.y, b.y),
            .z = @min(a.z, b.z),
        };
    }

    fn formMax(a: Vec3, b: Vec3) Vec3 {
        return Vec3{
            .x = @max(a.x, b.x),
            .y = @max(a.y, b.y),
            .z = @max(a.z, b.z),
        };
    }

    fn toVec2(self: Vec3) Vec2 {
        return Vec2{ .x = self.x, .y = self.y };
    }

    fn moveByZ(self: Vec3, z: i32) Vec3 {
        return Vec3{ .x = self.x, .y = self.y, .z = self.z + z };
    }

    fn moveToZ(self: Vec3, z: i32) Vec3 {
        return Vec3{ .x = self.x, .y = self.y, .z = z };
    }
};

const Brick = struct {
    name: i32,
    min: Vec3,
    max: Vec3,

    fn zero() Brick {
        return Brick{ .name = 0, .min = Vec3.zero(), .max = Vec3.zero() };
    }

    fn parse(data: []const u8, name: i32) !Brick {
        var parts = splitAny(u8, data, "~");
        const a = try Vec3.parse(parts.next().?);
        const b = try Vec3.parse(parts.next().?);
        return Brick{
            .name = name,
            .min = Vec3.formMin(a, b),
            .max = Vec3.formMax(a, b),
        };
    }

    fn collides(self: *const Brick, other: *const Brick) bool {
        return self.min.x <= other.max.x and
            self.max.x >= other.min.x and
            self.min.y <= other.max.y and
            self.max.y >= other.min.y and
            self.min.z <= other.max.z and
            self.max.z >= other.min.z;
    }

    fn moveByZ(self: *Brick, z: i32) void {
        self.min = self.min.moveByZ(z);
        self.max = self.max.moveByZ(z);
    }

    fn moveToZ(self: *Brick, z: i32) void {
        const by = z - self.min.z;
        self.moveByZ(by);
    }

    fn lessThan(_: void, lhs: Brick, rhs: Brick) bool {
        return lhs.min.z < rhs.min.z;
    }
};

const HeightMap = struct {
    map: AutoHashMap(Vec2, *const Brick),

    const Iterator = struct {
        dx: i32,
        dy: i32,
        left: i32,
        curr: Vec2,
        map: *const HeightMap,

        fn next(self: *Iterator) ?*const Brick {
            while (self.left > 0) {
                const got = self.map.map.get(self.curr);

                self.curr = self.curr.move(self.dx, self.dy);
                self.left -= 1;
                if (got != null) {
                    return got;
                }
            }
            return null;
        }
    };

    fn init(allocator: Allocator) HeightMap {
        return HeightMap{
            .map = AutoHashMap(Vec2, *const Brick).init(allocator),
        };
    }

    fn getSupport(self: *const HeightMap, brick: *const Brick) Iterator {
        return .{
            .dx = std.math.clamp(brick.max.x - brick.min.x, -1, 1),
            .dy = std.math.clamp(brick.max.y - brick.min.y, -1, 1),
            .left = @max(brick.max.x - brick.min.x, brick.max.y - brick.min.y) + 1,
            .curr = brick.min.toVec2(),
            .map = self,
        };
    }

    fn getHeightAt(self: *const HeightMap, brick: *const Brick) i32 {
        var iter = self.getSupport(brick);
        var currMax: i32 = 0;
        while (iter.next()) |b| {
            currMax = @max(currMax, b.max.z);
        }
        return currMax;
    }

    fn store(self: *HeightMap, brick: *const Brick) !void {
        const dx = std.math.clamp(brick.max.x - brick.min.x, -1, 1);
        const dy = std.math.clamp(brick.max.y - brick.min.y, -1, 1);

        var curr = brick.min.toVec2();
        var left = @max(brick.max.x - brick.min.x, brick.max.y - brick.min.y) + 1;
        while (left > 0) {
            try self.map.put(curr, brick);

            curr = curr.move(dx, dy);
            left -= 1;
        }
    }

    fn deinit(self: *HeightMap) void {
        self.map.deinit();
    }
};

const Game = struct {
    bricks: ArrayList(Brick),
    supportedBy: AutoHashMap(*const Brick, AutoArrayHashSet(*const Brick)),
    supports: AutoHashMap(*const Brick, AutoArrayHashSet(*const Brick)),
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);
        assert(try file.readAll(buffer) == stat.size);

        var lines = splitAny(u8, buffer, "\n");
        var bricks = ArrayList(Brick).init(allocator);
        var name: i32 = 1;
        while (lines.next()) |l| : (name += 1) {
            try bricks.append(try Brick.parse(l, name));
        }
        std.sort.pdq(Brick, bricks.items, {}, Brick.lessThan);

        var supportedBy = AutoHashMap(*const Brick, AutoArrayHashSet(*const Brick)).init(allocator);
        var supports = AutoHashMap(*const Brick, AutoArrayHashSet(*const Brick)).init(allocator);

        for (bricks.items) |*b| {
            try supportedBy.put(b, AutoArrayHashSet(*const Brick).init(allocator));
            try supports.put(b, AutoArrayHashSet(*const Brick).init(allocator));
        }

        return Game{
            .bricks = bricks,
            .supportedBy = supportedBy,
            .supports = supports,
            .allocator = allocator,
        };
    }

    fn fall(self: *Game) !void {
        var hm = HeightMap.init(self.allocator);
        defer hm.deinit();
        for (self.bricks.items) |*b| {
            const toHeight = hm.getHeightAt(b);
            b.moveToZ(toHeight + 1);

            var supportedBy = self.supportedBy.getPtr(b).?;

            var iter = hm.getSupport(b);
            while (iter.next()) |other| {
                if (other.max.z == toHeight) {
                    try supportedBy.put(other, {});
                }
            }

            try hm.store(b);
        }

        try self.buildSupports();
    }

    fn isCollision(self: *const Game) bool {
        for (0..self.bricks.items.len) |i| {
            for ((i + 1)..self.bricks.items.len) |j| {
                if (self.bricks.items[i].collides(&self.bricks.items[j])) {
                    std.debug.print("Collision: {} & {}\n", .{ i, j });
                    std.debug.print("   {any}\n", .{self.bricks.items[i]});
                    std.debug.print("   {any}\n", .{self.bricks.items[j]});
                    return true;
                }
            }
        }
        return false;
    }

    fn buildSupports(self: *Game) !void {
        for (self.bricks.items) |*b| {
            var sb = self.supportedBy.get(b).?;

            for (sb.keys()) |other| {
                var s = self.supports.getPtr(other).?;
                try s.put(b, {});
            }
        }
    }

    fn countOnesThatCanBeRemoved(self: *const Game) i32 {
        var result: i32 = 0;

        outer: for (self.bricks.items) |*b| {
            var supports = self.supports.get(b).?;

            for (supports.keys()) |s| {
                if (self.supportedBy.get(s).?.count() == 1) {
                    continue :outer;
                }
            }

            result += 1;
        }

        return result;
    }

    fn calculateChainLengthFor(self: *const Game, brick: *const Brick) !usize {
        var removed = AutoArrayHashSet(*const Brick).init(self.allocator);
        defer removed.deinit();

        try removed.put(brick, {});

        var i: usize = 0;
        while (i < removed.count()) : (i += 1) {
            const supports = self.supports.getPtr(removed.keys()[i]).?;

            for (supports.keys()) |s| {
                const supportedBy = self.supportedBy.getPtr(s).?;
                var supportCount: usize = 0;
                for (supportedBy.keys()) |sb| {
                    if (!removed.contains(sb)) {
                        supportCount += 1;
                    }
                }

                if (supportCount == 0) {
                    try removed.put(s, {});
                }
            }
        }

        return removed.count() - 1;
    }

    fn calculateChainSums(self: *const Game) !usize {
        var result: usize = 0;
        for (self.bricks.items) |*b| {
            result += try self.calculateChainLengthFor(b);
        }
        return result;
    }

    fn deinit(self: *Game) void {
        self.bricks.deinit();

        var sbiter = self.supportedBy.valueIterator();
        while (sbiter.next()) |l| {
            l.deinit();
        }
        self.supportedBy.deinit();

        var siter = self.supports.valueIterator();
        while (siter.next()) |l| {
            l.deinit();
        }
        self.supports.deinit();
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

    try g.fall();

    std.debug.print("Part 1: {}\n", .{g.countOnesThatCanBeRemoved()});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var g = try Game.parseFile(file, allocator);
    defer g.deinit();

    try g.fall();

    std.debug.print("Part 2: {}\n", .{try g.calculateChainSums()});
}

pub fn main() !void {
    try part1();
    try part2();
}
