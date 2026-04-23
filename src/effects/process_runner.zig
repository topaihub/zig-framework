const std = @import("std");
const builtin = @import("builtin");

pub const ProcessEnvVar = struct {
    key: []const u8,
    value: []const u8,
};

pub const ProcessRunRequest = struct {
    argv: []const []const u8,
    cwd: ?[]const u8 = null,
    env: []const ProcessEnvVar = &.{},
    stdin: ?[]const u8 = null,
    timeout_ms: ?u32 = null,
    max_output_bytes: usize = 64 * 1024,
};

pub const ProcessTerminationKind = enum {
    exited,
    signal,
    stopped,
    unknown,

    pub fn asText(self: ProcessTerminationKind) []const u8 {
        return switch (self) {
            .exited => "exited",
            .signal => "signal",
            .stopped => "stopped",
            .unknown => "unknown",
        };
    }
};

pub const ProcessRunResult = struct {
    stdout: []u8,
    stderr: []u8,
    exit_code: i32,
    term_kind: ProcessTerminationKind,

    pub fn deinit(self: *ProcessRunResult, allocator: std.mem.Allocator) void {
        allocator.free(self.stdout);
        allocator.free(self.stderr);
    }
};

pub const ProcessRunner = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        run: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, request: ProcessRunRequest) anyerror!ProcessRunResult,
        name: *const fn (ptr: *anyopaque) []const u8,
        deinit: ?*const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void = null,
    };

    pub fn run(self: ProcessRunner, allocator: std.mem.Allocator, request: ProcessRunRequest) anyerror!ProcessRunResult {
        return self.vtable.run(self.ptr, allocator, request);
    }

    pub fn name(self: ProcessRunner) []const u8 {
        return self.vtable.name(self.ptr);
    }

    pub fn deinit(self: ProcessRunner, allocator: std.mem.Allocator) void {
        if (self.vtable.deinit) |deinit_fn| deinit_fn(self.ptr, allocator);
    }
};

