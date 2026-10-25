const std = @import("std");

const handle = @import("handle.zig");

const Self = @This();
const Token = @import("token.zig").Token;

name: []const u8,
type: Token.Type,
value: Value,

pub const Handle = handle.Handle(Self, u32);

pub const Value = union(enum) {
    imm_int: i64,
    imm_float: f64,
    imm_str: []const u8,
};

pub fn dump(self: *const Self, writer: *std.Io.Writer) !void {
    try writer.print("@{s} = global {s} ", .{ self.name, @tagName(self.type) });
    switch (self.value) {
        .imm_int => |imm_int| try writer.print("{d}\n", .{imm_int}),
        .imm_float => |imm_float| try writer.print("{d}\n", .{imm_float}),
        .imm_str => |imm_str| try writer.print("{s}\n", .{imm_str}),
    }
}
