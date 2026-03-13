const std = @import("std");
const level_model = @import("level.zig");
const record_model = @import("record.zig");
const redact_model = @import("redact.zig");
const sink_model = @import("sink.zig");

pub const LogLevel = level_model.LogLevel;
pub const LogField = record_model.LogField;
pub const LogRecord = record_model.LogRecord;
pub const RedactMode = redact_model.RedactMode;
pub const LogSink = sink_model.LogSink;

pub const TraceContext = struct {
    trace_id: ?[]const u8 = null,
    span_id: ?[]const u8 = null,
    request_id: ?[]const u8 = null,
};

pub const TraceContextProvider = struct {
    ptr: *anyopaque,
    current: *const fn (ptr: *anyopaque) TraceContext,

    pub fn getCurrent(self: TraceContextProvider) TraceContext {
        return self.current(self.ptr);
    }
};

pub const LoggerOptions = struct {
    min_level: LogLevel = .info,
    redact_mode: RedactMode = .safe,
    trace_context_provider: ?TraceContextProvider = null,
};

pub const Logger = struct {
    sink: LogSink,
    min_level: LogLevel = .info,
    redact_mode: RedactMode = .safe,
    trace_context_provider: ?TraceContextProvider = null,

    const Self = @This();

    pub fn init(sink: LogSink, min_level: LogLevel) Self {
        return initWithOptions(sink, .{ .min_level = min_level });
    }

    pub fn initWithOptions(sink: LogSink, options: LoggerOptions) Self {
        return .{
            .sink = sink,
            .min_level = options.min_level,
            .redact_mode = options.redact_mode,
            .trace_context_provider = options.trace_context_provider,
        };
    }

    pub fn deinit(self: *Self) void {
        self.flush();
    }

    pub fn flush(self: *Self) void {
        self.sink.flush();
    }

    pub fn child(self: *Self, subsystem_name: []const u8) SubsystemLogger {
        return SubsystemLogger.init(self, subsystem_name);
    }

    pub fn subsystem(self: *Self, subsystem_name: []const u8) SubsystemLogger {
        return self.child(subsystem_name);
    }

    fn log(self: *Self, level: LogLevel, subsystem_name: []const u8, message: []const u8, fields: []const LogField) void {
        if (!self.min_level.allows(level)) {
            return;
        }

        var record = LogRecord{
            .ts_unix_ms = std.time.milliTimestamp(),
            .level = level,
            .subsystem = subsystem_name,
            .message = message,
            .fields = fields,
        };

        if (self.trace_context_provider) |provider| {
            const trace_context = provider.getCurrent();
            record.trace_id = trace_context.trace_id;
            record.span_id = trace_context.span_id;
            record.request_id = trace_context.request_id;
        }

        self.sink.write(&record);
    }
};

pub const SubsystemLogger = struct {
    logger: *Logger,
    subsystem_storage: [max_subsystem_len]u8 = undefined,
    subsystem_len: usize = 0,
    default_fields_storage: [max_default_fields]LogField = undefined,
    default_field_count: usize = 0,

    const Self = @This();
    const max_subsystem_len = 128;
    const max_default_fields = 8;
    const max_combined_fields = 16;

    pub fn init(logger: *Logger, subsystem_name: []const u8) Self {
        var self = Self{
            .logger = logger,
        };
        self.setSubsystem(subsystem_name);
        return self;
    }

    pub fn subsystem(self: *const Self) []const u8 {
        return self.subsystem_storage[0..self.subsystem_len];
    }

    pub fn child(self: Self, name: []const u8) Self {
        var next = self;
        next.appendSubsystem(name);
        return next;
    }

    pub fn withField(self: Self, field: LogField) Self {
        var next = self;
        if (next.default_field_count < max_default_fields) {
            next.default_fields_storage[next.default_field_count] = field;
            next.default_field_count += 1;
        }
        return next;
    }

    pub fn withFields(self: Self, fields: []const LogField) Self {
        var next = self;
        for (fields) |field| {
            if (next.default_field_count >= max_default_fields) {
                break;
            }
            next.default_fields_storage[next.default_field_count] = field;
            next.default_field_count += 1;
        }
        return next;
    }

    pub fn trace(self: *const Self, message: []const u8, fields: []const LogField) void {
        self.emit(.trace, message, fields);
    }

    pub fn debug(self: *const Self, message: []const u8, fields: []const LogField) void {
        self.emit(.debug, message, fields);
    }

    pub fn info(self: *const Self, message: []const u8, fields: []const LogField) void {
        self.emit(.info, message, fields);
    }

    pub fn warn(self: *const Self, message: []const u8, fields: []const LogField) void {
        self.emit(.warn, message, fields);
    }

    pub fn @"error"(self: *const Self, message: []const u8, fields: []const LogField) void {
        self.emit(.@"error", message, fields);
    }

    pub fn fatal(self: *const Self, message: []const u8, fields: []const LogField) void {
        self.emit(.fatal, message, fields);
    }

    fn emit(self: *const Self, level: LogLevel, message: []const u8, fields: []const LogField) void {
        var combined: [max_combined_fields]LogField = undefined;
        var redacted: [max_combined_fields]LogField = undefined;
        var combined_len: usize = 0;

        for (self.default_fields_storage[0..self.default_field_count]) |field| {
            if (combined_len >= max_combined_fields) {
                break;
            }
            combined[combined_len] = field;
            combined_len += 1;
        }

        for (fields) |field| {
            if (combined_len >= max_combined_fields) {
                break;
            }
            combined[combined_len] = field;
            combined_len += 1;
        }

        const emitted_fields = redact_model.redactFields(
            self.logger.redact_mode,
            combined[0..combined_len],
            redacted[0..combined_len],
        );

        self.logger.log(level, self.subsystem(), message, emitted_fields);
    }

    fn setSubsystem(self: *Self, subsystem_name: []const u8) void {
        const copy_len = @min(max_subsystem_len, subsystem_name.len);
        @memcpy(self.subsystem_storage[0..copy_len], subsystem_name[0..copy_len]);
        self.subsystem_len = copy_len;
    }

    fn appendSubsystem(self: *Self, suffix: []const u8) void {
        if (suffix.len == 0 or self.subsystem_len >= max_subsystem_len) {
            return;
        }

        var start = self.subsystem_len;
        if (start > 0 and start < max_subsystem_len) {
            self.subsystem_storage[start] = '/';
            start += 1;
        }

        const available = max_subsystem_len - start;
        const copy_len = @min(available, suffix.len);
        @memcpy(self.subsystem_storage[start .. start + copy_len], suffix[0..copy_len]);
        self.subsystem_len = start + copy_len;
    }
};

