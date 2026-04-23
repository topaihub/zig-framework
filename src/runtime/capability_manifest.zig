const std = @import("std");
const contracts = @import("../contracts/root.zig");

pub fn renderCapabilityManifestJson(allocator: std.mem.Allocator, manifest: contracts.capability_manifest.CapabilityManifest) anyerror![]u8 {
    var buf: std.ArrayListUnmanaged(u8) = .empty;
    defer buf.deinit(allocator);
    const writer = buf.writer(allocator);
    try writeCapabilityManifestJson(writer, manifest);
    return allocator.dupe(u8, buf.items);
}

pub fn writeCapabilityManifestJson(writer: anytype, manifest: contracts.capability_manifest.CapabilityManifest) anyerror!void {
    try writer.writeByte('{');
    var first = true;
    for (manifest.groups) |group| {
        if (!first) try writer.writeByte(',');
        first = false;
        try writeJsonString(writer, group.key);
        try writer.writeByte(':');
        try writer.writeByte('[');
        for (group.items, 0..) |item, index| {
            if (index > 0) try writer.writeByte(',');
            try writeJsonString(writer, item);
        }
        try writer.writeByte(']');
    }
    for (manifest.flags) |flag| {
        if (!first) try writer.writeByte(',');
        first = false;
        try writeJsonString(writer, flag.key);
        try writer.writeByte(':');
        try writer.writeAll(if (flag.enabled) "true" else "false");
    }
    try writer.writeByte('}');
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

test "runtime helper renders capability manifest json" {
    const groups = [_]contracts.capability_manifest.CapabilityGroup{
        .{ .key = "adapters", .items = &.{ "cli", "http" } },
        .{ .key = "providers", .items = &.{"openai"} },
    };
    const flags = [_]contracts.capability_manifest.CapabilityFlag{
        .{ .key = "supportsAsyncTasks", .enabled = true },
        .{ .key = "supportsObservers", .enabled = false },
    };
    const manifest = contracts.capability_manifest.CapabilityManifest{
        .groups = groups[0..],
        .flags = flags[0..],
    };

    const json = try renderCapabilityManifestJson(std.testing.allocator, manifest);
    defer std.testing.allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"adapters\":[\"cli\",\"http\"]") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"supportsAsyncTasks\":true") != null);
}


