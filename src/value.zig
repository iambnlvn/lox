const std = @import("std");
pub const Value = union(enum) {
    number: f64,
    bool: bool,
    nil: void,
    string: *String,

    pub fn fromNumber(n: f64) Value {
        return .{ .number = n };
    }

    pub fn isNumber(self: Value) bool {
        switch (self) {
            .number => return true,
            else => false,
        }
    }

    pub fn fromBool(b: bool) Value {
        return .{ .bool = b };
    }

    pub fn isBool(self: Value) bool {
        switch (self) {
            .bool => return true,
            else => false,
        }
    }

    pub fn fromNil() Value {
        return .{ .nil = {} };
    }

    pub fn isNil(self: Value) bool {
        switch (self) {
            .nil => return true,
            else => false,
        }
    }
    pub fn fromString(s: *String) Value {
        return .{ .string = s };
    }

    pub fn isString(self: Value) bool {
        switch (self) {
            .string => return true,
            else => false,
        }
    }
};

pub const String = struct {
    string: std.ArrayList(u8),

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .string = std.ArrayList(u8).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.string.deinit();
    }

    pub fn str(self: Self) []u8 {
        return self.string.items;
    }

    pub fn concat(self: *Self, otherStrings: []const []const u8) !void {
        var totalSize: usize = self.string.items.len;

        for (otherStrings) |otherStr| {
            totalSize += otherStr.len;
        }
        try self.string.ensureTotalCapacity(totalSize);

        for (otherStrings) |otherStr| {
            try self.string.appendSlice(otherStr);
        }
    }

    pub fn concatNTimes(self: *Self, other: []const u8, n: usize) !void {
        try self.string.ensureTotalCapacity(self.string.items.len + other.len);

        for (range(n)) |_| {
            try self.string.appendSlice(other);
        }
    }

    pub fn format(self: Self, writer: anytype) !void {
        return std.fmt.format(writer, "\"{s}\"", .{self.string.items});
    }
};

pub fn range(len: usize) []const void {
    return @as([*]void, undefined)[0..len];
}
