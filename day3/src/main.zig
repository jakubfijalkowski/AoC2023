const std = @import("std");
const assert = std.debug.assert;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const buffer_size = 2048;

const Symbol = struct {
    symbol: u8,
    x: usize,
    y: usize,
};

const Part = struct {
    number: u64,
    adjacent_symbols: ArrayList(Symbol),
    fn deinit(self: *const Part) void {
        self.adjacent_symbols.deinit();
    }
};

const PartsList = struct {
    parts: ArrayList(Part),
    fn deinit(self: *const PartsList) void {
        for (self.parts.items) |p| {
            p.deinit();
        }
        self.parts.deinit();
    }
};

const Map = struct {
    width: usize,
    height: usize,
    allocator: Allocator,
    inner_buffer: []u8,
    lines: ArrayList([]const u8),
    fn parse(file: std.fs.File, allocator: Allocator) !Map {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));

        var map = Map{
            .width = 0,
            .height = 0,
            .allocator = allocator,
            .inner_buffer = buffer,
            .lines = ArrayList([]const u8).init(allocator),
        };
        assert(try file.readAll(buffer) == stat.size);
        var iter = std.mem.splitAny(u8, buffer, "\n");
        while (iter.next()) |line| {
            map.width = line.len;
            map.height += 1;
            try map.lines.append(line);
        }
        return map;
    }
    fn find_all_part_numbers(self: *const Map, allocator: Allocator) !PartsList {
        var final_list = ArrayList(Part).init(allocator);
        for (0..self.height) |y| {
            var x1: usize = 0;
            while (x1 < self.width) {
                if (std.ascii.isDigit(self.char_at(x1, y))) {
                    var x2 = x1;
                    for ((x1 + 1)..self.width) |x_candidate| {
                        if (std.ascii.isDigit(self.char_at(x_candidate, y))) {
                            x2 = x_candidate;
                        } else {
                            break;
                        }
                    }
                    var symbols = try self.all_symbols(y, x1, x2, allocator);
                    if (symbols.items.len > 0) {
                        const slice = self.lines.items[y][x1..(x2 + 1)];
                        const part_number = try std.fmt.parseInt(u64, slice, 10);
                        try final_list.append(Part{ .number = part_number, .adjacent_symbols = symbols });
                    } else {
                        symbols.deinit();
                    }
                    x1 = x2;
                }
                x1 += 1;
            }
        }
        return PartsList{ .parts = final_list };
    }
    fn all_symbols(self: *const Map, y: usize, x1: usize, x2: usize, allocator: Allocator) !ArrayList(Symbol) {
        var symbols = ArrayList(Symbol).init(allocator);
        var min_y = @as(usize, @max(@as(i64, @intCast(y)) - 1, 0));
        var min_x = @as(usize, @max(@as(i64, @intCast(x1)) - 1, 0));

        for (min_y..@min(y + 2, self.height)) |line| {
            for (min_x..@min(x2 + 2, self.width)) |x| {
                if (self.is_symbol(x, line)) {
                    try symbols.append(Symbol{
                        .x = x,
                        .y = line,
                        .symbol = self.char_at(x, line),
                    });
                }
            }
        }
        return symbols;
    }
    fn char_at(self: *const Map, x: usize, y: usize) u8 {
        return self.lines.items[y][x];
    }
    fn is_symbol(self: *const Map, x: usize, y: usize) bool {
        return x >= 0 and y >= 0 and x < self.width and y < self.height and self.lines.items[y][x] != '.' and !std.ascii.isDigit(self.lines.items[y][x]);
    }
    fn deinit(self: *const Map) void {
        self.lines.deinit();
        self.allocator.free(self.inner_buffer);
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    const map = try Map.parse(file, allocator);
    defer map.deinit();

    const part_numbers = try map.find_all_part_numbers(allocator);
    defer part_numbers.deinit();

    var result: u64 = 0;
    for (part_numbers.parts.items) |p| {
        result += p.number;
    }

    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    const map = try Map.parse(file, allocator);
    defer map.deinit();

    const part_numbers = try map.find_all_part_numbers(allocator);
    defer part_numbers.deinit();

    // Assumption - part numbers are unique
    var symbols = std.AutoHashMap(Symbol, ArrayList(u64)).init(allocator);
    defer {
        var val_iter = symbols.valueIterator();
        while (val_iter.next()) |v| {
            v.deinit();
        }
        symbols.deinit();
    }

    for (part_numbers.parts.items) |p| {
        for (p.adjacent_symbols.items) |s| {
            var item = try symbols.getOrPut(s);
            if (!item.found_existing) {
                item.value_ptr.* = ArrayList(u64).init(allocator);
            }
            try item.value_ptr.append(p.number);
        }
    }

    var result: u64 = 0;
    var symbol_iter = symbols.iterator();
    while (symbol_iter.next()) |e| {
        if (e.value_ptr.items.len == 2) {
            result += e.value_ptr.items[0] * e.value_ptr.items[1];
        }
    }

    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
