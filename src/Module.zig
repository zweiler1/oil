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

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.globals.coll.deinit(allocator);

    self.functions.coll.deinit(allocator);
    self.params.coll.deinit(allocator);

    self.blocks.coll.deinit(allocator);

    self.instructions.coll.deinit(allocator);
    self.operands.coll.deinit(allocator);
}

pub fn dump(self: *const Self, writer: *std.Io.Writer) !void {
    for (self.globals.coll.items) |*global| {
        try global.dump(writer);
    }
    for (self.functions.coll.items) |*function| {
        try function.dump(self, writer);
    }
}
