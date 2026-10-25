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

pub const Operand = struct {
    /// Function call operands have an additional type
    type: ?Token.Type = null,
    o: union(enum) {
        unresolved_global: []const u8, // @x
        unresolved_value: []const u8, // %x, the value could also refer to a parameter or to a block

        /// The callee to call in a function call. The first operand of a 'call' instruction is the function to call
        function: Function.Handle, // resolved @foo
        global: Global.Handle, // @x
        param: Function.Param.Handle, // %x
        block: Block.Handle, // br / phi
        value: Self.Handle, // %x
        @"align": u32, // align N

        imm_int: i64,
        imm_float: f64,
    },

    pub const Handle = handle.Handle(Operand, u32);
};
