const std = @import("std");

pub const TokenType = enum {
    LParen,
    RParen,
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    Comma,
    Dot,
    Minus,
    Plus,
    Semicolon,
    Slash,
    Star,
    Bang,
    BangEqual,
    Equal,
    EqualEqual,
    Greater,
    GreaterEqual,
    Less,
    LessEqual,
    Identifier,
    String,
    Number,
    And,
    OR,
    If,
    Else,
    While,
    For,
    Fn,
    Return,
    Let,
    Const,
    True,
    False,
    Nil,
    EOF,
};

pub const Token = struct {
    type: TokenType,
    chars: []const u8,
    line: usize,
};

pub const Scanner = struct {
    source: []const u8,
    start: [*]const u8,
    current: [*]const u8,
    line: usize,
};

pub fn init(source: []const u8) Scanner {
    return Scanner{
        .source = source,
        .start = source.ptr,
        .current = source.ptr,
        .line = 1,
    };
}

fn isAtEnd(scanner: *Scanner) bool {
    return @intFromPtr(scanner.current) >= @intFromPtr(scanner.source.ptr) + scanner.source.len;
}

fn match(scanner: *Scanner, expected: u8) bool {
    if (isAtEnd(scanner)) return false;
    if (scanner.current[0] != expected) return false;
    scanner.current += 1;
    return true;
}

fn advance(scanner: *Scanner) u8 {
    scanner.current += 1;
    return (scanner.current - 1)[0];
}
fn peek(scanner: *Scanner) u8 {
    return scanner.current[0];
}

fn peekNext(scanner: *Scanner) u8 {
    if (isAtEnd(scanner)) return 0;
    return (scanner.current + 1)[0];
}

fn skipWhiteSpace(scanner: *Scanner) void {
    while (true) {
        switch (peek(scanner)) {
            ' ', '\r', '\t' => {
                _ = advance(scanner);
            },
            '\n' => {
                scanner.line += 1;
                _ = advance(scanner);
            },
            '/' => {
                if (peekNext(scanner) == '/') {
                    while (peek(scanner) != '\n' and !isAtEnd(scanner)) {
                        _ = advance(scanner);
                    }
                } else {
                    break;
                }
            },
            else => break,
        }
    }
}

test "init" {
    const source = "abc";
    const scanner = init(source);

    try std.testing.expect(std.mem.eql(u8, scanner.source, source));
    try std.testing.expect(scanner.start == source.ptr);
    try std.testing.expect(scanner.current == source.ptr);
    try std.testing.expect(scanner.line == 1);
}

test "match method" {
    const source = "abc";
    var scanner = init(source);

    try std.testing.expect(match(&scanner, 'a'));
    try std.testing.expect(scanner.current[0] == 'b');

    try std.testing.expect(!match(&scanner, 'c'));
    try std.testing.expect(scanner.current[0] == 'b');

    try std.testing.expect(match(&scanner, 'b'));
    try std.testing.expect(scanner.current[0] == 'c');

    try std.testing.expect(match(&scanner, 'c'));
    try std.testing.expect(scanner.current == source.ptr + source.len);

    try std.testing.expect(!match(&scanner, 'd'));
}

test "advance" {
    const source = "abc";
    var s = init(source);

    try std.testing.expect(advance(&s) == 'a');
    try std.testing.expect(advance(&s) == 'b');
    try std.testing.expect(advance(&s) == 'c');
    try std.testing.expect(isAtEnd(&s));
}

test "peek" {
    const source = "abc";
    var s = init(source);

    try std.testing.expect(peek(&s) == 'a');
    _ = advance(&s);
    try std.testing.expect(peek(&s) == 'b');
    _ = advance(&s);
    try std.testing.expect(peek(&s) == 'c');
    _ = advance(&s);
    try std.testing.expect(peek(&s) == 0);
}

test "peekNext" {
    const source = "abc";
    var s = init(source);

    try std.testing.expect(peekNext(&s) == 'b');
    _ = advance(&s);
    try std.testing.expect(peekNext(&s) == 'c');
    _ = advance(&s);
    try std.testing.expect(peekNext(&s) == 0);
}
test "skipWhiteSpace" {
    const source = "  \n  \t  \r  \n ";
    var s = init(source);

    skipWhiteSpace(&s);
    try std.testing.expect(isAtEnd(&s));
}
