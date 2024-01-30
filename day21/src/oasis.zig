const std = @import("std");
const splitAny = std.mem.splitAny;
const trim = std.mem.trim;
const assert = std.debug.assert;
const parseInt = std.fmt.parseInt;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

pub const OasisSequence = ArrayList(u64);

pub const OasisTriangle = struct {
    maxLen: usize,
    levels: ArrayList(OasisSequence),

    pub fn build(seq: OasisSequence, allocator: Allocator, maxLen: usize) !OasisTriangle {
        var triangle = OasisTriangle{
            .maxLen = maxLen,
            .levels = ArrayList(OasisSequence).init(allocator),
        };
        try triangle.levels.append(seq);
        while (!triangle.isLastZero()) {
            try triangle.buildNext(allocator);
        }
        return triangle;
    }

    pub fn appendNext(self: *const OasisTriangle) u64 {
        var x: u64 = 0;
        var i = @as(isize, @intCast(self.levels.items.len)) - 1;
        while (i >= 0) : (i -= 1) {
            var lvl = &self.levels.items[@intCast(i)];
            const y = lvl.items[lvl.items.len - 1];
            x = y + x;
            lvl.appendAssumeCapacity(x);
        }

        return x;
    }

    fn buildNext(self: *OasisTriangle, allocator: Allocator) !void {
        const last_level = self.levels.items[self.levels.items.len - 1];
        var next_level = try OasisSequence.initCapacity(allocator, self.maxLen);
        for (last_level.items[1..], 0..) |b, i| {
            next_level.appendAssumeCapacity(b - last_level.items[i]);
        }
        try self.levels.append(next_level);
    }

    fn isLastZero(self: *const OasisTriangle) bool {
        return std.mem.allEqual(u64, self.levels.items[self.levels.items.len - 1].items, 0);
    }

    pub fn deinit(self: *const OasisTriangle) void {
        for (self.levels.items) |l| {
            l.deinit();
        }
        self.levels.deinit();
    }
};
