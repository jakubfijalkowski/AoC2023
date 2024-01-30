const std = @import("std");
const splitAny = std.mem.splitAny;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
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

    fn canBeDamaged(self: Spring) bool {
        return self == Spring.Damaged or self == Spring.Unknown;
    }

    fn isDamaged(self: Spring) bool {
        return self == Spring.Damaged;
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

    fn print(self: *const Pattern) void {
        for (self.data.items) |s| {
            std.debug.print("{c}", .{s.toC()});
        }
    }

    fn unfold(self: *Pattern) !void {
        const patLen = self.data.items.len;

        try self.data.ensureTotalCapacityPrecise(patLen * 5 + 4);
        for (0..4) |_| {
            self.data.appendAssumeCapacity(Spring.Unknown);
            self.data.appendSliceAssumeCapacity(self.data.items[0..patLen]);
        }
    }

    fn deinit(self: *const Pattern) void {
        self.data.deinit();
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

    fn unfold(self: *Row) !void {
        const blocksLen = self.blocks.items.len;

        try self.blocks.ensureTotalCapacityPrecise(blocksLen * 5);
        for (0..4) |_| {
            self.blocks.appendSliceAssumeCapacity(self.blocks.items[0..blocksLen]);
        }

        try self.pattern.unfold();
    }
    fn deinit(self: *const Row) void {
        self.pattern.deinit();
        self.blocks.deinit();
    }
};

const CacheEntry = struct {
    blockIdx: usize,
    pos: usize,
};

const CandidateTester = struct {
    row: *const Row,
    working: Candidate,
    cache: AutoHashMap(CacheEntry, u64),

    fn create(basedOn: *const Row, allocator: Allocator) !CandidateTester {
        return CandidateTester{
            .row = basedOn,
            .working = try Candidate.base(basedOn, allocator),
            .cache = AutoHashMap(CacheEntry, u64).init(allocator),
        };
    }

    fn calculateMatches(self: *CandidateTester) !u64 {
        var result: u64 = 0;
        try self.next(0, 0, 0, &result);
        return result;
    }

    fn next(self: *CandidateTester, blockIdx: usize, prevEnd: usize, from: usize, output: *u64) !void {
        if (blockIdx == self.row.blocks.items.len) {
            if (self.working.restMatch(prevEnd)) {
                output.* += 1;
            }
        } else {
            var blockLen = self.row.blocks.items[blockIdx];
            for (0..self.row.pattern.data.items.len) |offset| {
                const entry = CacheEntry{ .blockIdx = blockIdx, .pos = from + offset };
                const existing = self.cache.get(entry);
                if (existing == null) {
                    var segOutput: u64 = 0;
                    if (self.working.trySet(blockIdx, prevEnd, entry.pos)) {
                        try self.next(blockIdx + 1, entry.pos + blockLen, entry.pos + blockLen + 1, &segOutput);
                        try self.cache.put(entry, segOutput);
                        output.* += segOutput;
                    }
                } else {
                    output.* += existing.?;
                }
            }
        }
    }

    fn deinit(self: *CandidateTester) void {
        self.working.deinit();
        self.cache.deinit();
    }
};

const Candidate = struct {
    basedOn: *const Row,
    spaceReq: []usize,
    allocator: Allocator,

    fn base(row: *const Row, allocator: Allocator) !Candidate {
        var spaceReq = try allocator.alloc(usize, row.blocks.items.len + 1);
        spaceReq[spaceReq.len - 1] = 0;
        spaceReq[spaceReq.len - 2] = row.blocks.items[row.blocks.items.len - 1];

        for (1..row.blocks.items.len) |i| {
            spaceReq[spaceReq.len - 2 - i] = spaceReq[spaceReq.len - 1 - i] + row.blocks.items[row.blocks.items.len - 1 - i] + 1;
        }

        return Candidate{
            .basedOn = row,
            .spaceReq = spaceReq,
            .allocator = allocator,
        };
    }

    fn isMatch(self: *const Candidate, blockIdx: usize, prevEnd: usize, from: usize) bool {
        const to = from + self.basedOn.blocks.items[blockIdx];

        for (prevEnd..from) |j| {
            if (self.basedOn.pattern.data.items[j].isDamaged()) {
                return false;
            }
        }

        for (from..to) |j| {
            if (!self.basedOn.pattern.data.items[j].canBeDamaged()) {
                return false;
            }
        }
        return true;
    }

    fn trySet(self: *Candidate, blockIdx: usize, prevEnd: usize, from: usize) bool {
        const reqLen = from + self.spaceReq[blockIdx];
        return reqLen <= self.basedOn.pattern.data.items.len and self.isMatch(blockIdx, prevEnd, from);
    }

    fn restMatch(self: *const Candidate, prevEnd: usize) bool {
        if (prevEnd >= self.basedOn.pattern.data.items.len) {
            return true;
        }

        for (prevEnd..self.basedOn.pattern.data.items.len) |i| {
            if (self.basedOn.pattern.data.items[i].isDamaged()) {
                return false;
            }
        }
        return true;
    }

    fn deinit(self: *const Candidate) void {
        self.allocator.free(self.spaceReq);
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

    fn unfold(self: *Game) !void {
        for (self.rows.items) |*r| {
            try r.unfold();
        }
    }

    fn calculatePossibilities(self: *const Game, allocator: Allocator) !u64 {
        var result: u64 = 0;
        for (self.rows.items) |r| {
            var builder = try CandidateTester.create(&r, allocator);
            defer builder.deinit();
            result += try builder.calculateMatches();
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

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var game = try Game.parseFile(file, allocator);
    defer game.deinit();

    try game.unfold();

    std.debug.print("Part 2: {}\n", .{try game.calculatePossibilities(allocator)});
}

pub fn main() !void {
    try part1();
    try part2();
}
