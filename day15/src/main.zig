const std = @import("std");
const splitAny = std.mem.splitAny;
const indexOf = std.mem.indexOf;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const ArrayHashMap = std.ArrayHashMap;
const Allocator = std.mem.Allocator;

fn hash(data: []const u8) u8 {
    var result: u64 = 0;
    for (data) |c| {
        result += c;
        result *= 17;
        result %= 256;
    }
    return @truncate(result);
}

const Action = enum { Remove, Add };

const Instruction = struct {
    label: []const u8,
    box: u64,
    action: Action,
    focal: ?u64,
    fn parse(data: []const u8) !Instruction {
        const removeIdx = indexOf(u8, data, "-");
        if (removeIdx == null) {
            const eqIdx = indexOf(u8, data, "=").?;
            return Instruction{
                .label = data[0..eqIdx],
                .box = hash(data[0..eqIdx]),
                .action = Action.Add,
                .focal = try parseInt(u64, data[(eqIdx + 1)..], 10),
            };
        } else {
            return Instruction{ .label = data[0..removeIdx.?], .box = hash(data[0..removeIdx.?]), .action = Action.Remove, .focal = null };
        }
    }
};

const Lens = struct {
    label: []const u8,
    focal: u64,
};

const Box = struct {
    data: ArrayList(Lens),

    fn init(allocator: Allocator) Box {
        return Box{
            .data = ArrayList(Lens).init(allocator),
        };
    }

    fn add(self: *Box, lens: Lens) !void {
        for (self.data.items, 0..) |d, i| {
            if (std.mem.eql(u8, d.label, lens.label)) {
                self.data.items[i] = lens;
                return;
            }
        }

        try self.data.append(lens);
    }

    fn remove(self: *Box, lbl: []const u8) void {
        for (self.data.items, 0..) |d, i| {
            if (std.mem.eql(u8, d.label, lbl)) {
                _ = self.data.orderedRemove(i);
                break;
            }
        }
    }

    fn calculate(self: *const Box, idx: u64) u64 {
        var result: u64 = 0;
        for (self.data.items, 1..) |l, i| {
            result += (idx + 1) * i * l.focal;
        }
        return result;
    }

    fn deinit(self: *const Box) void {
        self.data.deinit();
    }
};

const Game = struct {
    data: []const u8,
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));

        assert(try file.readAll(buffer) == stat.size);

        return Game{ .data = buffer, .allocator = allocator };
    }

    fn splitAndHashAll(self: *const Game) u64 {
        var parts = splitAny(u8, self.data, ",");
        var result: u64 = 0;
        while (parts.next()) |p| {
            result += hash(p);
        }
        return result;
    }

    fn execute(self: *const Game) !u64 {
        var boxes: [256]Box = undefined;
        defer {
            for (boxes) |b| {
                b.deinit();
            }
        }
        for (0..boxes.len) |i| {
            boxes[i] = Box.init(self.allocator);
        }

        var parts = splitAny(u8, self.data, ",");
        while (parts.next()) |p| {
            const instr = try Instruction.parse(p);
            if (instr.action == Action.Remove) {
                boxes[instr.box].remove(instr.label);
            } else {
                try boxes[instr.box].add(Lens{ .label = instr.label, .focal = instr.focal.? });
            }
        }

        var result: u64 = 0;
        for (boxes, 0..) |b, i| {
            result += b.calculate(i);
        }

        return result;
    }

    fn deinit(self: *const Game) void {
        self.allocator.free(self.data);
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

    var result = game.splitAndHashAll();

    std.debug.print("Part 1: {}\n", .{result});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var game = try Game.parseFile(file, allocator);
    defer game.deinit();

    var result = try game.execute();

    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
