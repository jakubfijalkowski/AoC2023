const std = @import("std");
const splitAny = std.mem.splitAny;
const splitSequence = std.mem.splitSequence;
const indexOf = std.mem.indexOf;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const StringHashMap = std.StringHashMap;
const AutoHashMap = std.AutoHashMap;
const Allocator = std.mem.Allocator;

const PulseType = enum { high, low };

const Outputs = ArrayList([]const u8);
const Pulse = struct { pulseType: PulseType, source: []const u8, target: []const u8, id: usize };
const Pulses = ArrayList(Pulse);

fn parseOutputs(data: []const u8, allocator: Allocator) !Outputs {
    var parts = splitAny(u8, data, ",");
    var outputs = Outputs.init(allocator);

    while (parts.next()) |p| {
        try outputs.append(trim(u8, p, " "));
    }

    return outputs;
}

const Receiver = struct {
    name: []const u8,
    outputs: Outputs,

    fn new(allocator: Allocator) Receiver {
        return Receiver{ .name = "rx", .outputs = Outputs.init(allocator) };
    }

    pub fn accept(self: *Receiver, pulse: Pulse, pulses: *Pulses) !void {
        _ = pulse;
        _ = self;
        _ = pulses;
    }

    fn deinit(self: *Receiver) void {
        self.outputs.deinit();
    }
};

const Broadcast = struct {
    name: []const u8,
    outputs: Outputs,

    pub fn parse(data: []const u8, allocator: Allocator) !Broadcast {
        var parts = splitSequence(u8, data, " -> ");
        var name = parts.next().?;
        var outputs = try parseOutputs(parts.next().?, allocator);
        return Broadcast{
            .name = name,
            .outputs = outputs,
        };
    }

    pub fn accept(self: *Broadcast, pulse: Pulse, pulses: *Pulses) !void {
        for (self.outputs.items) |o| {
            try pulses.append(Pulse{
                .pulseType = pulse.pulseType,
                .source = self.name,
                .target = o,
                .id = pulse.id,
            });
        }
    }

    fn deinit(self: *Broadcast) void {
        self.outputs.deinit();
    }
};

const FlipFlop = struct {
    name: []const u8,
    state: bool,
    outputs: Outputs,

    pub fn parse(data: []const u8, allocator: Allocator) !FlipFlop {
        var parts = splitSequence(u8, data, " -> ");
        var name = parts.next().?[1..];
        var outputs = try parseOutputs(parts.next().?, allocator);
        return FlipFlop{
            .name = name,
            .state = false,
            .outputs = outputs,
        };
    }

    pub fn accept(self: *FlipFlop, pulse: Pulse, pulses: *Pulses) !void {
        if (pulse.pulseType == PulseType.low) {
            self.state = !self.state;

            for (self.outputs.items) |o| {
                try pulses.append(Pulse{
                    .pulseType = if (self.state) PulseType.high else PulseType.low,
                    .source = self.name,
                    .target = o,
                    .id = pulse.id,
                });
            }
        }
    }

    fn deinit(self: *FlipFlop) void {
        self.outputs.deinit();
    }
};

const Conjunction = struct {
    name: []const u8,
    inputs: StringHashMap(PulseType),
    lastReceived: ?Pulse,
    outputs: Outputs,

    pub fn parse(data: []const u8, allocator: Allocator) !Conjunction {
        var parts = splitSequence(u8, data, " -> ");
        var name = parts.next().?[1..];
        var outputs = try parseOutputs(parts.next().?, allocator);
        return Conjunction{
            .name = name,
            .inputs = StringHashMap(PulseType).init(allocator),
            .lastReceived = null,
            .outputs = outputs,
        };
    }

    pub fn accept(self: *Conjunction, pulse: Pulse, pulses: *Pulses) !void {
        try self.inputs.put(pulse.source, pulse.pulseType);

        var isAllHigh = true;
        var valueIter = self.inputs.valueIterator();
        while (valueIter.next()) |v| {
            isAllHigh = isAllHigh and v.* == PulseType.high;
        }

        for (self.outputs.items) |o| {
            try pulses.append(Pulse{
                .pulseType = if (isAllHigh) PulseType.low else PulseType.high,
                .source = self.name,
                .target = o,
                .id = pulse.id,
            });
        }

        self.lastReceived = pulse;
    }

    fn takeLastReceived(self: *Conjunction) ?Pulse {
        var tmp = self.lastReceived;
        self.lastReceived = null;
        return tmp;
    }

    fn deinit(self: *Conjunction) void {
        self.inputs.deinit();
        self.outputs.deinit();
    }
};

const ModuleType = enum { broadcast, flipFlop, conjunction, receiver };
const Module = union(ModuleType) {
    broadcast: Broadcast,
    flipFlop: FlipFlop,
    conjunction: Conjunction,
    receiver: Receiver,

    fn receiver(allocator: Allocator) Module {
        return Module{ .receiver = Receiver.new(allocator) };
    }

    fn parse(data: []const u8, allocator: Allocator) !Module {
        return switch (data[0]) {
            '%' => .{ .flipFlop = try FlipFlop.parse(data, allocator) },
            '&' => .{ .conjunction = try Conjunction.parse(data, allocator) },
            'r' => .{ .receiver = Receiver.new(allocator) },
            else => .{ .broadcast = try Broadcast.parse(data, allocator) },
        };
    }

    fn name(self: *const Module) []const u8 {
        return switch (self.*) {
            .broadcast => |*m| m.name,
            .flipFlop => |*m| m.name,
            .conjunction => |*m| m.name,
            .receiver => |*m| m.name,
        };
    }

    fn outputs(self: *const Module) *const Outputs {
        return switch (self.*) {
            .broadcast => |*m| &m.outputs,
            .flipFlop => |*m| &m.outputs,
            .conjunction => |*m| &m.outputs,
            .receiver => |*m| &m.outputs,
        };
    }

    pub fn accept(self: *Module, pulse: Pulse, pulses: *Pulses) !void {
        switch (self.*) {
            .broadcast => |*m| try m.accept(pulse, pulses),
            .flipFlop => |*m| try m.accept(pulse, pulses),
            .conjunction => |*m| try m.accept(pulse, pulses),
            .receiver => |*m| try m.accept(pulse, pulses),
        }
    }

    fn deinit(self: *Module) void {
        switch (self.*) {
            .broadcast => |*m| m.deinit(),
            .flipFlop => |*m| m.deinit(),
            .conjunction => |*m| m.deinit(),
            .receiver => |*m| m.deinit(),
        }
    }
};

