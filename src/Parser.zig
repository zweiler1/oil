const std = @import("std");

const handle = @import("handle.zig");

const Self = @This();
const Token = @import("token.zig").Token;
const Module = @import("Module.zig");
const Global = @import("Global.zig");
const Function = @import("Function.zig");
const Block = @import("Block.zig");
const Instruction = @import("Instruction.zig");

const ExpectOptions = struct {
    /// Whether to advance when expecting a value
    adv: bool = true,
    /// Whether there even should be an output when erroring
    silent: bool = false,
};

tokens: []const Token,
pos: usize,
module: Module,

pub fn init(tokens: []const Token) Self {
    return .{
        .tokens = tokens,
        .pos = 0,
        .module = .{},
    };
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    self.module.deinit(allocator);
}

pub fn parse(self: *Self, allocator: std.mem.Allocator) !void {
    while (self.peek()) |next| {
        _ = try self.expectTag(.keyword, .{ .adv = false });
        switch (next.keyword) {
            .global => try self.parseGlobal(allocator),
            .define, .declare => try self.parseFunction(allocator),
            else => return error.UnexpectedToken,
        }
    }
}

fn err(e: anyerror, comptime format: []const u8, args: anytype) anyerror!void {
    std.log.err(format, args);
    return e;
}

fn skipEols(self: *Self) void {
    while (self.pos < self.tokens.len) {
        const curr = self.tokens[self.pos];
        if (curr != .symbol or curr.symbol != .eol) {
            break;
        }
        self.pos += 1;
    }
}

fn peek(self: *Self) ?Token {
    self.skipEols();
    if (self.pos >= self.tokens.len) {
        return null;
    }
    return self.tokens[self.pos];
}

fn advance(self: *Self) ?Token {
    self.skipEols();
    defer self.pos += 1;
    return self.peek();
}

fn expectTag(self: *Self, comptime expected: Token.Tag, options: ExpectOptions) !switch (expected) {
    .identifier => []const u8,
    .number => []const u8,
    .symbol => Token.Symbol,
    .keyword => Token.Keyword,
    .instruction => Token.Instruction,
    .type => Token.Type,
} {
    const tok = blk: {
        break :blk if (options.adv)
            self.advance()
        else
            self.peek();
    } orelse return error.UnexpectedEof;
    if (std.meta.activeTag(tok) != expected) {
        if (options.silent) {
            return error.UnexpectedToken;
        }
        try err(error.UnexpectedToken, "Expected {s} but got {f}", .{ @tagName(expected), tok });
        unreachable;
    }
    return switch (expected) {
        .identifier => tok.identifier,
        .number => tok.number,
        .symbol => tok.symbol,
        .keyword => tok.keyword,
        .instruction => tok.instruction,
        .type => tok.type,
    };
}

fn expect(self: *Self, expected: Token, options: ExpectOptions) !Token {
    const tok = blk: {
        break :blk if (options.adv)
            self.advance()
        else
            self.peek();
    } orelse return error.UnexpectedEof;
    const expected_str: []const u8 = switch (expected) {
        .identifier => "identifier",
        .number => "number",
        .symbol => |sym| switch (sym) {
            .eol => "'\\n'",
            .percent => "'%'",
            .at => "'@'",
            .comma => "','",
            .colon => "':'",
            .equals => "'='",
            .l_brace => "'{'",
            .r_brace => "'}'",
            .l_paren => "'('",
            .r_paren => "')'",
        },
        .keyword => |keyword| switch (keyword) {
            .@"align" => "'align'",
            .define => "'define'",
            .declare => "'declare'",
            .global => "'global'",
            .label => "'label'",
        },
        .instruction => "instruction",
        .type => "type",
    };
    if (std.meta.activeTag(tok) != std.meta.activeTag(expected) or switch (std.meta.activeTag(tok)) {
        .identifier => !std.mem.eql(u8, tok.identifier, expected.identifier),
        .number => !std.mem.eql(u8, tok.number, expected.number),
        .symbol => tok.symbol != expected.symbol,
        .keyword => tok.keyword != expected.keyword,
        .instruction => tok.instruction != expected.instruction,
        .type => tok.type != expected.type,
    }) {
        if (options.silent) {
            return error.UnexpectedToken;
        }
        try err(error.UnexpectedToken, "Expected {s} but got {f}", .{ expected_str, tok });
        unreachable;
    }
    return tok;
}

fn parseGlobal(self: *Self, allocator: std.mem.Allocator) !void {
    _ = allocator;
    _ = try self.expect(.{ .keyword = .global }, .{});
    const ty = try self.expectTag(.type, .{});
    _ = ty;
    return error.TODO;
}

