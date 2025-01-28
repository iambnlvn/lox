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

    pub fn init(source: []const u8) Scanner {
        return .{
            .source = source,
            .start = source.ptr,
            .current = source.ptr,
            .line = 1,
        };
    }

    fn checkKeyword(scanner: *Scanner, start: usize, length: usize, rest: []const u8, tt: TokenType) TokenType {
        const word = scanner.start[start .. start + length];
        if ((scanner.currentLen(scanner) == start + length) and std.mem.eql(u8, word, rest)) return tt;
        return TokenType.Identifier;
    }
    fn isAtEnd(scanner: *Scanner) bool {
        return @intFromPtr(scanner.current) >= @intFromPtr(scanner.source.ptr) + scanner.source.len;
    }

    fn currentLen(scanner: *Scanner) usize {
        return @intFromPtr(scanner.current) - @intFromPtr(scanner.start);
    }
    fn match(scanner: *Scanner, expected: u8) bool {
        if (scanner.isAtEnd()) return false;
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
        if (scanner.isAtEnd()) return 0;
        return (scanner.current + 1)[0];
    }

    fn skipWhiteSpace(scanner: *Scanner) void {
        while (true) {
            switch (scanner.peek()) {
                ' ', '\r', '\t' => {
                    _ = scanner.advance();
                },
                '\n' => {
                    scanner.line += 1;
                    _ = scanner.advance();
                },
                '/' => {
                    if (scanner.peekNext() == '/') {
                        while (scanner.peek() != '\n' and !scanner.isAtEnd()) {
                            _ = scanner.advance();
                        }
                    } else {
                        break;
                    }
                },
                else => break,
            }
        }
    }
    fn makeToken(scanner: *Scanner, tt: TokenType) Token {
        return .{
            .type = tt,
            .chars = scanner.start[0..scanner.currentLen()],
            .line = scanner.line,
        };
    }
};

test "init" {
    const source = "abc";
    const scanner = Scanner.init(source);

    try std.testing.expect(std.mem.eql(u8, scanner.source, source));
    try std.testing.expect(scanner.start == source.ptr);
    try std.testing.expect(scanner.current == source.ptr);
    try std.testing.expect(scanner.line == 1);
}

test "match method" {
    const source = "abc";
    var scanner = Scanner.init(source);

    try std.testing.expect(scanner.match('a'));
    try std.testing.expect(scanner.current[0] == 'b');

    try std.testing.expect(!scanner.match('c'));
    try std.testing.expect(scanner.current[0] == 'b');

    try std.testing.expect(scanner.match('b'));
    try std.testing.expect(scanner.current[0] == 'c');

    try std.testing.expect(scanner.match('c'));
    try std.testing.expect(scanner.current == source.ptr + source.len);

    try std.testing.expect(!scanner.match('d'));
}

test "advance" {
    const source = "abc";
    var s = Scanner.init(source);

    try std.testing.expect(s.advance() == 'a');
    try std.testing.expect(s.advance() == 'b');
    try std.testing.expect(s.advance() == 'c');
    try std.testing.expect(s.isAtEnd());
}

test "peek" {
    const source = "abc";
    var s = Scanner.init(source);

    try std.testing.expect(s.peek() == 'a');
    _ = s.advance();
    try std.testing.expect(s.peek() == 'b');
    _ = s.advance();
    try std.testing.expect(s.peek() == 'c');
    _ = s.advance();
    try std.testing.expect(s.peek() == 0);
}

test "peekNext" {
    const source = "abc";
    var s = Scanner.init(source);

    try std.testing.expect(s.peekNext() == 'b');
    _ = s.advance();
    try std.testing.expect(s.peekNext() == 'c');
    _ = s.advance();
    try std.testing.expect(s.peekNext() == 0);
}
test "skipWhiteSpace" {
    const source = "  \n  \t  \r  \n ";
    var s = Scanner.init(source);

    s.skipWhiteSpace();
    try std.testing.expect(s.isAtEnd());
}
