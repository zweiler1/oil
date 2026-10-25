const std = @import("std");

const handle = @import("handle.zig");

const Self = @This();
const Instruction = @import("Instruction.zig");

name: []const u8,
instructions: handle.Slice(Instruction),

pub const Handle = handle.Handle(Self, u32);
