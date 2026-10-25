const std = @import("std");

pub const Token = union(enum) {
    identifier: []const u8,
    number: []const u8,
    symbol: Symbol,
    keyword: Keyword,
    instruction: Instruction,
    type: Type,

    pub const Tag = std.meta.FieldEnum(Token);

    pub const Symbol = enum {
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

    pub const Keyword = enum {
        @"align",
        define,
        declare,
        global,
        label,
    };

    pub const Instruction = enum {
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

    pub const Type = enum {
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
            .instruction => |inst| try w.writeAll(@tagName(inst)),
            .type => |@"type"| try w.writeAll(@tagName(@"type")),
        }
        try w.writeAll(" }");
    }
};
