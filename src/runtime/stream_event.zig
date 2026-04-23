const std = @import("std");

pub fn renderJsonEvent(allocator: std.mem.Allocator, event_name: []const u8, seq: u64, data_json: []const u8) anyerror![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(allocator);
    const writer = buf.writer(allocator);
    try writer.writeByte('{');
    try appendJsonStringField(writer, "event", event_name, true);
    if (seq > 0) try appendJsonUnsignedField(writer, "seq", seq, false);
    try appendRawJsonField(writer, "data", data_json, false);
    try writer.writeByte('}');
    return allocator.dupe(u8, buf.items);
}

fn appendJsonStringField(writer: anytype, key: []const u8, value: []const u8, first: bool) anyerror!void {
    if (!first) try writer.writeByte(',');
    try writeJsonString(writer, key);
    try writer.writeByte(':');
    try writeJsonString(writer, value);
}

fn appendJsonUnsignedField(writer: anytype, key: []const u8, value: u64, first: bool) anyerror!void {
    if (!first) try writer.writeByte(',');
    try writeJsonString(writer, key);
    try writer.writeByte(':');
    try writer.print("{d}", .{value});
}

fn appendRawJsonField(writer: anytype, key: []const u8, value: []const u8, first: bool) anyerror!void {
    if (!first) try writer.writeByte(',');
    try writeJsonString(writer, key);
    try writer.writeByte(':');
    try writer.writeAll(value);
}

fn writeJsonString(writer: *std.Io.Writer, value: []const u8) anyerror!void {
    try writer.writeByte('"');
    for (value) |ch| {
        switch (ch) {
            '"' => try writer.writeAll("\\\""),
            '\\' => try writer.writeAll("\\\\"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                if (ch < 32) {
                    try writer.print("\\u00{x:0>2}", .{ch});
                } else {
                    try writer.writeByte(ch);
                }
            },
        }
    }
    try writer.writeByte('"');
}

test "render json event keeps event data shape" {
    const json = try renderJsonEvent(std.testing.allocator, "meta", 7, "{\"ok\":true}");
    defer std.testing.allocator.free(json);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"event\":\"meta\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"seq\":7") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"data\":{\"ok\":true}") != null);
}


