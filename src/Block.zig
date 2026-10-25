const std = @import("std");

const handle = @import("handle.zig");

const Self = @This();
const Module = @import("Module.zig");
const Instruction = @import("Instruction.zig");

name: []const u8,
instructions: handle.Slice(Instruction),

pub const Handle = handle.Handle(Self, u32);

pub fn dump(self: *const Self, module: *const Module, writer: *std.Io.Writer) !void {
    try writer.writeAll(self.name);
    try writer.writeAll(":\n");

    for (module.instructions.slice(self.instructions)) |instruction| {
        try instruction.dump(module, writer);
        try writer.writeByte('\n');
    }
}
