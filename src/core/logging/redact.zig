const std = @import("std");
const record_model = @import("record.zig");

pub const LogField = record_model.LogField;

pub const RedactMode = enum {
    off,
    safe,
    strict,
};

pub const REDACTED_VALUE = "[REDACTED]";

pub fn redactField(mode: RedactMode, field: LogField) LogField {
    if (!isSensitiveKey(mode, field.key)) {
        return field;
    }

    return .{
        .key = field.key,
        .value = .{ .string = REDACTED_VALUE },
    };
}

pub fn redactFields(mode: RedactMode, input: []const LogField, output: []LogField) []const LogField {
    std.debug.assert(output.len >= input.len);

    for (input, 0..) |field, index| {
        output[index] = redactField(mode, field);
    }

    return output[0..input.len];
}

pub fn isSensitiveKey(mode: RedactMode, key: []const u8) bool {
    if (mode == .off) {
        return false;
    }

    const safe_keys = [_][]const u8{
        "api_key",
        "apikey",
        "token",
        "authorization",
        "cookie",
        "password",
        "secret",
        "bearer",
    };

    for (safe_keys) |needle| {
        if (containsAsciiIgnoreCase(key, needle)) {
            return true;
        }
    }

    if (mode == .strict) {
        const strict_keys = [_][]const u8{
            "auth",
            "credential",
            "session",
            "pairing",
            "webhook",
        };

        for (strict_keys) |needle| {
            if (containsAsciiIgnoreCase(key, needle)) {
                return true;
            }
        }
    }

    return false;
}

fn containsAsciiIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) {
        return true;
    }
    if (needle.len > haystack.len) {
        return false;
    }

    var start: usize = 0;
    while (start + needle.len <= haystack.len) : (start += 1) {
        if (std.ascii.eqlIgnoreCase(haystack[start .. start + needle.len], needle)) {
            return true;
        }
    }

    return false;
}

test "safe mode redacts common secret field names" {
    try std.testing.expect(isSensitiveKey(.safe, "api_key"));
    try std.testing.expect(isSensitiveKey(.safe, "Authorization"));
    try std.testing.expect(isSensitiveKey(.safe, "bearer_token"));
    try std.testing.expect(!isSensitiveKey(.safe, "path"));
}

test "strict mode redacts broader auth-related field names" {
    try std.testing.expect(isSensitiveKey(.strict, "session_id"));
    try std.testing.expect(isSensitiveKey(.strict, "pairing_code"));
    try std.testing.expect(!isSensitiveKey(.off, "api_key"));
}

test "redact field replaces sensitive values with marker" {
    const field = LogField.string("api_key", "secret-value");
    const redacted = redactField(.safe, field);

    try std.testing.expectEqualStrings("api_key", redacted.key);
    try std.testing.expectEqualStrings(REDACTED_VALUE, redacted.value.string);
}