pub const NativeProcessRunner = struct {
    const vtable = ProcessRunner.VTable{
        .run = runErased,
        .name = nameErased,
        .deinit = null,
    };

    pub fn init() NativeProcessRunner {
        return .{};
    }

    pub fn runner(self: *NativeProcessRunner) ProcessRunner {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn runnerName() []const u8 {
        return "native";
    }

    pub fn run(_: *NativeProcessRunner, allocator: std.mem.Allocator, request: ProcessRunRequest) !ProcessRunResult {
        if (request.argv.len == 0) return error.EmptyProcessArgv;

        var env_map = try buildEnvMap(allocator, request.env);
        defer if (env_map) |*map| map.deinit();

        var child = std.process.Child.init(request.argv, allocator);
        child.stdin_behavior = if (request.stdin != null) .Pipe else .Ignore;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;
        child.cwd = request.cwd;
        if (env_map) |*map| child.env_map = map;

        try child.spawn();
        errdefer {
            _ = child.kill() catch {};
        }
        try child.waitForSpawn();

        if (request.stdin) |stdin_bytes| {
            const stdin_file = child.stdin.?;
            try stdin_file.writeAll(stdin_bytes);
            stdin_file.close();
            child.stdin = null;
        }

        const stdout_file = child.stdout.?;
        child.stdout = null;
        const stderr_file = child.stderr.?;
        child.stderr = null;

        var stdout_capture = PipeCapture.init(stdout_file, request.max_output_bytes);
        var stderr_capture = PipeCapture.init(stderr_file, request.max_output_bytes);

        const stdout_thread = try std.Thread.spawn(.{}, PipeCapture.run, .{&stdout_capture});
        const stderr_thread = try std.Thread.spawn(.{}, PipeCapture.run, .{&stderr_capture});

        const term = waitForExit(&child, request.timeout_ms) catch |err| {
            if (err == error.ProcessTimedOut) {
                _ = child.kill() catch {};
                stdout_thread.join();
                stderr_thread.join();
                stdout_capture.deinit();
                stderr_capture.deinit();
            }
            return err;
        };

        stdout_thread.join();
        stderr_thread.join();
        defer stdout_capture.deinit();
        defer stderr_capture.deinit();

        const stdout_bytes = try stdout_capture.toOwnedSlice(allocator, .stdout);
        errdefer allocator.free(stdout_bytes);
        const stderr_bytes = try stderr_capture.toOwnedSlice(allocator, .stderr);
        errdefer allocator.free(stderr_bytes);

        return .{
            .stdout = stdout_bytes,
            .stderr = stderr_bytes,
            .exit_code = exitCodeFromTerm(term),
            .term_kind = termKindFromTerm(term),
        };
    }

    fn runErased(ptr: *anyopaque, allocator: std.mem.Allocator, request: ProcessRunRequest) anyerror!ProcessRunResult {
        const self: *NativeProcessRunner = @ptrCast(@alignCast(ptr));
        return self.run(allocator, request);
    }

    fn nameErased(_: *anyopaque) []const u8 {
        return runnerName();
    }
};

const PipeCapture = struct {
    file: std.fs.File,
    max_output_bytes: usize,
    bytes: ?[]u8 = null,
    status: Status = .pending,

    const Status = enum {
        pending,
        ok,
        too_long,
        read_failed,
    };

    fn init(file: std.fs.File, max_output_bytes: usize) PipeCapture {
        return .{
            .file = file,
            .max_output_bytes = max_output_bytes,
        };
    }

    fn run(self: *PipeCapture) void {
        defer self.file.close();
        self.bytes = readAllWithLimit(std.heap.page_allocator, self.file, self.max_output_bytes) catch |err| {
            self.status = switch (err) {
                error.OutputTooLong => .too_long,
                else => .read_failed,
            };
            return;
        };
        self.status = .ok;
    }

    fn toOwnedSlice(self: *const PipeCapture, allocator: std.mem.Allocator, stream: enum { stdout, stderr }) ![]u8 {
        return switch (self.status) {
            .ok => allocator.dupe(u8, self.bytes orelse ""),
            .too_long => switch (stream) {
                .stdout => error.StdoutStreamTooLong,
                .stderr => error.StderrStreamTooLong,
            },
            .read_failed => switch (stream) {
                .stdout => error.StdoutReadFailed,
                .stderr => error.StderrReadFailed,
            },
            .pending => unreachable,
        };
    }

    fn deinit(self: *PipeCapture) void {
        if (self.bytes) |bytes| {
            std.heap.page_allocator.free(bytes);
            self.bytes = null;
        }
    }
};

fn buildEnvMap(allocator: std.mem.Allocator, env_vars: []const ProcessEnvVar) !?std.process.EnvMap {
    if (env_vars.len == 0) return null;

    var env_map = try std.process.getEnvMap(allocator);
    errdefer env_map.deinit();

    for (env_vars) |entry| {
        try env_map.put(entry.key, entry.value);
    }
    return env_map;
}

fn waitForExit(child: *std.process.Child, timeout_ms: ?u32) !std.process.Child.Term {
    if (timeout_ms == null) return child.wait();

    const deadline = (blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); }) + @as(i64, timeout_ms.?);
    while (true) {
        if (try pollExited(child)) |term| return term;
        if ((blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); }) >= deadline) return error.ProcessTimedOut;
        std.Thread.sleep(5 * std.time.ns_per_ms);
    }
}

fn pollExited(child: *std.process.Child) !?std.process.Child.Term {
    return switch (builtin.os.tag) {
        .windows => pollExitedWindows(child),
        else => pollExitedPosix(child),
    };
}

fn pollExitedWindows(child: *std.process.Child) !?std.process.Child.Term {
    const windows = std.os.windows;
    windows.WaitForSingleObjectEx(child.id, 0, false) catch |err| switch (err) {
        error.WaitTimeOut => return null,
        else => return error.ProcessWaitFailed,
    };
    return try child.wait();
}

fn pollExitedPosix(child: *std.process.Child) !?std.process.Child.Term {
    const res = std.posix.waitpid(child.id, std.posix.W.NOHANG);
    if (res.pid == 0) return null;

    const term = statusToTerm(res.status);
    child.term = term;
    child.id = undefined;
    return term;
}

fn statusToTerm(status: u32) std.process.Child.Term {
    return if (std.posix.W.IFEXITED(status))
        .{ .Exited = std.posix.W.EXITSTATUS(status) }
    else if (std.posix.W.IFSIGNALED(status))
        .{ .Signal = std.posix.W.TERMSIG(status) }
    else if (std.posix.W.IFSTOPPED(status))
        .{ .Stopped = std.posix.W.STOPSIG(status) }
    else
        .{ .Unknown = status };
}

