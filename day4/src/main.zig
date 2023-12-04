const std = @import("std");
const splitAny = std.mem.splitAny;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const buffer_size = 2048;

const ScratchCard = struct {
    id: u32,
    copies: u32,
    winning: ArrayList(u32),
    picked: ArrayList(u32),

    fn parsePart(parts: []const u8, allocator: Allocator) !ArrayList(u32) {
        var numbers = splitAny(u8, trim(u8, parts, " "), " ");
        var parsed = ArrayList(u32).init(allocator);
        while (numbers.next()) |n| {
            var trimmed = trim(u8, n, " ");
            if (trimmed.len > 0) {
                var p = try parseInt(u32, trimmed, 10);
                try parsed.append(p);
            }
        }
        return parsed;
    }

    fn parseOne(line: []const u8, allocator: Allocator) !ScratchCard {
        var outer = splitAny(u8, line, ":");

        var card_part = outer.next().?;
        var id_part = splitAny(u8, card_part, " ");
        assert(std.mem.eql(u8, id_part.next().?, "Card"));
        var id_slice = while (id_part.next()) |n| {
            var trimmed = trim(u8, n, " ");
            if (trimmed.len > 0) {
                break trimmed;
            }
        } else unreachable;
        var id = try parseInt(u32, id_slice, 10);

        var parts = splitAny(u8, trim(u8, outer.next().?, " "), "|");
        var winning_part = parts.next().?;
        var picked_part = parts.next().?;
        return ScratchCard{
            .id = id,
            .copies = 1,
            .winning = try ScratchCard.parsePart(winning_part, allocator),
            .picked = try ScratchCard.parsePart(picked_part, allocator),
        };
    }

    fn parse(data: []const u8, allocator: Allocator) !ArrayList(ScratchCard) {
        var lines = splitAny(u8, data, "\n");
        var output = ArrayList(ScratchCard).init(allocator);
        while (lines.next()) |l| {
            var card = try ScratchCard.parseOne(l, allocator);
            try output.append(card);
        }
        return output;
    }

    fn parseFile(file: std.fs.File, allocator: Allocator) !ArrayList(ScratchCard) {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);
        return ScratchCard.parse(buffer, allocator);
    }

    fn deinit(self: *const ScratchCard) void {
        self.winning.deinit();
        self.picked.deinit();
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    const all_cards = try ScratchCard.parseFile(file, allocator);
    defer {
        for (all_cards.items) |i| {
            i.deinit();
        }
        all_cards.deinit();
    }

    var result: u64 = 0;
    for (all_cards.items) |s| {
        var winning_numbers: u32 = 0;
        for (s.picked.items) |p| {
            for (s.winning.items) |w| {
                if (w == p) {
                    winning_numbers += 1;
                    break;
                }
            }
        }
        var points = if (winning_numbers > 0) std.math.pow(u32, 2, winning_numbers - 1) else 0;
        result += points;
    }

    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    const all_cards = try ScratchCard.parseFile(file, allocator);
    defer {
        for (all_cards.items) |i| {
            i.deinit();
        }
        all_cards.deinit();
    }

    var result: u64 = 0;
    var i: usize = 0;
    while (i < all_cards.items.len) : (i += 1) {
        var s = all_cards.items[i];

        var winning_numbers: u32 = 0;
        for (s.picked.items) |p| {
            for (s.winning.items) |w| {
                if (w == p) {
                    winning_numbers += 1;
                    break;
                }
            }
        }

        for ((i + 1)..(i + winning_numbers + 1)) |j| {
            all_cards.items[j].copies += s.copies;
        }

        result += s.copies;
    }

    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
