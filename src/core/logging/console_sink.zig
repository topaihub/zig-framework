const std = @import("std");
const level_model = @import("level.zig");
const record_model = @import("record.zig");
const sink_model = @import("sink.zig");

pub const LogLevel = level_model.LogLevel;
pub const LogField = record_model.LogField;
pub const LogFieldValue = record_model.LogFieldValue;
pub const LogRecord = record_model.LogRecord;
pub const LogSink = sink_model.LogSink;

pub const ConsoleStyle = enum {
    pretty,
    compact,
    json,
};

pub const EmitFn = *const fn (ctx: *anyopaque, to_stderr: bool, bytes: []const u8) anyerror!void;

pub const ConsoleSink = struct {
    min_level: LogLevel = .info,
    style: ConsoleStyle = .pretty,
    stderr_for_warn_and_error: bool = true,
    degraded: bool = false,
    dropped_records: usize = 0,
    emitter_ctx: ?*anyopaque = null,
    emitter_fn: ?EmitFn = null,

    const Self = @This();

    const vtable = LogSink.VTable{
        .write = writeErased,
        .flush = flushErased,
        .deinit = deinitErased,
        .name = nameErased,
    };

    pub fn init(min_level: LogLevel, style: ConsoleStyle) Self {
        return .{
            .min_level = min_level,
            .style = style,
        };
    }

    pub fn setEmitter(self: *Self, ctx: *anyopaque, emit_fn: EmitFn) void {
        self.emitter_ctx = ctx;
        self.emitter_fn = emit_fn;
    }

    pub fn asLogSink(self: *Self) LogSink {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn deinit(_: *Self) void {}

    pub fn flush(_: *Self) void {}

    pub fn write(self: *Self, record: *const LogRecord) void {
        if (!self.min_level.allows(record.level)) {
            return;
        }

        var rendered: std.ArrayListUnmanaged(u8) = .empty;
        defer rendered.deinit(std.heap.page_allocator);

        self.renderRecord(record, &rendered) catch {
            self.degraded = true;
            self.dropped_records += 1;
            return;
        };

        const to_stderr = self.stderr_for_warn_and_error and
            (@intFromEnum(record.level) >= @intFromEnum(LogLevel.warn));

        self.emit(to_stderr, rendered.items) catch {
            self.degraded = true;
            self.dropped_records += 1;
        };
    }

    fn renderRecord(self: *Self, record: *const LogRecord, buffer: *std.ArrayListUnmanaged(u8)) !void {
        const writer = buffer.writer(std.heap.page_allocator);

        switch (self.style) {
            .json => {
                try record.writeJson(writer);
            },
            .compact => {
                try writer.print("[{s}] {s}: {s}", .{ record.level.asText(), record.subsystem, record.message });
                try appendContext(writer, record);
                try appendFieldPairs(writer, record.fields);
            },
            .pretty => {
                try writer.print("{d} | {s: >5} | {s} | {s}", .{
                    record.ts_unix_ms,
                    record.level.asText(),
                    record.subsystem,
                    record.message,
                });
                try appendContext(writer, record);
                try appendFieldPairs(writer, record.fields);
            },
        }

        try writer.writeByte('\n');
    }

    fn emit(self: *Self, to_stderr: bool, bytes: []const u8) !void {
        if (self.emitter_fn) |emit_fn| {
            return emit_fn(self.emitter_ctx.?, to_stderr, bytes);
        }

        var local_buffer: [4096]u8 = undefined;
        if (to_stderr) {
            var stderr_writer = std.fs.File.stderr().writer(&local_buffer);
            try stderr_writer.interface.writeAll(bytes);
            try stderr_writer.interface.flush();
        } else {
            var stdout_writer = std.fs.File.stdout().writer(&local_buffer);
            try stdout_writer.interface.writeAll(bytes);
            try stdout_writer.interface.flush();
        }
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
        return "console";
    }
};

fn appendContext(writer: anytype, record: *const LogRecord) !void {
    if (record.trace_id) |trace_id| {
        try writer.print(" trace={s}", .{trace_id});
    }
    if (record.request_id) |request_id| {
        try writer.print(" request={s}", .{request_id});
    }
    if (record.error_code) |error_code| {
        try writer.print(" error_code={s}", .{error_code});
    }
    if (record.duration_ms) |duration_ms| {
        try writer.print(" duration_ms={d}", .{duration_ms});
    }
}

fn appendFieldPairs(writer: anytype, fields: []const LogField) !void {
    for (fields) |field| {
        try writer.print(" {s}=", .{field.key});
        try appendFieldValue(writer, field.value);
    }
}

fn appendFieldValue(writer: anytype, value: LogFieldValue) !void {
    switch (value) {
        .string => |text| try writer.print("\"{s}\"", .{text}),
        .int => |number| try writer.print("{}", .{number}),
        .uint => |number| try writer.print("{}", .{number}),
        .float => |number| try writer.print("{}", .{number}),
        .bool => |flag| try writer.writeAll(if (flag) "true" else "false"),
        .null => try writer.writeAll("null"),
    }
}

test "console sink renders json and routes errors to stderr" {
    const Capture = struct {
        allocator: std.mem.Allocator,
        stdout: std.ArrayListUnmanaged(u8) = .empty,
        stderr: std.ArrayListUnmanaged(u8) = .empty,

        fn deinit(self: *@This()) void {
            self.stdout.deinit(self.allocator);
            self.stderr.deinit(self.allocator);
        }

        fn emit(ptr: *anyopaque, to_stderr: bool, bytes: []const u8) !void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            if (to_stderr) {
                try self.stderr.appendSlice(self.allocator, bytes);
            } else {
                try self.stdout.appendSlice(self.allocator, bytes);
            }
        }
    };

    var capture = Capture{ .allocator = std.testing.allocator };
    defer capture.deinit();

    var sink = ConsoleSink.init(.trace, .json);
    sink.setEmitter(&capture, Capture.emit);

    const record = LogRecord{
        .ts_unix_ms = 10,
        .level = .@"error",
        .subsystem = "runtime/dispatch",
        .message = "command failed",
        .trace_id = "trc_01",
    };
    sink.write(&record);

    try std.testing.expectEqual(@as(usize, 0), capture.stdout.items.len);
    try std.testing.expect(std.mem.indexOf(u8, capture.stderr.items, "\"level\":\"error\"") != null);
}

