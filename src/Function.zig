const std = @import("std");

const handle = @import("handle.zig");

const Self = @This();
const Token = @import("token.zig").Token;
const Block = @import("Block.zig");

name: []const u8,
ret_ty: Token.Type,
params: handle.Slice(Param),
blocks: ?handle.Slice(Block),

pub const Handle = handle.Handle(Self, u32);

pub const Param = struct {
    name: []const u8,
    type: Token.Type,

    pub const Handle = handle.Handle(Param, u32);
};
