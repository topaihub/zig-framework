const std = @import("std");
const record_model = @import("record.zig");
const sink_model = @import("sink.zig");
const level_model = @import("level.zig");

pub const LogRecord = record_model.LogRecord;
pub const LogField = record_model.LogField;
pub const LogFieldValue = record_model.LogFieldValue;
pub const LogSink = sink_model.LogSink;
pub const LogLevel = level_model.LogLevel;

pub const TraceTextFileSinkOptions = struct {
    include_observer: bool = false,
    include_runtime_dispatch: bool = false,
    include_framework_method_trace: bool = false,
};

pub const TraceTextFileSink = struct {
    allocator: std.mem.Allocator,
    path: []u8,
    max_bytes: ?u64 = null,
    current_bytes: u64 = 0,
    degraded: bool = false,
    dropped_records: usize = 0,
    options: TraceTextFileSinkOptions = .{},

    const Self = @This();

    const vtable = LogSink.VTable{
        .write = writeErased,
        .flush = flushErased,
        .deinit = deinitErased,
        .name = nameErased,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        path: []const u8,
        max_bytes: ?u64,
        options: TraceTextFileSinkOptions,
    ) !Self {
        var self = Self{
            .allocator = allocator,
            .path = try allocator.dupe(u8, path),
            .max_bytes = max_bytes,
            .options = options,
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
        if (shouldSkipRecord(record, self.options)) return;

        var rendered: std.ArrayListUnmanaged(u8) = .empty;
        defer rendered.deinit(self.allocator);

        try formatRecord(rendered.writer(self.allocator), record);
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
        return "trace_text_file";
    }
};

fn shouldSkipRecord(record: *const LogRecord, options: TraceTextFileSinkOptions) bool {
    if (!options.include_observer and std.mem.eql(u8, record.subsystem, "observer")) {
        return true;
    }
    if (!options.include_runtime_dispatch and std.mem.startsWith(u8, record.subsystem, "runtime/dispatch")) {
        return true;
    }
    if (!options.include_framework_method_trace and std.mem.eql(u8, record.subsystem, "method")) {
        if (fieldString(record.fields, "method")) |method_name| {
            if (std.mem.startsWith(u8, method_name, "Command.") or std.mem.startsWith(u8, method_name, "AsyncCommand.")) {
                return true;
            }
        }
    }
    return false;
}

fn formatRecord(writer: anytype, record: *const LogRecord) !void {
    const time_text = try formatTimeOfDay(record.ts_unix_ms);
    try writer.print("[{s} {s}] ", .{ time_text, shortLevelText(record.level) });

    if (try renderSummaryTrace(writer, record)) return;
    if (try renderMethodTrace(writer, record)) return;
    if (try renderRequestTrace(writer, record)) return;
    if (try renderStepTrace(writer, record)) return;
    try renderGeneric(writer, record);
}

fn renderSummaryTrace(writer: anytype, record: *const LogRecord) !bool {
    if (!std.mem.eql(u8, record.subsystem, "summary")) return false;
    if (!std.mem.eql(u8, record.message, "TRACE_SUMMARY")) return false;

    const method_name = fieldString(record.fields, "method") orelse return false;
    const rt = fieldUint(record.fields, "rt") orelse return false;
    const bt = fieldBool(record.fields, "bt") orelse return false;
    const et = fieldString(record.fields, "et") orelse return false;

    try appendTracePrefix(writer, record);
    try writer.print("ME:{s}|RT:{d}|BT:{s}|ET:{s}", .{
        method_name,
        rt,
        if (bt) "Y" else "N",
        et,
    });
    return true;
}

fn renderMethodTrace(writer: anytype, record: *const LogRecord) !bool {
    if (!std.mem.eql(u8, record.subsystem, "method")) return false;
    const method_name = fieldString(record.fields, "method") orelse return false;
    if (!(std.mem.eql(u8, record.message, "ENTRY") or std.mem.eql(u8, record.message, "EXIT") or std.mem.eql(u8, record.message, "ERROR"))) return false;

    try appendTracePrefix(writer, record);
    try writer.print("{s}|{s}", .{ record.message, method_name });

    if (std.mem.eql(u8, record.message, "ENTRY")) {
        if (fieldString(record.fields, "params")) |params| {
            try writer.print("|Params:{s}", .{params});
        }
        return true;
    }

    if (fieldString(record.fields, "result")) |result| {
        try writer.print("|Result:{s}", .{result});
    }
    if (fieldString(record.fields, "status")) |status| {
        try writer.print("|Status:{s}", .{status});
    }
    if (fieldUint(record.fields, "duration_ms")) |duration_ms| {
        try writer.print("|Duration:{d}ms", .{duration_ms});
    }
    if (fieldString(record.fields, "type")) |kind| {
        try writer.print("|Type:{s}", .{kind});
    }
    if (fieldString(record.fields, "exception_type")) |exception_type| {
        try writer.print("|Exception:{s}", .{exception_type});
    }
    if (fieldString(record.fields, "error_code")) |error_code| {
        try writer.print("|ErrorCode:{s}", .{error_code});
    }
    return true;
}

fn renderRequestTrace(writer: anytype, record: *const LogRecord) !bool {
    if (!std.mem.eql(u8, record.subsystem, "request")) return false;

    try appendTracePrefix(writer, record);
    try writer.writeAll(record.message);

    if (fieldString(record.fields, "method")) |method_name| {
        try writer.print("|Method:{s}", .{method_name});
    }
    if (fieldString(record.fields, "path")) |path| {
        try writer.print("|Path:{s}", .{path});
    }
    if (fieldString(record.fields, "query")) |query| {
        try writer.print("|Query:{s}", .{query});
    }
    if (fieldUint(record.fields, "status")) |status| {
        try writer.print("|Status:{d}", .{status});
    }
    if (fieldUint(record.fields, "duration_ms")) |duration_ms| {
        try writer.print("|Duration:{d}ms", .{duration_ms});
    }
    if (fieldString(record.fields, "error_code")) |error_code| {
        try writer.print("|ErrorCode:{s}", .{error_code});
    }
    return true;
}

fn renderStepTrace(writer: anytype, record: *const LogRecord) !bool {
    const step = fieldString(record.fields, "step") orelse return false;
    if (!std.mem.eql(u8, record.message, "Step started") and !std.mem.eql(u8, record.message, "Step completed")) return false;

    try appendTracePrefix(writer, record);
    try writer.print("{s}|Subsystem:{s}|Step:{s}", .{ record.message, record.subsystem, step });

    if (fieldUint(record.fields, "duration_ms")) |duration_ms| {
        try writer.print("|Duration:{d}ms", .{duration_ms});
    }
    if (fieldBool(record.fields, "beyond_threshold")) |beyond_threshold| {
        try writer.print("|BT:{s}", .{if (beyond_threshold) "Y" else "N"});
    }
    if (fieldUint(record.fields, "threshold_ms")) |threshold_ms| {
        try writer.print("|Threshold:{d}ms", .{threshold_ms});
    }
    if (fieldString(record.fields, "error_code")) |error_code| {
        try writer.print("|ErrorCode:{s}", .{error_code});
    }
    return true;
}

fn renderGeneric(writer: anytype, record: *const LogRecord) !void {
    if (record.trace_id != null) {
        try appendTracePrefix(writer, record);
    }
    try writer.writeAll(record.message);
    for (record.fields) |field| {
        try appendLabeledField(writer, field.key, field.value);
    }
}

fn appendTracePrefix(writer: anytype, record: *const LogRecord) !void {
    if (record.trace_id) |trace_id| {
        try writer.print("TraceId:{s}|", .{trace_id});
    }
}

fn appendLabeledField(writer: anytype, key: []const u8, value: LogFieldValue) !void {
    const label = prettyLabel(key);
    switch (value) {
        .string => |text| {
            try writer.print("|{s}:{s}", .{ label, text });
        },
        .int => |number| {
            if (std.mem.eql(u8, key, "duration_ms") or std.mem.eql(u8, key, "threshold_ms")) {
                try writer.print("|{s}:{d}ms", .{ label, number });
            } else {
                try writer.print("|{s}:{d}", .{ label, number });
            }
        },
        .uint => |number| {
            if (std.mem.eql(u8, key, "duration_ms") or std.mem.eql(u8, key, "threshold_ms")) {
                try writer.print("|{s}:{d}ms", .{ label, number });
            } else {
                try writer.print("|{s}:{d}", .{ label, number });
            }
        },
        .float => |number| {
            try writer.print("|{s}:{d}", .{ label, number });
        },
        .bool => |flag| {
            try writer.print("|{s}:{s}", .{ label, if (flag) "Y" else "N" });
        },
        .null => {
            try writer.print("|{s}:null", .{label});
        },
    }
}

fn prettyLabel(key: []const u8) []const u8 {
    if (std.mem.eql(u8, key, "params")) return "Params";
    if (std.mem.eql(u8, key, "result")) return "Result";
    if (std.mem.eql(u8, key, "status")) return "Status";
    if (std.mem.eql(u8, key, "duration_ms")) return "Duration";
    if (std.mem.eql(u8, key, "type")) return "Type";
    if (std.mem.eql(u8, key, "exception_type")) return "Exception";
    if (std.mem.eql(u8, key, "error_code")) return "ErrorCode";
    if (std.mem.eql(u8, key, "threshold_ms")) return "Threshold";
    if (std.mem.eql(u8, key, "beyond_threshold")) return "BT";
    if (std.mem.eql(u8, key, "change_dir")) return "ChangeDir";
    if (std.mem.eql(u8, key, "metadata_path")) return "MetadataPath";
    if (std.mem.eql(u8, key, "change")) return "Change";
    if (std.mem.eql(u8, key, "schema")) return "Schema";
    if (std.mem.eql(u8, key, "project_root")) return "ProjectRoot";
    if (std.mem.eql(u8, key, "config_path")) return "ConfigPath";
    if (std.mem.eql(u8, key, "has_created")) return "HasCreated";
    if (std.mem.eql(u8, key, "is_complete")) return "IsComplete";
    if (std.mem.eql(u8, key, "completed_count")) return "CompletedCount";
    if (std.mem.eql(u8, key, "artifact_count")) return "ArtifactCount";
    if (std.mem.eql(u8, key, "artifact")) return "Artifact";
    if (std.mem.eql(u8, key, "dependency_count")) return "DependencyCount";
    if (std.mem.eql(u8, key, "unlock_count")) return "UnlockCount";
    if (std.mem.eql(u8, key, "has_rules")) return "HasRules";
    if (std.mem.eql(u8, key, "has_context")) return "HasContext";
    if (std.mem.eql(u8, key, "specs_rule_count")) return "SpecsRuleCount";
    if (std.mem.eql(u8, key, "design_rule_count")) return "DesignRuleCount";
    if (std.mem.eql(u8, key, "tasks_rule_count")) return "TasksRuleCount";
    if (std.mem.eql(u8, key, "path")) return "Path";
    if (std.mem.eql(u8, key, "query")) return "Query";
    if (std.mem.eql(u8, key, "step")) return "Step";
    return key;
}

fn fieldString(fields: []const LogField, key: []const u8) ?[]const u8 {
    for (fields) |field| {
        if (!std.mem.eql(u8, field.key, key)) continue;
        return switch (field.value) {
            .string => |text| text,
            else => null,
        };
    }
    return null;
}

fn fieldUint(fields: []const LogField, key: []const u8) ?u64 {
    for (fields) |field| {
        if (!std.mem.eql(u8, field.key, key)) continue;
        return switch (field.value) {
            .uint => |value| value,
            .int => |value| if (value >= 0) @intCast(value) else null,
            else => null,
        };
    }
    return null;
}

fn fieldBool(fields: []const LogField, key: []const u8) ?bool {
    for (fields) |field| {
        if (!std.mem.eql(u8, field.key, key)) continue;
        return switch (field.value) {
            .bool => |value| value,
            else => null,
        };
    }
    return null;
}

fn shortLevelText(level: LogLevel) []const u8 {
    return switch (level) {
        .trace => "TRC",
        .debug => "DBG",
        .info => "INF",
        .warn => "WRN",
        .@"error" => "ERR",
        .fatal => "FTL",
        .silent => "OFF",
    };
}

fn formatTimeOfDay(ts_unix_ms: i64) ![8]u8 {
    const seconds = @divFloor(ts_unix_ms, 1000);
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = @intCast(seconds) };
    const day_seconds = epoch_seconds.getDaySeconds();

    const hour = day_seconds.getHoursIntoDay();
    const minute = day_seconds.getMinutesIntoHour();
    const second = day_seconds.getSecondsIntoMinute();

    var out: [8]u8 = undefined;
    _ = try std.fmt.bufPrint(&out, "{d:0>2}:{d:0>2}:{d:0>2}", .{ hour, minute, second });
    return out;
}

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