const SimulationResult = struct { low: u64, high: u64 };

const Board = struct {
    rawData: []const u8,
    modules: StringHashMap(Module),
    allocator: Allocator,

    fn parseFile(file: std.fs.File, allocator: Allocator) !Board {
        const stat = try file.stat();
        var buffer = try allocator.alloc(u8, @as(usize, stat.size));
        assert(try file.readAll(buffer) == stat.size);

        var modules = StringHashMap(Module).init(allocator);
        var lines = splitAny(u8, buffer, "\n");
        while (lines.next()) |l| {
            var m = try Module.parse(l, allocator);
            try modules.put(m.name(), m);
        }

        var receiver = Module.receiver(allocator);
        try modules.put(receiver.name(), receiver);

        var modIter = modules.valueIterator();
        while (modIter.next()) |m| {
            for (m.outputs().items) |o| {
                var outputModule = modules.getPtr(o);
                if (outputModule != null) {
                    switch (outputModule.?.*) {
                        .conjunction => |*c| try c.inputs.put(m.name(), PulseType.low),
                        else => {},
                    }
                }
            }
        }

        return Board{
            .rawData = buffer,
            .modules = modules,
            .allocator = allocator,
        };
    }

    fn sendPulse(self: *const Board) !SimulationResult {
        var pulses = try Pulses.initCapacity(self.allocator, 100);
        defer pulses.deinit();

        pulses.appendAssumeCapacity(Pulse{
            .source = "button",
            .target = "broadcaster",
            .pulseType = PulseType.low,
            .id = 0,
        });

        var low: u64 = 0;
        var high: u64 = 0;

        while (pulses.items.len > 0) {
            var p = pulses.items[0];

            var m = self.modules.getPtr(p.target);
            if (m != null) {
                try m.?.accept(p, &pulses);
            }

            _ = pulses.orderedRemove(0);

            if (p.pulseType == PulseType.low) {
                low += 1;
            } else {
                high += 1;
            }
        }

        return SimulationResult{ .low = low, .high = high };
    }

    fn sendOneTo(self: *const Board, source: []const u8, output: []const u8, id: usize, receivedPulses: *Pulses) !void {
        var pulses = try Pulses.initCapacity(self.allocator, 100);
        defer pulses.deinit();

        pulses.appendAssumeCapacity(Pulse{
            .source = source,
            .target = output,
            .pulseType = PulseType.low,
            .id = id,
        });

        const target = switch (self.findLastConjunction().*) {
            .conjunction => |*c| c,
            else => unreachable,
        };

        while (pulses.items.len > 0) {
            var p = pulses.items[0];

            var m = self.modules.getPtr(p.target);
            if (m != null) {
                try m.?.accept(p, &pulses);
            }

            _ = pulses.orderedRemove(0);

            var rcv = target.takeLastReceived();
            if (rcv != null) {
                try receivedPulses.append(rcv.?);
            }
        }
    }

    fn findLastConjunction(self: *const Board) *Module {
        var iter = self.modules.iterator();
        while (iter.next()) |e| {
            for (e.value_ptr.outputs().items) |o| {
                if (std.mem.eql(u8, o, "rx")) {
                    return e.value_ptr;
                }
            }
        }
        unreachable;
    }

    fn deinit(self: *Board) void {
        var iter = self.modules.valueIterator();
        while (iter.next()) |v| {
            v.deinit();
        }
        self.modules.deinit();
        self.allocator.free(self.rawData);
    }
};

fn lcm(a: usize, b: usize) u64 {
    return a / std.math.gcd(a, b) * b;
}

pub fn part1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var g = try Board.parseFile(file, allocator);
    defer g.deinit();

    var result = SimulationResult{ .low = 0, .high = 0 };
    for (0..1000) |_| {
        const sr = try g.sendPulse();
        result.low += sr.low;
        result.high += sr.high;
    }

    std.debug.print("Part 1: {any}\n", .{result.low * result.high});
}

pub fn part2() !void {
    const TEST_PULSES: usize = 10000;

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("data.txt", .{});
    defer file.close();

    var g = try Board.parseFile(file, allocator);
    defer g.deinit();

    const b = g.modules.get("broadcaster").?;

    var pulses = try Pulses.initCapacity(allocator, TEST_PULSES);
    defer pulses.deinit();

    var repeated: usize = 1;

    for (b.outputs().items) |o| {
        pulses.clearRetainingCapacity();

        for (1..TEST_PULSES) |id| {
            try g.sendOneTo("broadcaster", o, id, &pulses);
        }

        for (pulses.items) |p| {
            if (p.pulseType == PulseType.high) {
                repeated = lcm(repeated, p.id);
                break;
            }
        }
    }

    std.debug.print("Part 2: {}\n", .{repeated});
}

pub fn main() !void {
    try part1();
    try part2();
}
