const std = @import("std");
const splitAny = std.mem.splitAny;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const abs = std.math.absCast;

const Spring = enum {
    Operational,
    Damaged,
    Unknown,

    fn parse(c: u8) Spring {
        return switch (c) {
            '.' => Spring.Operational,
            '#' => Spring.Damaged,
            else => Spring.Unknown,
        };
    }

    fn matches(self: Spring, other: Spring) bool {
        return other == Spring.Unknown or other == self;
    }

    fn toC(self: Spring) u8 {
        return switch (self) {
            Spring.Operational => '.',
            Spring.Damaged => '#',
            Spring.Unknown => '?',
        };
    }
};

const Pattern = struct {
    data: ArrayList(Spring),

    fn parse(data: []const u8, allocator: Allocator) !Pattern {
        var result = ArrayList(Spring).init(allocator);
        for (data) |c| {
            try result.append(Spring.parse(c));
        }
        return Pattern{ .data = result };
    }

    fn empty(len: usize, allocator: Allocator) !Pattern {
        var data = try ArrayList(Spring).initCapacity(allocator, len);
        data.appendNTimesAssumeCapacity(Spring.Unknown, len);
        return Pattern{ .data = data };
    }

    fn matches(self: *const Pattern, other: *const Pattern) bool {
        for (self.data.items, other.data.items) |s, o| {
            if (!s.matches(o)) {
                return false;
            }
        }

        return true;
    }

    fn print(self: *const Pattern) void {
        for (self.data.items) |s| {
            std.debug.print("{c}", .{s.toC()});
        }
    }

    fn deinit(self: *const Pattern) void {
        self.data.deinit();
    }
};

const PatternBuilder = struct {
    row: *const Row,
    working: Pattern,

    fn create(basedOn: *const Row, allocator: Allocator) !PatternBuilder {
        return PatternBuilder{
            .row = basedOn,
            .working = try Pattern.empty(basedOn.pattern.data.items.len, allocator),
        };
    }

    fn calculateMatches(self: *PatternBuilder) u32 {
        var result: u32 = 0;
        self.next(0, &result);
        return result;
    }

    fn next(self: *PatternBuilder, i: usize, output: *u32) void {
        if (i == self.working.data.items.len) {
            if (self.check()) {
                output.* += 1;
            }
        } else {
            if (self.row.pattern.data.items[i] == Spring.Unknown) {
                self.working.data.items[i] = Spring.Damaged;
                self.next(i + 1, output);
                self.working.data.items[i] = Spring.Operational;
                self.next(i + 1, output);
            } else {
                self.working.data.items[i] = self.row.pattern.data.items[i];
                self.next(i + 1, output);
            }
        }
    }

    fn check(self: *PatternBuilder) bool {
        return self.doBlocksMatch() and self.working.matches(&self.row.pattern);
    }

    fn doBlocksMatch(self: *const PatternBuilder) bool {
        var blockIdx: usize = 0;
        var currBlockLen: usize = 0;
        for (self.working.data.items) |i| {
            if (i == Spring.Damaged) {
                currBlockLen += 1;
            } else if (currBlockLen > 0) {
                if (blockIdx >= self.row.blocks.items.len or self.row.blocks.items[blockIdx] != currBlockLen) {
                    return false;
                }

                currBlockLen = 0;
                blockIdx += 1;
            }
        }

        if (currBlockLen > 0) {
            if (blockIdx >= self.row.blocks.items.len or self.row.blocks.items[blockIdx] != currBlockLen) {
                return false;
            }

            currBlockLen = 0;
            blockIdx += 1;
        }

        return blockIdx == self.row.blocks.items.len;
    }

    fn deinit(self: *const PatternBuilder) void {
        self.working.deinit();
    }
};

const Row = struct {
    pattern: Pattern,
    blocks: ArrayList(usize),

    fn parse(line: []const u8, allocator: Allocator) !Row {
        var parts = splitAny(u8, line, " ");
        var pattern = try Pattern.parse(parts.next().?, allocator);
        var numbers = splitAny(u8, parts.next().?, ",");
        var blocks = ArrayList(usize).init(allocator);
        while (numbers.next()) |n| {
            try blocks.append(try parseInt(usize, n, 10));
        }
        return Row{
            .pattern = pattern,
            .blocks = blocks,
        };
    }

    fn deinit(self: *const Row) void {
        self.pattern.deinit();
        self.blocks.deinit();
    }
};

const Game = struct {
    rows: ArrayList(Row),

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);

        var lines = splitAny(u8, buffer, "\n");
        var rows = ArrayList(Row).init(allocator);
        while (lines.next()) |l| {
            try rows.append(try Row.parse(l, allocator));
        }
        return Game{ .rows = rows };
    }

    fn calculatePossibilities(self: *const Game, allocator: Allocator) !u32 {
        var result: u32 = 0;
        for (self.rows.items) |r| {
            var builder = try PatternBuilder.create(&r, allocator);
            defer builder.deinit();
            result += builder.calculateMatches();
        }
        return result;
    }

    fn deinit(self: *const Game) void {
        for (self.rows.items) |i| {
            i.deinit();
        }
        self.rows.deinit();
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

    std.debug.print("Part 1: {}\n", .{try game.calculatePossibilities(allocator)});
}

pub fn part2() !void {}

pub fn main() !void {
    try part1();
    try part2();
}