fn readAllWithLimit(allocator: std.mem.Allocator, file: std.fs.File, max_output_bytes: usize) ![]u8 {
    var list: std.ArrayListUnmanaged(u8) = .empty;
    errdefer list.deinit(allocator);

    var buf: [4096]u8 = undefined;
    while (true) {
        const read = file.read(buf[0..]) catch return error.StreamReadFailed;
        if (read == 0) break;
        if (list.items.len + read > max_output_bytes) return error.OutputTooLong;
        try list.appendSlice(allocator, buf[0..read]);
    }

    return try list.toOwnedSlice(allocator);
}

fn termKindFromTerm(term: std.process.Child.Term) ProcessTerminationKind {
    return switch (term) {
        .Exited => .exited,
        .Signal => .signal,
        .Stopped => .stopped,
        .Unknown => .unknown,
    };
}

fn exitCodeFromTerm(term: std.process.Child.Term) i32 {
    return switch (term) {
        .Exited => |code| @intCast(code),
        .Signal => |signal| -@as(i32, @intCast(signal)),
        .Stopped => |signal| -@as(i32, @intCast(signal)),
        .Unknown => |status| -@as(i32, @intCast(status)),
    };
}

fn shellArgv(command: []const u8) []const []const u8 {
    return switch (builtin.os.tag) {
        .windows => &.{ "cmd.exe", "/C", command },
        else => &.{ "sh", "-c", command },
    };
}

fn trimLineEndings(text: []const u8) []const u8 {
    return std.mem.trimRight(u8, text, "\r\n");
}

test "native process runner executes command successfully" {
    var runner = NativeProcessRunner.init();
    var result = try runner.run(std.testing.allocator, .{
        .argv = shellArgv("echo hello"),
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(i32, 0), result.exit_code);
    try std.testing.expectEqualStrings("hello", trimLineEndings(result.stdout));
    try std.testing.expectEqualStrings("", trimLineEndings(result.stderr));
    try std.testing.expectEqualStrings("exited", result.term_kind.asText());
}

test "native process runner reports missing command" {
    var runner = NativeProcessRunner.init();
    try std.testing.expectError(error.FileNotFound, runner.run(std.testing.allocator, .{
        .argv = &.{"definitely_missing_framework_process_runner_binary"},
    }));
}

test "native process runner returns non-zero exit code" {
    const command = switch (builtin.os.tag) {
        .windows => "exit /B 7",
        else => "exit 7",
    };

    var runner = NativeProcessRunner.init();
    var result = try runner.run(std.testing.allocator, .{
        .argv = shellArgv(command),
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(i32, 7), result.exit_code);
    try std.testing.expectEqualStrings("exited", result.term_kind.asText());
}

test "native process runner enforces timeout" {
    const command = switch (builtin.os.tag) {
        .windows => "ping 127.0.0.1 -n 3 >NUL",
        else => "sleep 1",
    };

    var runner = NativeProcessRunner.init();
    try std.testing.expectError(error.ProcessTimedOut, runner.run(std.testing.allocator, .{
        .argv = shellArgv(command),
        .timeout_ms = 100,
    }));
}

test "native process runner honors cwd" {
    var tmp_dir = std.testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const cwd_path = try tmp_dir.dir.realpathAlloc(std.testing.allocator, ".");
    defer std.testing.allocator.free(cwd_path);

    const command = switch (builtin.os.tag) {
        .windows => "cd",
        else => "pwd",
    };

    var runner = NativeProcessRunner.init();
    var result = try runner.run(std.testing.allocator, .{
        .argv = shellArgv(command),
        .cwd = cwd_path,
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(cwd_path, trimLineEndings(result.stdout));
}

test "native process runner injects env vars" {
    const command = switch (builtin.os.tag) {
        .windows => "echo %FRAMEWORK_EFFECT_TEST_ENV%",
        else => "printf '%s' \"$FRAMEWORK_EFFECT_TEST_ENV\"",
    };

    var runner = NativeProcessRunner.init();
    var result = try runner.run(std.testing.allocator, .{
        .argv = shellArgv(command),
        .env = &.{.{ .key = "FRAMEWORK_EFFECT_TEST_ENV", .value = "effects-ok" }},
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("effects-ok", trimLineEndings(result.stdout));
}


