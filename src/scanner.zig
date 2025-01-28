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
    ERROR,
};

const OptionalTokenData = struct {
    base: u5,
    fraction: u5,
};
pub const Token = struct {
    type: TokenType,
    chars: []const u8,
    line: usize,
    optionalData: ?OptionalTokenData,
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
        if ((scanner.currentLen() == start + length) and std.mem.eql(u8, word, rest)) return tt;
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
    fn makeToken(scanner: *Scanner, tt: TokenType, optionalData: ?OptionalTokenData) Token {
        return .{
            .type = tt,
            .chars = scanner.start[0..scanner.currentLen()],
            .line = scanner.line,
            .optionalData = optionalData,
        };
    }

    fn identifierType(scanner: *Scanner) TokenType {
        return switch (scanner.start[0]) {
            'a' => scanner.checkKeyword(1, 2, "nd", TokenType.And),
            'c' => scanner.checkKeyword(1, 4, "onst", TokenType.Const),
            'e' => scanner.checkKeyword(1, 3, "lse", TokenType.Else),
            'f' => {
                if (scanner.currentLen() <= 1) return TokenType.Identifier;
                return switch (scanner.start[1]) {
                    'a' => scanner.checkKeyword(2, 3, "lse", TokenType.False),
                    'o' => scanner.checkKeyword(2, 1, "r", TokenType.For),
                    'n' => scanner.checkKeyword(2, 0, "n", TokenType.Fn),
                    else => TokenType.Identifier,
                };
            },
            'i' => scanner.checkKeyword(1, 1, "f", TokenType.If),
            'l' => scanner.checkKeyword(1, 2, "et", TokenType.Let),
            'n' => scanner.checkKeyword(1, 2, "il", TokenType.Nil),
            'o' => scanner.checkKeyword(1, 1, "r", TokenType.OR),
            'r' => scanner.checkKeyword(1, 5, "eturn", TokenType.Return),
            't' => {
                if (scanner.currentLen() <= 1) return TokenType.Identifier;
                return switch (scanner.start[1]) {
                    'r' => scanner.checkKeyword(2, 2, "ue", TokenType.True),
                    else => TokenType.Identifier,
                };
            },
            'w' => scanner.checkKeyword(1, 4, "hile", TokenType.While),
            else => TokenType.Identifier,
        };
    }
    fn MakeIdentifierToken(scanner: *Scanner) Token {
        while (std.ascii.isAlphabetic(scanner.peek()) or std.ascii.isDigit(scanner.peek())) {
            _ = scanner.advance();
        }
        return scanner.makeToken(scanner.identifierType(), null);
    }

    fn MakeNumberToken(scanner: *Scanner) Token {
        var base: u5 = 10;
        var fraction: u5 = 0;

        if (scanner.peek() == '0') {
            _ = scanner.advance();
            const nextChar = scanner.peek();
            if (nextChar == 'x' or nextChar == 'X') {
                base = 16;
                _ = scanner.advance();
            } else if (nextChar == 'b' or nextChar == 'B') {
                base = 2;
                _ = scanner.advance();
            } else if (nextChar == 'o' or nextChar == 'O') {
                base = 8;
                _ = scanner.advance();
            } else {
                base = 10;
            }
        }

        while (std.ascii.isDigit(scanner.peek()) or (base == 16 and std.ascii.isHex(scanner.peek()))) {
            _ = scanner.advance();
        }

        if (base == 10 and scanner.peek() == '.' and std.ascii.isDigit(scanner.peekNext())) {
            _ = scanner.advance();
            while (std.ascii.isDigit(scanner.peek())) _ = scanner.advance();
            fraction = 1;
        }

        return scanner.makeToken(TokenType.Number, .{ .base = base, .fraction = fraction });
    }

    fn makeStringToken(scanner: *Scanner) Token {
        while (scanner.peek() != '"' and !scanner.isAtEnd()) {
            if (scanner.peek() == '\n') scanner.line += 1;
            _ = scanner.advance();
        }
        if (scanner.isAtEnd()) return scanner.makeErrorToken("Unterminated string.");
        _ = scanner.advance();
        return scanner.makeToken(TokenType.String, null);
    }

    fn makeErrorToken(scanner: *Scanner, msg: []const u8) Token {
        return Token{
            .type = TokenType.ERROR,
            .chars = msg,
            .line = scanner.line,
            .optionalData = null,
        };
    }
};

test "init" {
    const source = "abc";
    const scanner = Scanner.init(source);

    try std.testing.expectEqualStrings(scanner.source, source);
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

test "MakeIdentifierToken" {
    const source = "varName = 123";
    var scanner = Scanner.init(source);

    _ = scanner.advance();
    _ = scanner.advance();
    _ = scanner.advance();
    _ = scanner.advance();
    const token = scanner.MakeIdentifierToken();
    try std.testing.expectEqual(token.type, TokenType.Identifier);
    try std.testing.expectEqualStrings(token.chars, "varName");
}

test "MakeNumberToken for decimal" {
    const source = "123 0x1F 0b101 0o77";
    var scanner = Scanner.init(source);

    const token = scanner.MakeNumberToken();
    try std.testing.expectEqual(token.type, TokenType.Number);
    try std.testing.expectEqualStrings(token.chars, "123");
    try std.testing.expectEqual(token.optionalData.?.base, 10);
    try std.testing.expectEqual(token.optionalData.?.fraction, 0);
}

test "MakeNumberToken for hex" {
    const source = "0x1F";
    var scanner = Scanner.init(source);

    const token = scanner.MakeNumberToken();
    try std.testing.expectEqual(token.type, TokenType.Number);
    try std.testing.expectEqualStrings(token.chars, "0x1F");
    try std.testing.expectEqual(token.optionalData.?.base, 16);
    try std.testing.expectEqual(token.optionalData.?.fraction, 0);
}

test "MakeNumberToken for binary" {
    const source = "0b101";
    var scanner = Scanner.init(source);

    const token = scanner.MakeNumberToken();
    try std.testing.expectEqual(token.type, TokenType.Number);
    try std.testing.expectEqualStrings(token.chars, "0b101");
    try std.testing.expectEqual(token.optionalData.?.base, 2);
    try std.testing.expectEqual(token.optionalData.?.fraction, 0);
}

test "MakeNumberToken for octal" {
    const source = "0o77";
    var scanner = Scanner.init(source);

    const token = scanner.MakeNumberToken();
    try std.testing.expectEqual(token.type, TokenType.Number);
    try std.testing.expectEqualStrings(token.chars, "0o77");
    try std.testing.expectEqual(token.optionalData.?.base, 8);
    try std.testing.expectEqual(token.optionalData.?.fraction, 0);
}

test "MakeNumberToken for float" {
    const source = "123.456";
    var scanner = Scanner.init(source);

    const token = scanner.MakeNumberToken();
    try std.testing.expectEqual(token.type, TokenType.Number);
    try std.testing.expectEqualStrings(token.chars, "123.456");
    try std.testing.expectEqual(token.optionalData.?.base, 10);
    try std.testing.expectEqual(token.optionalData.?.fraction, 1);
}
