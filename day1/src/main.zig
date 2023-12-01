const std = @import("std");

pub fn part1() !void {
    const file = try std.fs.cwd().openFile("data.txt", .{});

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var line_buf: [1024]u8 = undefined;
    var result: u64 = 0;
    while (try stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        var first: ?u8 = null;
        var last: ?u8 = null;
        for (line) |c| {
            if (std.ascii.isDigit(c)) {
                if (first == null) {
                    first = c - '0';
                    last = c - '0';
                } else {
                    last = c - '0';
                }
            }
        }
        result += first.? * 10 + last.?;
    }
    std.debug.print("Part 1: {}\n", .{result});
}

pub fn toDigit(data: []u8) ?u8 {
    if (std.ascii.isDigit(data[0])) {
        return data[0] - '0';
    } else if (std.mem.startsWith(u8, data, "one")) {
        return 1;
    } else if (std.mem.startsWith(u8, data, "two")) {
        return 2;
    } else if (std.mem.startsWith(u8, data, "three")) {
        return 3;
    } else if (std.mem.startsWith(u8, data, "four")) {
        return 4;
    } else if (std.mem.startsWith(u8, data, "five")) {
        return 5;
    } else if (std.mem.startsWith(u8, data, "six")) {
        return 6;
    } else if (std.mem.startsWith(u8, data, "seven")) {
        return 7;
    } else if (std.mem.startsWith(u8, data, "eight")) {
        return 8;
    } else if (std.mem.startsWith(u8, data, "nine")) {
        return 9;
    } else {
        return null;
    }
}

pub fn part2() !void {
    const file = try std.fs.cwd().openFile("data.txt", .{});

    var reader = std.io.bufferedReader(file.reader());
    var stream = reader.reader();

    var line_buf: [1024]u8 = undefined;
    var result: u64 = 0;
    while (try stream.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        var first: ?u8 = null;
        var last: ?u8 = null;
        for (line, 0..) |_, idx| {
            var digit = toDigit(line[idx..]);
            if (digit != null) {
                if (first == null) {
                    first = digit.?;
                    last = digit.?;
                } else {
                    last = digit.?;
                }
            }
        }
        result += first.? * 10 + last.?;
    }
    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
