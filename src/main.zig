const std = @import("std");
const oil = @import("oil");

pub fn main(init: std.process.Init) !void {
    const file_content = try std.Io.Dir.cwd().readFileAlloc(init.io, "test.ll", init.gpa, .unlimited);
    defer init.gpa.free(file_content);

    var lexer: oil.Lexer = .init(file_content);
    const tokens: []const oil.Token = try lexer.run(init.gpa);
    defer init.gpa.free(tokens);

    for (tokens) |token| {
        std.log.info("token = {f}", .{token});
    }

    var parser: oil.Parser = .init(tokens);
    defer parser.deinit(init.gpa);
    try parser.parse(init.gpa);
}
