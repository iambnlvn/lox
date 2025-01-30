const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Value = @import("value.zig").Value;
const Chunk = @import("byteCode.zig").Chunk;

const ObjType = enum {
    string,
    function,
    native,
    closure,
    upvalue,
    class,
    instance,
    boundMethod,
};

pub const Object = struct {
    type: ObjType,
    isMarked: bool = false,
    next: ?*Object = null,

    pub fn init(objType: ObjType) Object {
        return .{ .type = objType };
    }
    pub fn updateNext(obj: *Object, head: *?*Object) void {
        if (head.*) |ob| {
            ob.next = obj;
        }
        head.* = obj;
    }

    pub fn equals(self: *Object, o: *Object) bool {
        return self == o;
    }
    // cast is a generic function that casts the object to the given type (to be tested)
    fn cast(self: *Object, comptime T: type) *T {
        const ptr = @as([*]Object, @ptrCast(self));
        return @as(*T, @as(@alignOf(T), @alignCast(ptr + 1)));
    }
    pub fn asString(self: *Object) *ObjectString {
        return self.cast(ObjectString);
    }

    pub fn asFunction(self: *Object) *ObjectFunction {
        return self.cast(ObjectFunction);
    }

    pub fn mark(self: *Object) void {
        if (self.isMarked) return;
        self.isMarked = true;
    }
};

pub const ObjectString = struct {
    data: []const u8,

    pub fn init(str: []const u8, allocator: Allocator, take: bool) ObjectString {
        const data = if (!take) blk: {
            const data = alloc(u8, allocator, str.len);
            @memcpy(data, str);
            break :blk data;
        } else b: {
            break :b str;
        };

        return ObjectString{ .data = data };
    }

    pub fn deinit(self: *ObjectString, allocator: Allocator) void {
        allocator.free(self.data);
    }
    pub fn format(
        self: ObjectString,
        writer: Writer,
    ) !void {
        comptime {
            _ = @field(writer, "print");
        }
        writer.print("{s}", .{self.data});
    }
};

pub const ObjectFunction = struct {
    arity: u8 = 0,
    upvalueCount: u8 = 0,
    chunk: Chunk,
    name: ?*ObjectString = null,

    pub fn init(allocator: Allocator) ObjectFunction {
        const chunk = Chunk.init(allocator);
        return .{ .chunk = chunk };
    }

    pub fn deinit(self: *ObjectFunction) void {
        self.chunk.deinit();
    }

    pub fn format(
        self: ObjectFunction,
        writer: Writer,
    ) void {
        if (self.name) |name| {
            writer.print("<fn {s}>", .{name});
        } else {
            writer.print("<script>", .{});
        }
    }
};

pub const NativeFn = fn (argCount: u8, args: [*]Value) Value;

pub const NativeObject = struct {
    function: NativeFn,

    pub fn init(function: NativeFn) NativeObject {
        return NativeObject{ .function = function };
    }

    pub fn format(
        _: NativeObject,
        writer: Writer,
    ) void {
        writer.print("<native fn>", .{});
    }
};

pub fn alloc(comptime T: type, allocator: Allocator, length: usize) []T {
    return allocator.alloc(T, length) catch {
        @panic("Allocation failed");
    };
}

pub const Writer = struct {
    print: fn (comptime format: []const u8, args: anytype) void,
};
// this function is used to test the format method
fn customPrint(comptime format: []const u8, args: anytype) void {
    std.debug.print(format, args);
    return;
}

test "Object.init" {
    const obj = Object.init(ObjType.string);
    try testing.expect(obj.type == ObjType.string);
}

test "Object.updateNext" {
    var obj1 = Object.init(ObjType.string);
    var obj2 = Object.init(ObjType.function);
    var head: ?*Object = null;
    Object.updateNext(&obj1, &head);
    try testing.expect(head == &obj1);
    Object.updateNext(&obj2, &head);
    try testing.expect(head == &obj2);
    try testing.expect(obj1.next == &obj2);
}

test "Object.equals" {
    var obj1 = Object.init(ObjType.string);
    var obj2 = Object.init(ObjType.string);
    try testing.expect(obj1.equals(&obj1));
    try testing.expect(!obj1.equals(&obj2));
}

test "Object.mark" {
    var obj = Object.init(ObjType.string);
    try testing.expect(!obj.isMarked);
    obj.mark();
    try testing.expect(obj.isMarked);
}

test "ObjectString.init and deinit" {
    const allocator = testing.allocator;
    var str = ObjectString.init("Hello, World!", allocator, false);
    try testing.expectEqualStrings(str.data, "Hello, World!");
    str.deinit(allocator);
}
test "ObjectString.format" {
    const allocator = testing.allocator;
    var str = ObjectString.init("Hello, World!\n", allocator, false);
    const writer = Writer{
        .print = customPrint,
    };
    try str.format(writer);
    str.deinit(allocator);
}

test "ObjectFunction init and deinit" {
    const allocator = testing.allocator;
    var objFn = ObjectFunction.init(allocator);
    defer objFn.deinit();

    try std.testing.expect(objFn.arity == 0);
    try std.testing.expect(objFn.upvalueCount == 0);
    try std.testing.expect(objFn.name == null);
}

fn testNativeFn(argCount: u8, args: [*]Value) Value {
    _ = args;
    return Value{ .number = @as(f64, @floatFromInt(argCount)) };
}

fn testPrint(comptime format: []const u8, args: anytype) void {
    std.debug.print(format, args);
}

test "NativeObject.init" {
    const nativeObj = NativeObject.init(testNativeFn);
    try testing.expect(@TypeOf(nativeObj.function) == @TypeOf(testNativeFn));
}

test "NativeObject.format" {
    const nativeObj = NativeObject.init(testNativeFn);
    const writer = Writer{
        .print = testPrint,
    };
    nativeObj.format(writer);
}

test "NativeObject function call" {
    const nativeObj = NativeObject.init(testNativeFn);
    var args: [1]Value = undefined;
    const result = nativeObj.function(1, &args);
    try testing.expectEqual(@as(f64, 1.0), result.number);
}

test "ObjectFunction - initialization and deinitialization" {
    const allocator = testing.allocator;
    var func = ObjectFunction.init(allocator);
    defer func.deinit();

    try testing.expectEqual(@as(u8, 0), func.arity);
    try testing.expectEqual(@as(u8, 0), func.upvalueCount);
    try testing.expect(func.name == null);
}

//TODO!: fix the following tests
// test "ObjectFunction - format unnamed function" {
//     const allocator = testing.allocator;
//     var func = ObjectFunction.init(allocator);
//     defer func.deinit();

//     const writer = Writer{ .print = testPrint };
//     func.format(writer);
// }

// test "ObjectFunction - format named function" {
//     const allocator = testing.allocator;
//     var func = ObjectFunction.init(allocator);
//     defer func.deinit();

//     var nameStr = ObjectString.init("test", allocator, false);
//     defer nameStr.deinit(allocator);

//     func.name = &nameStr;

//     const writer = Writer{ .print = testPrint };
//     func.format(writer);
// }

test "ObjectFunction - arity and upvalue manipulation" {
    const allocator = testing.allocator;
    var func = ObjectFunction.init(allocator);
    defer func.deinit();

    func.arity = 2;
    func.upvalueCount = 3;

    try testing.expectEqual(@as(u8, 2), func.arity);
    try testing.expectEqual(@as(u8, 3), func.upvalueCount);
}
