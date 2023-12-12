const std = @import("std");
const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;
const Allocator = std.mem.Allocator;

const Node = struct {
    name: []const u8,
    left: []const u8,
    right: []const u8,

    fn parse(line: []const u8) Node {
        return Node{
            .name = line[0..3],
            .left = line[7..10],
            .right = line[12..15],
        };
    }
};

const Game = struct {
    instructions: []const u8,
    nodes: StringArrayHashMap(Node),
    buffer: []const u8,
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));

        assert(try file.readAll(buffer) == stat.size);

        var lines = splitAny(u8, buffer, "\n");
        var result = StringArrayHashMap(Node).init(allocator);
        var instructions = lines.next().?;
        _ = lines.next().?;
        while (lines.next()) |l| {
            var n = Node.parse(l);
            try result.put(n.name, n);
        }
        return Game{
            .instructions = instructions,
            .nodes = result,
            .buffer = buffer,
            .allocator = allocator,
        };
    }

    fn move(self: *const Game, n: []const u8, i: u64) []const u8 {
        var next = self.nodes.get(n).?;
        var instr = self.instructions[i % self.instructions.len];
        if (instr == 'L') {
            return next.left;
        } else {
            return next.right;
        }
    }

    fn deinit(self: *Game) void {
        self.nodes.deinit();
        self.allocator.free(self.buffer);
    }
};

fn lcm(a: u64, b: u64) u64 {
    return a / std.math.gcd(a, b) * b;
}

fn lcmList(list: []const u64) u64 {
    var result = list[0];
    for (list[1..]) |n| {
        result = lcm(result, n);
    }
    return result;
}

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();
    var game = try Game.parseFile(file, allocator);
    defer game.deinit();

    var result: u64 = 0;
    var current_node: []const u8 = "AAA";
    while (!std.mem.eql(u8, current_node, "ZZZ")) : (result += 1) {
        current_node = game.move(current_node, result);
    }
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

    var steps = ArrayList(u64).init(allocator);
    defer steps.deinit();

    outer: for (game.nodes.values()) |v| {
        if (v.name[2] == 'A') {
            var current_node: []const u8 = v.name;
            for (0..std.math.maxInt(u32)) |i| {
                if (current_node[2] == 'Z') {
                    try steps.append(i);
                    continue :outer;
                }
                current_node = game.move(current_node, i);
            }
        }
    }

    var result = lcmList(steps.items);

    std.debug.print("Part 2: {}\n", .{result});
}

pub fn main() !void {
    try part1();
    try part2();
}
