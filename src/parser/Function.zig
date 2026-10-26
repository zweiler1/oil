const std = @import("std");

const root = @import("../root.zig");
const handle = @import("handle.zig");

const Self = @This();
const Token = root.Token;
const Module = root.Module;
const Block = root.Block;

name: []const u8,
ret_ty: Token.Type,
params: handle.Slice(Param),
blocks: ?handle.Slice(Block),

pub const Handle = handle.Handle(Self, u32);

pub const Param = struct {
    name: []const u8,
    type: Token.Type,

    pub const Handle = handle.Handle(Param, u32);

    pub fn dump(self: *const Param, writer: *std.Io.Writer) !void {
        try writer.print("{s} %{s}", .{ @tagName(self.type), self.name });
    }
};

pub fn dump(self: *const Self, module: *const Module, writer: *std.Io.Writer) !void {
    if (self.blocks == null) {
        try writer.writeAll("declare ");
    } else {
        try writer.writeAll("define ");
    }
    try writer.print("{s} @{s}(", .{ @tagName(self.ret_ty), self.name });
    for (module.params.slice(self.params), 0..) |param, i| {
        try param.dump(writer);
        if (i > 0) {
            try writer.writeAll(", ");
        }
    }
    if (self.blocks == null) {
        try writer.writeAll(")\n");
        return;
    }
    try writer.writeAll(") {\n");
    const blocks = module.blocks.slice(self.blocks.?);
    for (blocks, 0..) |block, i| {
        try block.dump(module, writer);
        if (i + 1 < blocks.len) {
            try writer.writeByte('\n');
        }
    }
    try writer.writeAll("}\n\n");
}
