const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;
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
