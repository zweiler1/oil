const std = @import("std");

const handle = @import("handle.zig");

const Self = @This();
const Global = @import("Global.zig");
const Function = @import("Function.zig");
const Block = @import("Block.zig");
const Instruction = @import("Instruction.zig");

globals: handle.Collection(Global) = .empty,

functions: handle.Collection(Function) = .empty,
params: handle.Collection(Function.Param) = .empty,

blocks: handle.Collection(Block) = .empty,

instructions: handle.Collection(Instruction) = .empty,
operands: handle.Collection(Instruction.Operand) = .empty,