test "logger writes structured records into memory sink" {
    const memory_sink_model = @import("memory_sink.zig");

    var memory_sink = memory_sink_model.MemorySink.init(std.testing.allocator, 8);
    defer memory_sink.deinit();

    var logger = Logger.init(memory_sink.asLogSink(), .debug);
    defer logger.deinit();

    const fields = [_]LogField{
        LogField.string("method", "config.set"),
        LogField.boolean("retryable", false),
    };
    const subsystem_logger = logger
        .child("runtime")
        .child("dispatch")
        .withField(LogField.string("source", "test"));

    subsystem_logger.info("command started", fields[0..]);

    try std.testing.expectEqual(@as(usize, 1), memory_sink.count());
    try std.testing.expectEqualStrings("runtime/dispatch", memory_sink.latest().?.subsystem);
    try std.testing.expectEqualStrings("command started", memory_sink.latest().?.message);
    try std.testing.expectEqual(@as(usize, 3), memory_sink.latest().?.fields.len);
    try std.testing.expectEqualStrings("source", memory_sink.latest().?.fields[0].key);
    try std.testing.expectEqualStrings("config.set", memory_sink.latest().?.fields[1].value.string);
}

test "logger respects minimum level filtering" {
    const memory_sink_model = @import("memory_sink.zig");

    var memory_sink = memory_sink_model.MemorySink.init(std.testing.allocator, 4);
    defer memory_sink.deinit();

    var logger = Logger.init(memory_sink.asLogSink(), .warn);
    defer logger.deinit();

    const subsystem_logger = logger.child("config");
    subsystem_logger.info("ignored", &.{});
    subsystem_logger.@"error"("persist failed", &.{});

    try std.testing.expectEqual(@as(usize, 1), memory_sink.count());
    try std.testing.expect(memory_sink.latest().?.level == .@"error");
    try std.testing.expectEqualStrings("persist failed", memory_sink.latest().?.message);
}

test "logger redacts sensitive fields before sink write" {
    const memory_sink_model = @import("memory_sink.zig");

    var memory_sink = memory_sink_model.MemorySink.init(std.testing.allocator, 4);
    defer memory_sink.deinit();

    var logger = Logger.initWithOptions(memory_sink.asLogSink(), .{
        .min_level = .info,
        .redact_mode = .safe,
    });
    defer logger.deinit();

    const subsystem_logger = logger.child("providers");
    subsystem_logger.info("request prepared", &.{
        LogField.string("api_key", "top-secret"),
        LogField.string("model", "gpt-test"),
    });

    try std.testing.expectEqualStrings(redact_model.REDACTED_VALUE, memory_sink.latest().?.fields[0].value.string);
    try std.testing.expectEqualStrings("gpt-test", memory_sink.latest().?.fields[1].value.string);
}

test "logger injects trace context automatically" {
    const memory_sink_model = @import("memory_sink.zig");

    const TraceState = struct {
        trace_context: TraceContext,

        fn current(ptr: *anyopaque) TraceContext {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            return self.trace_context;
        }
    };

    var trace_state = TraceState{
        .trace_context = .{
            .trace_id = "trc_01",
            .span_id = "spn_01",
            .request_id = "req_01",
        },
    };

    var memory_sink = memory_sink_model.MemorySink.init(std.testing.allocator, 4);
    defer memory_sink.deinit();

    var logger = Logger.initWithOptions(memory_sink.asLogSink(), .{
        .min_level = .info,
        .trace_context_provider = .{
            .ptr = @ptrCast(&trace_state),
            .current = TraceState.current,
        },
    });
    defer logger.deinit();

    logger.child("runtime").info("dispatch started", &.{});

    try std.testing.expectEqualStrings("trc_01", memory_sink.latest().?.trace_id.?);
    try std.testing.expectEqualStrings("spn_01", memory_sink.latest().?.span_id.?);
    try std.testing.expectEqualStrings("req_01", memory_sink.latest().?.request_id.?);
}
