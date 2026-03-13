const std = @import("std");
const record_model = @import("record.zig");
const sink_model = @import("sink.zig");

pub const LogRecord = record_model.LogRecord;
pub const LogSink = sink_model.LogSink;

pub const JsonlFileSink = struct {
    allocator: std.mem.Allocator,
    path: []u8,
    max_bytes: ?u64 = null,
    current_bytes: u64 = 0,
    degraded: bool = false,
    dropped_records: usize = 0,

    const Self = @This();

    const vtable = LogSink.VTable{
        .write = writeErased,
        .flush = flushErased,
        .deinit = deinitErased,
        .name = nameErased,
    };

    pub fn init(allocator: std.mem.Allocator, path: []const u8, max_bytes: ?u64) !Self {
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

    pub fn asLogSink(self: *Self) LogSink {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn write(self: *Self, record: *const LogRecord) void {
        self.writeInternal(record) catch {
            self.degraded = true;
            self.dropped_records += 1;
        };
    }

    pub fn flush(_: *Self) void {}

    fn writeInternal(self: *Self, record: *const LogRecord) !void {
        var rendered: std.ArrayListUnmanaged(u8) = .empty;
        defer rendered.deinit(self.allocator);

        try record.writeJson(rendered.writer(self.allocator));
        try rendered.append(self.allocator, '\n');

        if (self.max_bytes) |max_bytes| {
            if (self.current_bytes + rendered.items.len > max_bytes) {
                self.dropped_records += 1;
                return;
            }
        }

        try ensureParentDirectory(self.path);
        var file = try openAppendFile(self.path);
        defer file.close();

        try file.writeAll(rendered.items);
        self.current_bytes += rendered.items.len;
    }

    fn writeErased(ptr: *anyopaque, record: *const LogRecord) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.write(record);
    }

    fn flushErased(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.flush();
    }

    fn deinitErased(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }

    fn nameErased(_: *anyopaque) []const u8 {
        return "jsonl_file";
    }
};

fn currentSize(path: []const u8) u64 {
    const stat = std.fs.cwd().statFile(path) catch return 0;
    return stat.size;
}

fn ensureParentDirectory(path: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir_name| {
        try std.fs.cwd().makePath(dir_name);
    }
}

fn openAppendFile(path: []const u8) !std.fs.File {
    var file = std.fs.cwd().openFile(path, .{ .mode = .read_write }) catch |err| switch (err) {
        error.FileNotFound => try std.fs.cwd().createFile(path, .{ .read = true, .truncate = false }),
        else => return err,
    };

    try file.seekFromEnd(0);
    return file;
}

test "jsonl file sink creates parent directory and appends records" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);

    const log_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "logs", "app.jsonl" });
    defer std.testing.allocator.free(log_path);

    var sink = try JsonlFileSink.init(std.testing.allocator, log_path, 4096);
    defer sink.deinit();

    const record = LogRecord{
        .ts_unix_ms = 1,
        .level = .info,
        .subsystem = "config",
        .message = "updated",
    };
    sink.write(&record);
    sink.write(&record);

    const contents = try tmp_dir.dir.readFileAlloc(std.testing.allocator, "logs/app.jsonl", 4096);
    defer std.testing.allocator.free(contents);

    try std.testing.expect(std.mem.count(u8, contents, "\n") == 2);
    try std.testing.expect(std.mem.indexOf(u8, contents, "\"subsystem\":\"config\"") != null);
}

test "jsonl file sink respects max bytes limit" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);

    const log_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "limited.jsonl" });
    defer std.testing.allocator.free(log_path);

    var sink = try JsonlFileSink.init(std.testing.allocator, log_path, 80);
    defer sink.deinit();

    const record = LogRecord{
        .ts_unix_ms = 1,
        .level = .info,
        .subsystem = "runtime/dispatch",
        .message = "command finished with a long message",
    };

    sink.write(&record);
    sink.write(&record);

    try std.testing.expect(sink.dropped_records >= 1);
}
