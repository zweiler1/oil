const std = @import("std");

pub fn Handle(comptime Tag: type, comptime T: type) type {
    _ = Tag;

    return enum(T) {
        _,

        const Self = @This();

        pub fn fromInt(int: T) Self {
            return @enumFromInt(int);
        }

        pub fn toInt(self: Self) T {
            return @intFromEnum(self);
        }
    };
}

pub fn Slice(comptime T: type) type {
    if (!@hasDecl(T, "Handle")) {
        @panic("Type " ++ @typeName(T) ++ " is missing decl 'Handle'");
    }
    return struct {
        len: u32,
        start: Handle(T, u32),
    };
}

pub fn Collection(comptime T: type) type {
    if (!@hasDecl(T, "Handle")) {
        @panic("Type " ++ @typeName(T) ++ " is missing decl 'Handle'");
    }
    return struct {
        coll: std.ArrayList(T),

        const Self = @This();

        pub const empty: Self = .{ .coll = .empty };

        /// Only call this function if you are no longer adding any elements to the collection
        /// as otherwise the returned pointer would be invalid.
        pub fn get(self: *Self, handle: Handle(T, u32)) *T {
            if (handle.toInt() >= self.coll.items.len) {
                @panic("Invalid handle");
            }
            return &self.coll.items[handle.toInt()];
        }

        /// Only call this function if you are no longer adding any elements to the collection
        /// as otherwise the returned slice would be invalid.
        pub fn slice(self: *Self, s: Slice(T)) []T {
            if (s.start.toInt() + s.len > self.coll.items.len) {
                @panic("Invalid slice handle");
            }
            return self.coll.items[s.start.toInt()..(s.start.toInt() + s.len)];
        }

        pub fn append(self: *Self, allocator: std.mem.Allocator, value: T) !Handle(T, u32) {
            try self.coll.append(allocator, value);
            return Handle(T, u32).fromInt(self.coll.items.len - 1);
        }
    };
}
