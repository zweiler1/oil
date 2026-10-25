src: []const u8,
pos: usize,

const std = @import("std");

const Self = @This();

pub const Token = union(enum) {
    identifier: []const u8,
    number: []const u8,
    symbol: Symbol,
    keyword: Keyword,
    inst: Inst,
    type: Type,

    const Symbol = enum {
        eol,
        percent,
        at,

        comma,
        colon,
        equals,

        l_brace,
        r_brace,
        l_paren,
        r_paren,
    };

    const Keyword = enum {
        define,
        declare,
        global,
        label,
    };

    const Inst = enum {
        // Branching
        br,
        phi,

        // Calls
        call,
        ret,

        // Integer arithmetic
        add,
        sub,
        mul,
        sdiv,
        udiv,
        srem,
        urem,
        @"and",
        @"or",
        xor,
        shl,
        lshr,
        ashr,

        // Floating point arithmetic
        fadd,
        fsub,
        fmul,
        fdiv,

        // Integer comparisons
        icmp,
        eq,
        ne,
        slt,
        sle,
        sgt,
        sge,
        ult,
        ule,
        ugt,
        uge,

        // Floating point comparisons
        fcmp,
        olt,
        ole,
        ogt,
        oge,

        // Casts
        zext,
        sext,
        trunc,
        bitcast,
        ptrtoint,
        inttoptr,
        fptosi,
        sitofp,

        // Memory
        alloc,
        load,
        store,
        gep,
    };

    const Type = enum {
        ptr,
        void,
        i1,
        i8,
        i16,
        i32,
        i64,
        f32,
        f64,
    };

    pub fn format(self: *const Token, w: *std.Io.Writer) std.Io.Writer.Error!void {
        try w.print(".{{ .{s: <10} = ", .{@tagName(self.*)});
        switch (self.*) {
            .identifier => |identifier| try w.print("\"{s}\"", .{identifier}),
            .number => |number| try w.writeAll(number),
            .symbol => |sym| switch (sym) {
                .eol => try w.writeAll("'\\n'"),
                .percent => try w.writeAll("'%'"),
                .at => try w.writeAll("'@'"),

                .comma => try w.writeAll("','"),
                .colon => try w.writeAll("':'"),
                .equals => try w.writeAll("'='"),

                .l_brace => try w.writeAll("'{'"),
                .r_brace => try w.writeAll("'}'"),
                .l_paren => try w.writeAll("'('"),
                .r_paren => try w.writeAll("')'"),
            },
            .keyword => |kw| try w.writeAll(@tagName(kw)),
            .inst => |inst| try w.writeAll(@tagName(inst)),
            .type => |@"type"| try w.writeAll(@tagName(@"type")),
        }
        try w.writeAll(" }");
    }
};

pub fn init(src: []const u8) Self {
    return .{
        .src = src,
        .pos = 0,
    };
}

pub fn run(self: *Self, allocator: std.mem.Allocator) ![]Token {
    var tokens: std.ArrayList(Token) = .empty;
    defer tokens.deinit(allocator);

    self.pos = 0;
    while (self.pos < self.src.len) : (self.pos += 1) {
        try tokens.append(allocator, switch (self.peek().?) {
            else => {
                if (std.ascii.isWhitespace(self.peek().?)) {
                    continue;
                }
                std.log.err("UnexpectedToken: '{c}'", .{self.peek().?});
                return error.UnexpectedToken;
            },
            ';' => blk: {
                while (self.peek()) |next| {
                    if (next == '\n') {
                        break;
                    }
                    self.pos += 1;
                } else return error.UnexpectedEof;
                break :blk .{ .symbol = .eol };
            },
            '\n' => .{ .symbol = .eol },
            '%' => .{ .symbol = .percent },
            '@' => .{ .symbol = .at },
            ',' => .{ .symbol = .comma },
            ':' => .{ .symbol = .colon },
            '=' => .{ .symbol = .equals },
            '{' => .{ .symbol = .l_brace },
            '}' => .{ .symbol = .r_brace },
            '(' => .{ .symbol = .l_paren },
            ')' => .{ .symbol = .r_paren },
            'a'...'z', 'A'...'Z', '_' => blk: {
                // First get the whole identifier
                const start = self.pos;
                while (self.peek2()) |next| {
                    if (next != '_' and !std.ascii.isAlphanumeric(next)) {
                        break;
                    }
                    self.pos += 1;
                } else return error.UnexpectedEof;
                const identifier: []const u8 = self.src[start..(self.pos + 1)];

                if (std.meta.stringToEnum(Token.Keyword, identifier)) |kw| {
                    break :blk .{ .keyword = kw };
                } else if (std.meta.stringToEnum(Token.Inst, identifier)) |inst| {
                    break :blk .{ .inst = inst };
                } else if (std.meta.stringToEnum(Token.Type, identifier)) |@"type"| {
                    break :blk .{ .type = @"type" };
                } else {
                    break :blk .{ .identifier = identifier };
                }
            },
            '0'...'9' => blk: {
                const start = self.pos;
                var contains_dot: bool = false;
                while (self.peek2()) |next| {
                    if (next == '.' and !contains_dot) {
                        contains_dot = true;
                    } else if (!std.ascii.isDigit(next)) {
                        break;
                    }
                    self.pos += 1;
                } else return error.UnexpectedEof;
                const number: []const u8 = self.src[start..(self.pos + 1)];
                break :blk .{ .number = number };
            },
        });
    }
    return tokens.toOwnedSlice(allocator);
}

fn peek(self: *const Self) ?u8 {
    if (self.pos >= self.src.len) {
        return null;
    }
    return self.src[self.pos];
}

fn peek2(self: *const Self) ?u8 {
    if (self.pos + 1 >= self.src.len) {
        return null;
    }
    return self.src[self.pos + 1];
}
