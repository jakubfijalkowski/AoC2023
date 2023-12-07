const std = @import("std");
const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const AutoArrayHashMap = std.AutoArrayHashMap;
const Allocator = std.mem.Allocator;

const Strength = enum { FiveOfAKind, FourOfAKind, FullHouse, ThreeOfAKind, TwoPair, OnePair, HighCard };

const Game = struct {
    hands: ArrayList(Hand),

    fn parseFile(file: std.fs.File, replaceJokers: bool, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);

        var lines = splitAny(u8, buffer, "\n");
        var result = ArrayList(Hand).init(allocator);
        while (lines.next()) |l| {
            try result.append(try Hand.parse(l, replaceJokers, allocator));
        }
        std.sort.insertion(Hand, result.items, replaceJokers, Hand.compare);
        return Game{ .hands = result };
    }

    fn deinit(self: *const Game) void {
        for (self.hands.items) |g| {
            g.deinit();
        }
        self.hands.deinit();
    }
};

const Hand = struct {
    hand: []const u8,
    strength: Strength,
    bid: u64,
    allocator: Allocator,

    fn parse(line: []const u8, replaceJokers: bool, allocator: Allocator) !Hand {
        var parts = splitAny(u8, line, " ");

        var hand = try allocator.dupe(u8, parts.next().?);
        return Hand{
            .hand = hand,
            .strength = try Hand.classify(hand, replaceJokers, allocator),
            .bid = try parseInt(u64, parts.next().?, 10),
            .allocator = allocator,
        };
    }

    fn compare(ctx: bool, lhs: Hand, rhs: Hand) bool {
        const sort = std.sort.desc(u32);
        if (lhs.strength == rhs.strength) {
            for (lhs.hand, 0..) |l, i| {
                const r = rhs.hand[i];
                if (l != r) {
                    return sort({}, Hand.toValue(r, ctx), Hand.toValue(l, ctx));
                }
            }
        }

        return sort({}, @intFromEnum(lhs.strength), @intFromEnum(rhs.strength));
    }

    fn classify(hand: []const u8, replaceJokers: bool, allocator: Allocator) !Strength {
        var cards = AutoArrayHashMap(u8, u8).init(allocator);
        defer cards.deinit();
        for (hand) |c| {
            var e = try cards.getOrPut(c);
            if (e.found_existing) {
                e.value_ptr.* += 1;
            } else {
                e.value_ptr.* = 1;
            }
        }

        var jokers = cards.get('J');
        if (replaceJokers and jokers != null) {
            _ = cards.swapRemove('J');

            if (jokers == 5) {
                try cards.put('A', 5);
            } else {
                var max_key: u8 = 0;
                var max_val: u8 = 0;
                for (cards.keys(), cards.values()) |k, v| {
                    if (v > max_val) {
                        max_val = v;
                        max_key = k;
                    }
                }

                cards.getEntry(max_key).?.value_ptr.* += jokers.?;
            }
        }

        const vals = cards.values();
        if (cards.count() == 1) {
            return Strength.FiveOfAKind;
        } else if (cards.count() == 2) {
            if (vals[0] == 4 or vals[0] == 1) {
                return Strength.FourOfAKind;
            } else {
                return Strength.FullHouse;
            }
        } else if (cards.count() == 3) {
            if (vals[0] == 3 or vals[1] == 3 or vals[2] == 3) {
                return Strength.ThreeOfAKind;
            } else {
                return Strength.TwoPair;
            }
        } else if (cards.count() == 4) {
            return Strength.OnePair;
        } else {
            return Strength.HighCard;
        }
    }

    fn toValue(c: u8, replaceJoker: bool) u32 {
        return switch (c) {
            'T' => 10,
            'J' => if (replaceJoker) 1 else 11,
            'Q' => 12,
            'K' => 13,
            'A' => 14,
            else => c - '0',
        };
    }

    fn deinit(self: *const Hand) void {
        self.allocator.free(self.hand);
    }
};

pub fn play(replaceJokers: bool) !u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();
    const game = try Game.parseFile(file, replaceJokers, allocator);
    defer game.deinit();

    var result: u64 = 0;
    for (game.hands.items, 1..) |h, r| {
        result += h.bid * r;
    }
    return result;
}

pub fn part1() !void {
    var result = try play(false);
    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var result = try play(true);
    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
