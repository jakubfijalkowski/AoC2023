const std = @import("std");
const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const indexOf = std.mem.indexOf;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const StringArrayHashMap = std.StringArrayHashMap;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;
const PriorityDequeue = std.PriorityDequeue;

const Category = enum {
    x,
    m,
    a,
    s,
    fn parse(data: []const u8) Category {
        if (data.len != 1) {
            unreachable;
        } else {
            return switch (data[0]) {
                'x' => Category.x,
                'm' => Category.m,
                'a' => Category.a,
                's' => Category.s,
                else => unreachable,
            };
        }
    }
};

const Result = enum { reject, accept };
const ActionType = enum { proceed, reject, accept };
const Action = union(ActionType) {
    proceed: []const u8,
    reject,
    accept,
    fn parse(act: []const u8) Action {
        if (std.mem.eql(u8, act, "A")) {
            return Action{ .accept = {} };
        } else if (std.mem.eql(u8, act, "R")) {
            return Action{ .reject = {} };
        } else {
            return Action{ .proceed = act };
        }
    }
};

const RuleType = enum { noCondition, greaterThan, lessThan };
const RulePayload = struct { value: u32, prop: Category, action: Action };
const Rule = union(RuleType) {
    noCondition: Action,
    greaterThan: RulePayload,
    lessThan: RulePayload,

    fn parse(data: []const u8) !Rule {
        var colon = indexOf(u8, data, ":");
        if (colon == null) {
            return Rule{
                .noCondition = Action.parse(data),
            };
        } else {
            var prop = Category.parse(data[0..1]);
            var value = try parseInt(u32, data[2..colon.?], 10);
            var action = Action.parse(data[(colon.? + 1)..]);
            var payload = RulePayload{ .value = value, .prop = prop, .action = action };
            if (data[1] == '<') {
                return Rule{
                    .lessThan = payload,
                };
            } else {
                return Rule{
                    .greaterThan = payload,
                };
            }
        }
    }

    fn run(self: *const Rule, data: *const Rating) ?Action {
        return switch (self.*) {
            .noCondition => |c| c,
            .greaterThan => |*c| if (data.get(c.*.prop) > c.*.value) c.*.action else null,
            .lessThan => |*c| if (data.get(c.*.prop) < c.*.value) c.*.action else null,
        };
    }
};

const Workflow = struct {
    rules: ArrayList(Rule),
    name: []const u8,

    fn parse(line: []const u8, allocator: Allocator) !Workflow {
        var condStart = indexOf(u8, line, "{").?;
        var name = line[0..condStart];

        var rules = ArrayList(Rule).init(allocator);
        var ruleParts = splitAny(u8, line[(condStart + 1)..(line.len - 1)], ",");
        while (ruleParts.next()) |p| {
            try rules.append(try Rule.parse(p));
        }
        return Workflow{
            .rules = rules,
            .name = name,
        };
    }

    fn run(self: *const Workflow, data: *const Rating) Action {
        for (self.rules.items) |r| {
            var res = r.run(data);
            if (res != null) {
                return res.?;
            }
        }
        unreachable;
    }

    fn deinit(self: *const Workflow) void {
        self.rules.deinit();
    }
};

const Workflows = struct {
    workflows: StringArrayHashMap(Workflow),

    fn parse(data: []const u8, allocator: Allocator) !Workflows {
        var workflowLines = splitAny(u8, data, "\n");
        var workflows = StringArrayHashMap(Workflow).init(allocator);
        while (workflowLines.next()) |w| {
            const wf = try Workflow.parse(w, allocator);
            try workflows.put(wf.name, wf);
        }
        return Workflows{ .workflows = workflows };
    }

    fn run(self: *const Workflows, data: *const Rating) Result {
        var action = Action{ .proceed = "in" };
        while (switch (action) {
            .proceed => true,
            else => false,
        }) {
            const name = switch (action) {
                .proceed => |n| n,
                else => unreachable,
            };
            const workflow = self.workflows.getPtr(name).?;
            action = workflow.run(data);
        }

        return switch (action) {
            .accept => Result.accept,
            .reject => Result.reject,
            else => unreachable,
        };
    }

    fn deinit(self: *Workflows) void {
        for (self.workflows.values()) |w| {
            w.deinit();
        }
        self.workflows.deinit();
    }
};

const Rating = struct {
    x: u32,
    m: u32,
    a: u32,
    s: u32,

    fn parse(line: []const u8) !Rating {
        var parts = splitAny(u8, line[1 .. line.len - 1], ",");
        return Rating{
            .x = try parseSingle(parts.next().?),
            .m = try parseSingle(parts.next().?),
            .a = try parseSingle(parts.next().?),
            .s = try parseSingle(parts.next().?),
        };
    }

    fn parseSingle(data: []const u8) !u32 {
        return try parseInt(u32, data[2..], 10);
    }

    fn get(self: *const Rating, prop: Category) u32 {
        return switch (prop) {
            Category.x => self.x,
            Category.m => self.m,
            Category.a => self.a,
            Category.s => self.s,
        };
    }

    fn sum(self: *const Rating) u32 {
        return self.x + self.m + self.a + self.s;
    }
};

const Game = struct {
    workflows: Workflows,
    ratings: ArrayList(Rating),
    buffer: []const u8,
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Game {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        assert(try file.readAll(buffer) == stat.size);

        var parts = splitSequence(u8, buffer, "\n\n");
        var workflows = try Workflows.parse(parts.next().?, allocator);

        var dataLines = splitAny(u8, parts.next().?, "\n");
        var ratings = ArrayList(Rating).init(allocator);
        while (dataLines.next()) |l| {
            try ratings.append(try Rating.parse(l));
        }

        return Game{
            .workflows = workflows,
            .ratings = ratings,
            .buffer = buffer,
            .allocator = allocator,
        };
    }

    fn run(self: *const Game) u32 {
        var result: u32 = 0;
        for (self.ratings.items) |r| {
            if (self.workflows.run(&r) == Result.accept) {
                result += r.sum();
            }
        }
        return result;
    }

    fn deinit(self: *Game) void {
        self.workflows.deinit();
        self.ratings.deinit();
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

    std.debug.print("Part 1: {}\n", .{g.run()});
}

pub fn part2() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var g = try Game.parseFile(file, allocator);
    defer g.deinit();
}

pub fn main() !void {
    try part1();
    try part2();
}
