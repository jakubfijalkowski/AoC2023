const std = @import("std");
const splitAny = std.mem.splitAny;
const trim = std.mem.trim;
const parseInt = std.fmt.parseInt;
const eql = std.mem.eql;
const assert = std.debug.assert;

const CubeNumType = u64;

const buffer_size = 2048;

const CubeSet = struct {
    red: CubeNumType,
    green: CubeNumType,
    blue: CubeNumType,
    pub fn is_valid(self: *const CubeSet, other: *const CubeSet) bool {
        return (self.red <= other.red) and (self.green <= other.green) and (self.blue <= other.blue);
    }
};
const Game = struct {
    id: CubeNumType,
    sets: std.ArrayList(CubeSet),
    pub fn deinit(self: *Game) void {
        self.sets.deinit();
    }
    pub fn is_valid(self: *const Game, set: *const CubeSet) bool {
        for (self.sets.items) |item| {
            if (!item.is_valid(set)) {
                return false;
            }
        }
        return true;
    }
    pub fn min_set(self: *const Game) CubeSet {
        var set = CubeSet{ .red = 0, .green = 0, .blue = 0 };
        for (self.sets.items) |item| {
            set.red = @max(item.red, set.red);
            set.green = @max(item.green, set.green);
            set.blue = @max(item.blue, set.blue);
        }
        return set;
    }
};

const ModelSet = CubeSet{ .red = 12, .green = 13, .blue = 14 };

pub fn parseSet(data: []const u8) !CubeSet {
    var set_iter = splitAny(u8, data, ",");

    var set = CubeSet{ .red = 0, .green = 0, .blue = 0 };

    while (set_iter.next()) |element| {
        var elem_iter = splitAny(u8, trim(u8, element, " "), " ");
        const value = try parseInt(CubeNumType, elem_iter.next().?, 10);
        const color = trim(u8, elem_iter.next().?, " ");
        if (eql(u8, color, "red")) {
            set.red = value;
        } else if (eql(u8, color, "green")) {
            set.green = value;
        } else {
            set.blue = value;
        }
    }
    return set;
}

pub fn parseGame(data: []const u8, allocator: std.mem.Allocator) !Game {
    var base_iter = splitAny(u8, data, ":");

    var game = splitAny(u8, base_iter.next().?, " ");
    assert(eql(u8, game.next().?, "Game")); // Skip 'Game'
    const game_id = try parseInt(CubeNumType, game.next().?, 10);

    var set_list = std.ArrayList(CubeSet).init(allocator);
    var sets = splitAny(u8, base_iter.next().?, ";");
    while (sets.next()) |set| {
        try set_list.append(try parseSet(set));
    }

    return Game{ .id = game_id, .sets = set_list };
}

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var line_buf: [buffer_size]u8 = undefined;
    var result: CubeNumType = 0;
    while (try stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        var game = try parseGame(line, allocator);
        defer game.deinit();

        if (game.is_valid(&ModelSet)) {
            result += game.id;
        }
    }
    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);

    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var line_buf: [buffer_size]u8 = undefined;
    var result: CubeNumType = 0;
    while (try stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        var game = try parseGame(line, allocator);
        defer game.deinit();
        var min_set = game.min_set();

        result += min_set.red * min_set.green * min_set.blue;
    }
    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