fn parseFunction(self: *Self, allocator: std.mem.Allocator) !void {
    const is_definition = switch (try self.expectTag(.keyword, .{})) {
        .define => true,
        .declare => false,
        else => return error.UnexpectedToken,
    };

    const ret_ty = try self.expectTag(.type, .{});
    _ = try self.expect(.{ .symbol = .at }, .{});
    const name = try self.expectTag(.identifier, .{});
    _ = try self.expect(.{ .symbol = .l_paren }, .{});

    const params_list = &self.module.params;
    var params: handle.Slice(Function.Param) = .{
        .len = 0,
        .start = .fromInt(@intCast(params_list.coll.items.len)),
    };
    while (true) {
        if (self.peek().? == .symbol and self.peek().?.symbol == .r_paren) {
            break;
        }
        const param_type = try self.expectTag(.type, .{});
        const param_name: []const u8 = blk: {
            if (is_definition) {
                _ = try self.expect(.{ .symbol = .percent }, .{});
                break :blk try self.expectTag(.identifier, .{});
            }
            break :blk &.{};
        };
        _ = try params_list.append(allocator, .{
            .name = param_name,
            .type = param_type,
        });
        params.len += 1;

        _ = self.expect(.{ .symbol = .comma }, .{ .adv = false, .silent = true }) catch {
            break;
        };
        _ = self.advance();
    }
    _ = try self.expect(.{ .symbol = .r_paren }, .{});

    _ = try self.module.functions.append(allocator, .{
        .name = name,
        .ret_ty = ret_ty,
        .params = params,
        .blocks = if (!is_definition) null else blk: {
            _ = try self.expect(.{ .symbol = .l_brace }, .{});
            const _blocks = try self.parseBody(allocator);
            _ = try self.expect(.{ .symbol = .r_brace }, .{});
            break :blk _blocks;
        },
    });
}

