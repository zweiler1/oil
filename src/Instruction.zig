const std = @import("std");

const handle = @import("handle.zig");

const Self = @This();
const Token = @import("token.zig").Token;
const Global = @import("Global.zig");
const Function = @import("Function.zig");
const Block = @import("Block.zig");

result: ?[]const u8,
operation: Token.Instruction,
type: Token.Type,
operands: handle.Slice(Operand),

pub const Handle = handle.Handle(Self, u32);

pub const Operand = union(enum) {
    global: Global.Handle,
    param: Function.Param.Handle,
    block: Block.Handle, // br / phi
    value: Self.Handle, // %x
    imm_int: i64,
    imm_float: f64,

    pub const Handle = handle.Handle(Operand, u32);
};
