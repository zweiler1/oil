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