fn parseBody(self: *Self, allocator: std.mem.Allocator) !handle.Slice(Block) {
    const block_name = try self.expectTag(.identifier, .{});
    _ = try self.expect(.{ .symbol = .colon }, .{});

    const blocks_list = &self.module.blocks;
    const instructions_list = &self.module.instructions;
    const operands_list = &self.module.operands;

    const entry_block = try blocks_list.append(allocator, .{
        .name = block_name,
        .instructions = .{
            .len = 0,
            .start = .fromInt(@intCast(instructions_list.coll.items.len)),
        },
    });
    var blocks: handle.Slice(Block) = .{
        .len = 1,
        .start = entry_block,
    };

    var curr_block: *Block = blocks_list.get(entry_block);
    while (true) {
        switch (self.peek() orelse return error.UnexpectedEof) {
            .identifier => |next_block_name| {
                // Start of a new block, add all accumulated instructions to the current block, then add a new block and clean up the instructions slice
                _ = self.advance();
                _ = try self.expect(.{ .symbol = .colon }, .{});

                const new_block = try blocks_list.append(allocator, .{
                    .name = next_block_name,
                    .instructions = .{
                        .len = 0,
                        .start = .fromInt(@intCast(instructions_list.coll.items.len)),
                    },
                });
                curr_block = blocks_list.get(new_block);
                blocks.len += 1;
                continue;
            },
            .symbol => |symbol| switch (symbol) {
                .percent => {
                    // Instruction line with result value found
                    _ = self.advance();
                    const result_name = try self.expectTag(.identifier, .{});
                    _ = try self.expect(.{ .symbol = .equals }, .{});
                    var operation = try self.expectTag(.instruction, .{});

                    var optype: Token.Type = undefined;
                    var operands: handle.Slice(Instruction.Operand) = .{
                        .len = 0,
                        .start = .fromInt(@intCast(operands_list.coll.items.len)),
                    };

                    switch (operation) {
                        .store, .br, .phi, .ret => {
                            try err(
                                error.InstructionCannotHaveBoundResultValue,
                                "The instruction {s} cannot be bound to a result value",
                                .{@tagName(operation)},
                            );
                            unreachable;
                        },

                        // Calls
                        .call => {
                            optype = try self.expectTag(.type, .{});
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                            _ = try self.expect(.{ .symbol = .l_paren }, .{});
                            while (true) {
                                if (self.peek().? == .symbol and self.peek().?.symbol == .r_paren) {
                                    break;
                                }

                                const arg_type = try self.expectTag(.type, .{});
                                const arg = operands_list.get(try self.parseOperand(allocator));
                                operands.len += 1;
                                arg.type = arg_type;

                                _ = self.expect(.{ .symbol = .comma }, .{ .adv = false, .silent = true }) catch {
                                    break;
                                };
                            }
                            _ = try self.expect(.{ .symbol = .r_paren }, .{});
                        },

                        // Integer arithmetic
                        .add,
                        .sub,
                        .mul,
                        .sdiv,
                        .udiv,
                        .srem,
                        .urem,
                        .@"and",
                        .@"or",
                        .xor,
                        .shl,
                        .lshr,
                        .ashr,
                        // Floating point arithmetic
                        .fadd,
                        .fsub,
                        .fmul,
                        .fdiv,
                        => {
                            optype = try self.expectTag(.type, .{});
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                            _ = try self.expect(.{ .symbol = .comma }, .{});
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                        },

                        // Integer comparisons
                        .icmp => {
                            operation = try self.expectTag(.instruction, .{});
                            optype = try self.expectTag(.type, .{});
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                            _ = try self.expect(.{ .symbol = .comma }, .{});
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                        },
                        .eq, .ne, .slt, .sle, .sgt, .sge, .ult, .ule, .ugt, .uge => {
                            try err(
                                error.IcmpInstWithoutIcmpPrefix,
                                "The instruction {s} needs to be prefixed by the 'icmp' instruction",
                                .{@tagName(operation)},
                            );
                            unreachable;
                        },

                        // Floating point comparisons
                        .fcmp => {
                            operation = try self.expectTag(.instruction, .{});
                            optype = try self.expectTag(.type, .{});
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                            _ = try self.expect(.{ .symbol = .comma }, .{});
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                        },
                        .olt, .ole, .ogt, .oge => {
                            try err(
                                error.FcmpInstWithoutFcmpPrefix,
                                "The instruction {s} needs to be prefixed by the 'fcmp' instruction",
                                .{@tagName(operation)},
                            );
                            unreachable;
                        },

                        // Casts
                        .zext, .sext, .trunc, .bitcast, .ptrtoint, .inttoptr, .fptosi, .sitofp => {
                            optype = try self.expectTag(.type, .{});
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                        },

                        // Memory
                        .alloc => {
                            optype = try self.expectTag(.type, .{});
                            return error.TODO;
                        },
                        .load => {
                            optype = try self.expectTag(.type, .{});
                            _ = try self.expect(.{ .symbol = .comma }, .{});
                            const ptr_type = try self.expectTag(.type, .{});
                            if (ptr_type != .ptr) {
                                try err(
                                    error.LoadInstOnlyAllowedOnPtrType,
                                    "The 'load' instructions first operand needs to be of type 'ptr', but got '{s}' instead",
                                    .{@tagName(ptr_type)},
                                );
                                unreachable;
                            }
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                            _ = try self.expect(.{ .symbol = .comma }, .{});
                            _ = try self.expect(.{ .keyword = .@"align" }, .{});
                            const alignment_str = try self.expectTag(.number, .{});
                            const alignment = try std.fmt.parseInt(u32, alignment_str, 10);
                            _ = try operands_list.append(allocator, .{
                                .o = .{
                                    .@"align" = alignment,
                                },
                            });
                            operands.len += 1;
                        },
                        .gep => {
                            optype = try self.expectTag(.type, .{});
                            return error.TODO;
                        },
                    }
                    std.debug.assert(operation != .icmp and operation != .fcmp);

                    _ = try instructions_list.append(allocator, .{
                        .result = result_name,
                        .operation = operation,
                        .type = optype,
                        .operands = operands,
                    });
                    curr_block.instructions.len += 1;
                },
                // We are done with parsing the body
                .r_brace => break,
                else => {
                    try err(error.UnexpectedToken, "Expected '%' or '}}' but got {f}", .{self.peek().?});
                    unreachable;
                },
            },
            .instruction => |operation| {
                // Instruction line without result value found
                _ = self.advance();
                var optype: Token.Type = undefined;
                var operands: handle.Slice(Instruction.Operand) = .{
                    .len = 0,
                    .start = .fromInt(@intCast(operands_list.coll.items.len)),
                };
                switch (operation) {
                    .store => {
                        optype = try self.expectTag(.type, .{});
                        _ = try self.parseOperand(allocator);
                        operands.len += 1;
                        _ = try self.expect(.{ .symbol = .comma }, .{});
                        _ = try self.parseOperand(allocator);
                        operands.len += 1;
                    },
                    .ret => {
                        optype = try self.expectTag(.type, .{});
                        _ = try self.parseOperand(allocator);
                        operands.len += 1;
                    },
                    .br => {
                        if (self.peek().? == .keyword and self.peek().?.keyword == .label) {
                            // Single-label branch, by convention a single-label branches "type" is void while the conditional branches type is 'i1'
                            optype = .void;
                            _ = self.advance();
                            _ = try self.parseOperand(allocator);
                            operands.len += 1;
                        } else {
                            // Conditional branch
                            optype = try self.expectTag(.type, .{});
                            if (optype != .i1) {
                                try err(
                                    error.IncorrectTypeForCondBr,
                                    "Conditional branches can only have the type 'i1', but got '{s}'",
                                    .{@tagName(optype)},
                                );
                                unreachable;
                            }
                            _ = try self.parseOperand(allocator); // Condition
                            operands.len += 1;
                            _ = try self.expect(.{ .symbol = .comma }, .{});
                            _ = try self.expect(.{ .keyword = .label }, .{});
                            _ = try self.parseOperand(allocator); // True Block
                            operands.len += 1;
                            _ = try self.expect(.{ .symbol = .comma }, .{});
                            _ = try self.expect(.{ .keyword = .label }, .{});
                            _ = try self.parseOperand(allocator); // False Block
                            operands.len += 1;
                        }
                    },
                    .phi => {
                        return error.TODO;
                    },
                    .call => {
                        optype = try self.expectTag(.type, .{});
                        _ = try self.parseOperand(allocator);
                        operands.len += 1;
                        _ = try self.expect(.{ .symbol = .l_paren }, .{});
                        while (true) {
                            if (self.peek().? == .symbol and self.peek().?.symbol == .r_paren) {
                                break;
                            }

                            const arg_type = try self.expectTag(.type, .{});
                            const arg = operands_list.get(try self.parseOperand(allocator));
                            operands.len += 1;
                            arg.type = arg_type;

                            _ = self.expect(.{ .symbol = .comma }, .{ .adv = false, .silent = true }) catch {
                                break;
                            };
                        }
                        _ = try self.expect(.{ .symbol = .r_paren }, .{});
                    },

                    .eq, .ne, .slt, .sle, .sgt, .sge, .ult, .ule, .ugt, .uge => {
                        try err(
                            error.IcmpInstWithoutIcmpPrefix,
                            "The instruction {s} needs to be prefixed by the 'icmp' instruction",
                            .{@tagName(operation)},
                        );
                        unreachable;
                    },
                    .olt, .ole, .ogt, .oge => {
                        try err(
                            error.FcmpInstWithoutFcmpPrefix,
                            "The instruction {s} needs to be prefixed by the 'fcmp' instruction",
                            .{@tagName(operation)},
                        );
                        unreachable;
                    },

                    // Integer arithmetic
                    .add,
                    .sub,
                    .mul,
                    .sdiv,
                    .udiv,
                    .srem,
                    .urem,
                    .@"and",
                    .@"or",
                    .xor,
                    .shl,
                    .lshr,
                    .ashr,
                    // Floating point arithmetic
                    .fadd,
                    .fsub,
                    .fmul,
                    .fdiv,
                    // Integer comparisons
                    .icmp,
                    // Floating point comparisons
                    .fcmp,
                    // Casts
                    .zext,
                    .sext,
                    .trunc,
                    .bitcast,
                    .ptrtoint,
                    .inttoptr,
                    .fptosi,
                    .sitofp,
                    // Memory
                    .alloc,
                    .load,
                    .gep,
                    => {
                        try err(
                            error.InstructionMustHaveBoundResultValue,
                            "The result of instruction {s} must be bound to a result value",
                            .{@tagName(operation)},
                        );
                        unreachable;
                    },
                }
                _ = try instructions_list.append(allocator, .{
                    .result = null,
                    .operation = operation,
                    .type = optype,
                    .operands = operands,
                });
                curr_block.instructions.len += 1;
            },
            else => {
                try err(error.UnexpectedToken, "Expected 'block:', '%identifier =', '}}' or instruction but got {f}", .{self.peek().?});
                unreachable;
            },
        }
    }
    return blocks;
}

fn parseOperand(self: *Self, allocator: std.mem.Allocator) !Instruction.Operand.Handle {
    return switch (self.advance() orelse return error.UnexpectedEof) {
        .symbol => |symbol| switch (symbol) {
            .percent => try self.module.operands.append(allocator, .{
                .o = .{
                    .unresolved_value = try self.expectTag(.identifier, .{}),
                },
            }),
            .at => try self.module.operands.append(allocator, .{
                .o = .{
                    .unresolved_global = try self.expectTag(.identifier, .{}),
                },
            }),
            else => {
                try err(error.InvalidTokenForOperand, "Invalid token for operand: {f}", .{self.peek().?});
                unreachable;
            },
        },
        .number => |number| try self.module.operands.append(allocator, if (std.mem.containsAtLeastScalar2(u8, number, '.', 1)) .{
            .o = .{
                .imm_float = try std.fmt.parseFloat(f64, number),
            },
        } else .{
            .o = .{
                .imm_int = try std.fmt.parseInt(i64, number, 10),
            },
        }),
        else => {
            try err(error.InvalidTokenForOperand, "Invalid token for operand: {f}", .{self.peek().?});
            unreachable;
        },
    };
}
