const std = @import("std");
const Bytecode = std.ArrayList(u8);
const Value = @import("value.zig").Value;
const Constants = std.ArrayList(Value);

pub const Chunk = struct {
    code: Bytecode,
    constants: Constants,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Chunk {
        return Chunk{
            .code = Bytecode.init(allocator),
            .constants = Constants.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.constants.deinit();
        self.code.deinit();
    }

    fn addConstant(self: *Self, value: Value) ConstantIndex {
        const id = @as(u16, @intCast(self.constants.items.len));
        self.constants.append(value) catch unreachable;
        return .{ .index = id };
    }

    pub fn pushConstant(self: *Self, value: Value) void {
        const id = self.addConstant(value);
        self.code.append(id.words.low) catch unreachable;
        self.code.append(id.words.high) catch unreachable;
    }

    pub fn push(self: *Self, op: Operator) void {
        self.code.append(@intFromEnum(op)) catch unreachable;
    }

    pub fn getConstant(self: Self, ip: usize) Value {
        const index = ConstantIndex{
            .words = Words{
                .low = self.code.items[ip],
                .high = self.code.items[ip + 1],
            },
        };

        return self.constants.items[@as(usize, @intCast(index.index))];
    }
};

const ConstantIndex = packed union {
    index: u16,
    words: Words,
};
const Words = packed struct {
    low: u8,
    high: u8,
};

pub const Operator = enum {
    Return,
    Constant,
    True,
    False,
    Nil,
    Add,
    Sub,
    Mul,
    Mod,
    Div,
    Neg,
    Not,
    And,
    Or,
    Xor,
    Equal,
    NotEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
};
