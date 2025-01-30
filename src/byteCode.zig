const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Value = @import("value.zig").Value;

pub const Chunk = struct {
    code: ArrayList(u8),
    lines: ArrayList(u32),
    constants: ArrayList(Value),
    const Self = @This();
    pub fn init(allocator: Allocator) Self {
        return Self{
            .code = ArrayList(u8).init(allocator),
            .lines = ArrayList(u32).init(allocator),
            .constants = ArrayList(Value).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.code.deinit();
        self.lines.deinit();
        self.constants.deinit();
    }

    pub fn write(self: *Self, byte: u8, line: u32) !void {
        try self.code.append(byte);
        try self.lines.append(line);
    }

    pub fn addConstant(self: *Self, value: Value) !i32 {
        try self.constants.append(value);
        return @as(i32, @intCast(self.constants.items.len)) - 1;
    }
};

pub const OpCode = enum {
    Constant,
    Nil,
    True,
    False,
    Pop,
    GetLocal,
    SetLocal,
    GetUpvalue,
    CloseUpvalue,
    SetUpvalue,
    GetGlobal,
    DefineGlobal,
    SetGlobal,
    Equal,
    Greater,
    Less,
    Add,
    Subtract,
    Multiply,
    Divide,
    Mod,
    Not,
    Negate,
    Print,
    Jump,
    JumpIfFalse,
    Loop,
    Call,
    Closure,
    Return,
};
