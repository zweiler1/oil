const std = @import("std");

const Self = @This();
const Token = @import("token.zig").Token;

src: []const u8,
pos: usize,

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
                } else if (std.meta.stringToEnum(Token.Instruction, identifier)) |inst| {
                    break :blk .{ .instruction = inst };
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
