const std = @import("std");
const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const Range = struct {
    start: i64,
    len: i64,
};

const Mapping = struct {
    source: i64,
    destination: i64,
    len: i64,

    fn parse(data: []const u8) !Mapping {
        var parts = splitAny(u8, data, " ");
        var destination = try parseInt(i64, parts.next().?, 10);
        var source = try parseInt(i64, parts.next().?, 10);
        var length = try parseInt(i64, parts.next().?, 10);
        return Mapping{
            .destination = destination,
            .source = source,
            .len = length,
        };
    }

    fn tryTranslate(self: *const Mapping, n: i64) ?i64 {
        if (n >= self.source and n < self.source + self.len) {
            return self.destination + n - self.source;
        } else {
            return null;
        }
    }

    fn inRange(self: *const Mapping, v: i64) bool {
        return self.source <= v and v < self.source + self.len;
    }

    fn part2(self: *const Mapping, r: Range, lvl: usize, almanac: *const Almanac) ?i64 {
        const end = r.start + r.len - 1;
        if (self.inRange(r.start) and self.inRange(end)) {
            var inner = Range{ .start = self.destination + (r.start - self.source), .len = r.len };
            return almanac.part2(inner, lvl + 1);
        } else if (self.inRange(r.start) and !self.inRange(end)) {
            var inner = Range{ .start = self.destination + r.start - self.source, .len = self.len - (r.start - self.source) };
            var after = Range{ .start = r.start + inner.len, .len = r.len - inner.len };
            return @min(
                almanac.part2(inner, lvl + 1),
                almanac.part2(after, lvl),
            );
        } else if (!self.inRange(r.start) and self.inRange(end)) {
            var before = Range{ .start = r.start, .len = self.source - r.start };
            var inner = Range{ .start = self.destination, .len = r.len - before.len };
            return @min(
                almanac.part2(before, lvl),
                almanac.part2(inner, lvl + 1),
            );
        } else if (r.start < self.source and (self.source + self.len) < (r.start + r.len)) {
            var before = Range{ .start = r.start, .len = self.source - r.start };
            var inner = Range{ .start = self.destination, .len = self.len };
            var after = Range{ .start = self.source + self.len, .len = (r.start + r.len) - (self.source + self.len) };
            return @min(@min(
                almanac.part2(before, lvl),
                almanac.part2(after, lvl),
            ), almanac.part2(inner, lvl + 1));
        } else {
            return null;
        }
    }
};

const Category = struct {
    name: []const u8,
    mappings: ArrayList(Mapping),
    allocator: Allocator,

    fn parse(data: []const u8, allocator: Allocator) !Category {
        var lines = splitAny(u8, data, "\n");
        var name = lines.next().?;
        var mappings = ArrayList(Mapping).init(allocator);

        while (lines.next()) |l| {
            try mappings.append(try Mapping.parse(l));
        }

        return Category{
            .name = try allocator.dupe(u8, name),
            .mappings = mappings,
            .allocator = allocator,
        };
    }

    fn translate(self: *const Category, n: i64) i64 {
        for (self.mappings.items) |m| {
            var mapped = m.tryTranslate(n);
            if (mapped != null) {
                return mapped.?;
            }
        }
        return n;
    }

    fn part2(self: *const Category, r: Range, lvl: usize, almanac: *const Almanac) i64 {
        for (self.mappings.items) |m| {
            var mapped = m.part2(r, lvl, almanac);
            if (mapped != null) {
                return mapped.?;
            }
        }
        return almanac.part2(r, lvl + 1);
    }

    fn deinit(self: *const Category) void {
        self.mappings.deinit();
        self.allocator.free(self.name);
    }
};

const Almanac = struct {
    seeds: ArrayList(i64),
    categories: ArrayList(Category),

    fn parseFile(file: std.fs.File, allocator: Allocator) !Almanac {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        defer allocator.free(buffer);

        assert(try file.readAll(buffer) == stat.size);
        return Almanac.parse(buffer, allocator);
    }

    fn parse(data: []const u8, allocator: Allocator) !Almanac {
        var parts = splitSequence(u8, data, "\n\n");

        var seeds_parts = splitAny(u8, parts.next().?, " ");
        assert(std.mem.eql(u8, seeds_parts.next().?, "seeds:"));
        var seeds = ArrayList(i64).init(allocator);
        while (seeds_parts.next()) |s| {
            try seeds.append(try parseInt(i64, s, 10));
        }

        var categories = ArrayList(Category).init(allocator);
        while (parts.next()) |p| {
            try categories.append(try Category.parse(p, allocator));
        }

        return Almanac{
            .seeds = seeds,
            .categories = categories,
        };
    }

    fn translate(self: *const Almanac, n: i64) i64 {
        var output = n;
        for (self.categories.items) |c| {
            output = c.translate(output);
        }
        return output;
    }

    fn part2(self: *const Almanac, r: Range, lvl: usize) i64 {
        if (r.len <= 0) {
            return std.math.maxInt(i64);
        } else if (lvl == self.categories.items.len) {
            return r.start;
        }

        var category = self.categories.items[lvl];
        return category.part2(r, lvl, self);
    }

    fn deinit(self: *const Almanac) void {
        self.seeds.deinit();
        for (self.categories.items) |c| {
            c.deinit();
        }
        self.categories.deinit();
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    const almanac = try Almanac.parseFile(file, allocator);
    defer almanac.deinit();

    var result: i64 = std.math.maxInt(i64);
    for (almanac.seeds.items) |s| {
        var target = almanac.translate(s);
        result = @min(result, target);
    }

    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    const almanac = try Almanac.parseFile(file, allocator);
    defer almanac.deinit();

    var result: i64 = std.math.maxInt(i64);
    var i: usize = 0;

    while (i < almanac.seeds.items.len) : (i += 2) {
        var start = almanac.seeds.items[i];
        var length = almanac.seeds.items[i + 1];

        result = @min(result, almanac.part2(Range{ .start = start, .len = length }, 0));
    }

    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
