const std = @import("std");
const observer_model = @import("observer.zig");

pub const Observer = observer_model.Observer;

pub const JsonlFileObserver = struct {
    allocator: std.mem.Allocator,
    path: []u8,
    max_bytes: ?u64 = null,
    current_bytes: u64 = 0,
    dropped_events: usize = 0,
    flush_count: usize = 0,
    degraded: bool = false,

    const Self = @This();

    const vtable = Observer.VTable{
        .record = recordErased,
        .flush = flushErased,
    };

    pub fn init(allocator: std.mem.Allocator, path: []const u8, max_bytes: ?u64) anyerror!Self {
        var self = Self{
            .allocator = allocator,
            .path = try allocator.dupe(u8, path),
            .max_bytes = max_bytes,
        };
        self.current_bytes = currentSize(self.path);
        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.path);
    }

    pub fn asObserver(self: *Self) Observer {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn record(self: *Self, topic: []const u8, payload_json: []const u8) anyerror!void {
        self.recordInternal(topic, payload_json) catch {
            self.degraded = true;
            self.dropped_events += 1;
        };
    }

    pub fn flush(self: *Self) anyerror!void {
        self.flush_count += 1;
    }

    fn recordInternal(self: *Self, topic: []const u8, payload_json: []const u8) anyerror!void {
        var rendered: std.ArrayListUnmanaged(u8) = .empty;
        defer rendered.deinit(self.allocator);

        const writer = rendered.writer(self.allocator);
        try writer.writeAll("{\"topic\":");
        try writeJsonString(writer, topic);
        try writer.print(",\"tsUnixMs\":{d},\"payload\":", .{std.time.milliTimestamp()});
        try writer.writeAll(payload_json);
        try writer.writeAll("}\n");

        if (self.max_bytes) |max_bytes| {
            if (self.current_bytes + rendered.items.len > max_bytes) {
                self.dropped_events += 1;
                return;
            }
        }

        try ensureParentDirectory(self.path);
        var file = try openAppendFile(self.path);
        defer file.close();

        try file.writeAll(rendered.items);
        self.current_bytes += rendered.items.len;
    }

    fn recordErased(ptr: *anyopaque, topic: []const u8, payload_json: []const u8) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        try self.record(topic, payload_json);
    }

    fn flushErased(ptr: *anyopaque) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        try self.flush();
    }
};

fn currentSize(path: []const u8) u64 {
    const stat = std.fs.cwd().statFile(path) catch return 0;
    return stat.size;
}

fn ensureParentDirectory(path: []const u8) anyerror!void {
    if (std.fs.path.dirname(path)) |dir_name| {
        try std.fs.cwd().makePath(dir_name);
    }
}

fn openAppendFile(path: []const u8) anyerror!std.fs.File {
    var file = std.fs.cwd().openFile(path, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => try std.fs.cwd().createFile(path, .{ .read = true, .truncate = false }),
        else => return err,
    };
    try file.seekFromEnd(0);
    return file;
}

fn writeJsonString(writer: anytype, value: []const u8) anyerror!void {
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

test "jsonl file observer writes observer events" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);
    const file_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "events", "observer.jsonl" });
    defer std.testing.allocator.free(file_path);

    var observer = try JsonlFileObserver.init(std.testing.allocator, file_path, 4096);
    defer observer.deinit();

    try observer.record("task.succeeded", "{\"taskId\":\"task_01\"}");
    try observer.flush();

    const contents = try tmp_dir.dir.readFileAlloc(std.testing.allocator, "events/observer.jsonl", 4096);
    defer std.testing.allocator.free(contents);

    try std.testing.expectEqual(@as(usize, 1), observer.flush_count);
    try std.testing.expect(std.mem.indexOf(u8, contents, "\"topic\":\"task.succeeded\"") != null);
}