test "console sink pretty and compact output differ" {
    const Capture = struct {
        allocator: std.mem.Allocator,
        stdout: std.ArrayListUnmanaged(u8) = .empty,

        fn deinit(self: *@This()) void {
            self.stdout.deinit(self.allocator);
        }

        fn emit(ptr: *anyopaque, _: bool, bytes: []const u8) !void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            try self.stdout.appendSlice(self.allocator, bytes);
        }
    };

    const record = LogRecord{
        .ts_unix_ms = 22,
        .level = .info,
        .subsystem = "config",
        .message = "field updated",
        .fields = &.{LogField.string("path", "gateway.port")},
    };

    var pretty_capture = Capture{ .allocator = std.testing.allocator };
    defer pretty_capture.deinit();
    var pretty_sink = ConsoleSink.init(.trace, .pretty);
    pretty_sink.setEmitter(&pretty_capture, Capture.emit);
    pretty_sink.write(&record);

    var compact_capture = Capture{ .allocator = std.testing.allocator };
    defer compact_capture.deinit();
    var compact_sink = ConsoleSink.init(.trace, .compact);
    compact_sink.setEmitter(&compact_capture, Capture.emit);
    compact_sink.write(&record);

    try std.testing.expect(std.mem.indexOf(u8, pretty_capture.stdout.items, "| config | field updated") != null);
    try std.testing.expect(std.mem.indexOf(u8, compact_capture.stdout.items, "[info] config: field updated") != null);
}
