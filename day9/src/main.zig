const std = @import("std");
const splitAny = std.mem.splitAny;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const OasisSequence = ArrayList(i64);

const OasisTriangle = struct {
    levels: ArrayList(OasisSequence),
    fn build(seq: OasisSequence, allocator: Allocator) !OasisTriangle {
        var triangle = OasisTriangle{ .levels = ArrayList(OasisSequence).init(allocator) };
        try triangle.levels.append(seq);
        while (!triangle.isLastZero()) {
            try triangle.buildNext(allocator);
        }
        return triangle;
    }

    fn calculateNext(self: *const OasisTriangle) i64 {
        var x: i64 = 0;
        var i = @as(isize, @intCast(self.levels.items.len)) - 2;
        while (i >= 0) : (i -= 1) {
            var lvl = self.levels.items[@as(usize, @intCast(i))];
            var y = lvl.items[lvl.items.len - 1];
            x = y + x;
        }

        return x;
    }

    fn calculatePrevious(self: *const OasisTriangle) i64 {
        var x: i64 = 0;
        var i = @as(isize, @intCast(self.levels.items.len)) - 2;
        while (i >= 0) : (i -= 1) {
            var lvl = self.levels.items[@as(usize, @intCast(i))];
            var y = lvl.items[0];
            x = y - x;
        }

        return x;
    }

    fn buildNext(self: *OasisTriangle, allocator: Allocator) !void {
        const last_level = self.levels.items[self.levels.items.len - 1];
        var next_level = try OasisSequence.initCapacity(allocator, last_level.items.len - 1);
        for (last_level.items[1..], 0..) |b, i| {
            next_level.appendAssumeCapacity(b - last_level.items[i]);
        }
        try self.levels.append(next_level);
    }

    fn isLastZero(self: *const OasisTriangle) bool {
        return std.mem.allEqual(i64, self.levels.items[self.levels.items.len - 1].items, 0);
    }

    fn deinit(self: *const OasisTriangle) void {
        for (self.levels.items[1..]) |l| {
            l.deinit();
        }
        self.levels.deinit();
    }
};

const Oasis = struct {
    sequences: ArrayList(OasisSequence),

    fn parseFile(file: std.fs.File, allocator: Allocator) !Oasis {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);

        var lines = splitAny(u8, buffer, "\n");
        var result = ArrayList(OasisSequence).init(allocator);
        while (lines.next()) |l| {
            var numbers = splitAny(u8, l, " ");
            var seq = OasisSequence.init(allocator);
            while (numbers.next()) |n| {
                try seq.append(try parseInt(i64, n, 10));
            }
            try result.append(seq);
        }
        return Oasis{
            .sequences = result,
        };
    }

    fn deinit(self: *const Oasis) void {
        for (self.sequences.items) |s| {
            s.deinit();
        }
        self.sequences.deinit();
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();
    var oasis = try Oasis.parseFile(file, allocator);
    defer oasis.deinit();

    var result: i64 = 0;
    for (oasis.sequences.items) |s| {
        var triangle = try OasisTriangle.build(s, allocator);
        result += triangle.calculateNext();
        defer triangle.deinit();
    }

    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();
    var oasis = try Oasis.parseFile(file, allocator);
    defer oasis.deinit();

    var result: i64 = 0;
    for (oasis.sequences.items) |s| {
        var triangle = try OasisTriangle.build(s, allocator);
        result += triangle.calculatePrevious();
        defer triangle.deinit();
    }

    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
