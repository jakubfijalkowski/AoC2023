const std = @import("std");
const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const indexOf = std.mem.indexOf;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const StringArrayHashMap = std.StringArrayHashMap;
const Allocator = std.mem.Allocator;

const StringHashSet = StringArrayHashMap(void);

const String = []const u8;

const Component = struct {
    name: String,
    edges: StringHashSet,

    fn empty(name: String, allocator: Allocator) Component {
        return .{
            .name = name,
            .edges = StringHashSet.init(allocator),
        };
    }

    fn parse(data: String, allocator: Allocator) !Component {
        var generalParts = splitAny(u8, data, ":");
        const name = generalParts.next().?;

        var connectionParts = splitAny(u8, trim(u8, generalParts.next().?, " "), " ");
        var edges = StringHashSet.init(allocator);
        while (connectionParts.next()) |c| {
            try edges.put(c, {});
        }
        return .{
            .name = name,
            .edges = edges,
        };
    }

    fn deinit(self: *Component) void {
        self.edges.deinit();
    }
};

const Game = struct {
    components: StringArrayHashMap(Component),
    buffer: String,
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        assert(try file.readAll(buffer) == stat.size);

        var lines = splitAny(u8, buffer, "\n");
        var components = StringArrayHashMap(Component).init(allocator);
        while (lines.next()) |l| {
            const c = try Component.parse(l, allocator);
            try components.put(c.name, c);
        }

        // We have to allocate up-front, otherwise it will crash at rutime because the components will move
        try components.ensureUnusedCapacity(components.count());

        for (components.values()) |*component| {
            for (component.edges.keys()) |conn| {
                var entry = try components.getOrPut(conn);
                if (!entry.found_existing) {
                    entry.value_ptr.* = Component.empty(conn, allocator);
                }
                try entry.value_ptr.edges.put(component.name, {});
            }
        }

        return Game{
            .components = components,
            .buffer = buffer,
            .allocator = allocator,
        };
    }

    fn findCutOf3(self: *const Game) !usize {
        for (self.components.keys()) |k| {
            const cut = try self.findCutOf3From(k);
            if (cut != null) {
                return cut.?;
            }
        }

        unreachable;
    }

    fn findCutOf3From(self: *const Game, from: String) !?usize {
        var thisPart = StringHashSet.init(self.allocator);
        var thisOutbound = StringHashSet.init(self.allocator);
        var working = StringHashSet.init(self.allocator);
        defer {
            thisPart.deinit();
            thisOutbound.deinit();
            working.deinit();
        }

        try thisPart.put(from, {});
        for (self.components.getPtr(from).?.edges.keys()) |e| {
            try thisOutbound.put(e, {});
        }

        while (thisOutbound.count() > 0 and thisOutbound.count() != 3) {
            working.clearRetainingCapacity();

            for (thisOutbound.keys()) |c| {
                try thisPart.put(c, {});
            }

            for (thisOutbound.keys()) |c| {
                const component = self.components.getPtr(c).?;

                for (component.edges.keys()) |e| {
                    if (!thisPart.contains(e)) {
                        try working.put(e, {});
                    }
                }
            }

            std.mem.swap(StringHashSet, &thisOutbound, &working);
        }

        const all = self.components.count();
        if (thisOutbound.count() == 3 and thisPart.count() <= all / 2) {
            return thisPart.count() * (all - thisPart.count());
        } else {
            return null;
        }
    }

    fn deinit(self: *Game) void {
        for (self.components.values()) |*c| {
            c.deinit();
        }

        self.components.deinit();
        self.allocator.free(self.buffer);
    }
};

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var g = try Game.parseFile(file, allocator);
    defer g.deinit();

    const res = try g.findCutOf3();
    std.debug.print("Part 1: {any}\n", .{res});
}

pub fn part2() !void {}

pub fn main() !void {
    try part1();
    try part2();
}
