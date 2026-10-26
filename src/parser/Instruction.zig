const std = @import("std");

const root = @import("../root.zig");
const handle = @import("handle.zig");

const Self = @This();
const Token = root.Token;
const Module = root.Module;
const Global = root.Global;
const Function = root.Function;
const Block = root.Block;

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

    pub fn dump(self: *const Operand, module: *const Module, writer: *std.Io.Writer) !void {
        if (self.type) |t| {
            try writer.writeAll(@tagName(t));
            try writer.writeByte(' ');
        }
        switch (self.o) {
            .unresolved_global => |unresolved_global| try writer.print("@{s}", .{unresolved_global}),
            .unresolved_value => |unresolved_value| try writer.print("%{s}", .{unresolved_value}),
            .function => |function_handle| try writer.print("@{s}(", .{module.functions.get(function_handle).name}),
            .global => |global_handle| try writer.print("@{s}", .{module.globals.get(global_handle).name}),
            .param => |param_handle| try writer.print("%{s}", .{module.params.get(param_handle).name}),
            .block => |block_handle| try writer.print("%{s}", .{module.blocks.get(block_handle).name}),
            .value => |value_handle| try writer.print("%{s}", .{module.instructions.get(value_handle).result.?}),
            .@"align" => |@"align"| try writer.print("align {d}", .{@"align"}),
            .imm_int => |imm_int| try writer.printInt(imm_int, 10, .lower, .{}),
            .imm_float => |imm_float| try writer.printFloat(imm_float, .{}),
        }
    }
};

pub fn dump(self: *const Self, module: *const Module, writer: *std.Io.Writer) !void {
    const operands = module.operands.slice(self.operands);

    try writer.writeAll("  ");
    if (self.result) |result| {
        try writer.print("%{s} = ", .{result});
    }

    switch (self.operation) {
        .eq, .ne, .slt, .sle, .sgt, .sge, .ult, .ule, .ugt, .uge => try writer.writeAll("icmp "),
        .olt, .ole, .ogt, .oge => try writer.writeAll("fcmp "),
        else => {},
    }
    try writer.writeAll(@tagName(self.operation));
    try writer.writeByte(' ');

    if (self.operation == .br and self.operands.len == 1) {
        try writer.writeAll("label ");
        try operands[0].dump(module, writer);
        return;
    }

    try writer.writeAll(@tagName(self.type));
    try writer.writeByte(' ');

    switch (self.operation) {
        .call => {
            std.debug.assert(operands.len >= 1);
            try operands[0].dump(module, writer);
            try writer.writeByte('(');
            for (operands[1..], 1..) |operand, i| {
                try operand.dump(module, writer);
                if (i + 1 < operands.len) {
                    try writer.writeAll(", ");
                }
            }
            try writer.writeByte(')');
        },
        .br => {
            for (operands, 0..) |operand, i| {
                if (i > 0) {
                    try writer.writeAll("label ");
                }
                try operand.dump(module, writer);
                if (i + 1 < operands.len) {
                    try writer.writeAll(", ");
                }
            }
        },
        else => {
            for (operands, 0..) |operand, i| {
                try operand.dump(module, writer);
                if (i + 1 < operands.len) {
                    try writer.writeAll(", ");
                }
            }
        },
    }
}