test "trace text file sink writes human-readable method trace lines" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);

    const log_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "logs", "trace.log" });
    defer std.testing.allocator.free(log_path);

    var sink = try TraceTextFileSink.init(std.testing.allocator, log_path, 4096, .{});
    defer sink.deinit();

    const record = LogRecord{
        .ts_unix_ms = 22,
        .level = .info,
        .subsystem = "method",
        .message = "EXIT",
        .trace_id = "trc_01",
        .fields = &.{
            LogField.string("method", "Controller.Auth.Login"),
            LogField.string("result", "Ok(200)"),
            LogField.string("status", "SUCCESS"),
            LogField.uint("duration_ms", 542),
            LogField.string("type", "SYNC"),
        },
    };
    sink.write(&record);

    const contents = try tmp_dir.dir.readFileAlloc(std.testing.allocator, "logs/trace.log", 4096);
    defer std.testing.allocator.free(contents);

    try std.testing.expect(std.mem.indexOf(u8, contents, "[00:00:00 INF] TraceId:trc_01|EXIT|Controller.Auth.Login|Result:Ok(200)|Status:SUCCESS|Duration:542ms|Type:SYNC") != null);
}

test "trace text file sink can skip observer and framework command traces" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);

    const log_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "trace.log" });
    defer std.testing.allocator.free(log_path);

    var sink = try TraceTextFileSink.init(std.testing.allocator, log_path, 4096, .{});
    defer sink.deinit();

    sink.write(&LogRecord{
        .ts_unix_ms = 1,
        .level = .info,
        .subsystem = "observer",
        .message = "observer event",
    });
    sink.write(&LogRecord{
        .ts_unix_ms = 1,
        .level = .debug,
        .subsystem = "method",
        .message = "ENTRY",
        .fields = &.{
            LogField.string("method", "Command.workflow.status"),
            LogField.string("params", "{}"),
        },
    });
    sink.write(&LogRecord{
        .ts_unix_ms = 1,
        .level = .info,
        .subsystem = "method",
        .message = "EXIT",
        .trace_id = "trc_01",
        .fields = &.{
            LogField.string("method", "OpenSpecZig.Status"),
            LogField.string("result", "Ok(status)"),
            LogField.string("status", "SUCCESS"),
            LogField.uint("duration_ms", 1),
            LogField.string("type", "SYNC"),
        },
    });

    const contents = try tmp_dir.dir.readFileAlloc(std.testing.allocator, "trace.log", 4096);
    defer std.testing.allocator.free(contents);

    try std.testing.expect(std.mem.indexOf(u8, contents, "observer event") == null);
    try std.testing.expect(std.mem.indexOf(u8, contents, "Command.workflow.status") == null);
    try std.testing.expect(std.mem.indexOf(u8, contents, "OpenSpecZig.Status") != null);
}

test "trace text file sink renders summary trace in ME/RT/BT/ET format" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const root_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(root_path);

    const log_path = try std.fs.path.join(std.testing.allocator, &.{ root_path, "trace.log" });
    defer std.testing.allocator.free(log_path);

    var sink = try TraceTextFileSink.init(std.testing.allocator, log_path, 4096, .{});
    defer sink.deinit();

    sink.write(&LogRecord{
        .ts_unix_ms = 22,
        .level = .warn,
        .subsystem = "summary",
        .message = "TRACE_SUMMARY",
        .trace_id = "trc_01",
        .fields = &.{
            LogField.string("method", "Auth.Login"),
            LogField.uint("rt", 449),
            LogField.boolean("bt", false),
            LogField.string("et", "N"),
        },
    });

    const contents = try tmp_dir.dir.readFileAlloc(std.testing.allocator, "trace.log", 4096);
    defer std.testing.allocator.free(contents);

    try std.testing.expect(std.mem.indexOf(u8, contents, "[00:00:00 WRN] TraceId:trc_01|ME:Auth.Login|RT:449|BT:N|ET:N") != null);
}
