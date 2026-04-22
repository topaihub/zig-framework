const std = @import("std");
const contracts = @import("../contracts/root.zig");
const observer_model = @import("../observability/observer.zig");
const event_bus_model = @import("event_bus.zig");

pub const TaskAccepted = contracts.envelope.TaskAccepted;
pub const Observer = observer_model.Observer;
pub const EventBus = event_bus_model.EventBus;

pub const TaskState = enum {
    queued,
    running,
    succeeded,
    failed,
    cancelled,

    pub fn asText(self: TaskState) []const u8 {
        return switch (self) {
            .queued => "queued",
            .running => "running",
            .succeeded => "succeeded",
            .failed => "failed",
            .cancelled => "cancelled",
        };
    }

    pub fn isTerminal(self: TaskState) bool {
        return switch (self) {
            .succeeded, .failed, .cancelled => true,
            else => false,
        };
    }
};

pub const TaskJob = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        run: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]u8,
        deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    };

    pub fn run(self: TaskJob, allocator: std.mem.Allocator) anyerror![]u8 {
        return self.vtable.run(self.ptr, allocator);
    }

    pub fn deinit(self: TaskJob, allocator: std.mem.Allocator) void {
        self.vtable.deinit(self.ptr, allocator);
    }
};

pub const TaskRecord = struct {
    id: []u8,
    command: []u8,
    request_id: ?[]u8 = null,
    state: TaskState,
    started_at_ms: ?i64 = null,
    finished_at_ms: ?i64 = null,
    error_code: ?[]u8 = null,
    result_json: ?[]u8 = null,

    pub fn cloneSummary(self: TaskRecord, allocator: std.mem.Allocator) anyerror!TaskSummary {
        return .{
            .id = try allocator.dupe(u8, self.id),
            .command = try allocator.dupe(u8, self.command),
            .request_id = if (self.request_id) |request_id| try allocator.dupe(u8, request_id) else null,
            .state = self.state,
            .started_at_ms = self.started_at_ms,
            .finished_at_ms = self.finished_at_ms,
            .error_code = if (self.error_code) |error_code| try allocator.dupe(u8, error_code) else null,
            .result_json = if (self.result_json) |result_json| try allocator.dupe(u8, result_json) else null,
        };
    }

    pub fn deinit(self: *TaskRecord, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.command);
        if (self.request_id) |request_id| allocator.free(request_id);
        if (self.error_code) |error_code| allocator.free(error_code);
        if (self.result_json) |result_json| allocator.free(result_json);
    }
};

pub const TaskSummary = struct {
    id: []u8,
    command: []u8,
    request_id: ?[]u8,
    state: TaskState,
    started_at_ms: ?i64,
    finished_at_ms: ?i64,
    error_code: ?[]u8,
    result_json: ?[]u8,

    pub fn deinit(self: *TaskSummary, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.command);
        if (self.request_id) |request_id| allocator.free(request_id);
        if (self.error_code) |error_code| allocator.free(error_code);
        if (self.result_json) |result_json| allocator.free(result_json);
    }
};

pub const TaskRunner = struct {
    allocator: std.mem.Allocator,
    next_id: u64 = 1,
    tasks: std.ArrayListUnmanaged(TaskRecord) = .empty,
    threads: std.ArrayListUnmanaged(std.Thread) = .empty,
    observer: ?Observer = null,
    event_bus: ?EventBus = null,
    mutex: std.atomic.Mutex = .unlocked,

    const Self = @This();

    const AsyncExecution = struct {
        runner: *Self,
        task_id: []u8,
        job: TaskJob,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn initWithObservability(allocator: std.mem.Allocator, observer: ?Observer, event_bus: ?EventBus) Self {
        return .{
            .allocator = allocator,
            .observer = observer,
            .event_bus = event_bus,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.threads.items) |thread| {
            thread.join();
        }
        self.threads.deinit(self.allocator);

        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        for (self.tasks.items) |*task| {
            task.deinit(self.allocator);
        }
        self.tasks.deinit(self.allocator);
    }

    pub fn submit(self: *Self, command: []const u8, request_id: ?[]const u8) anyerror!TaskAccepted {
        var accepted: TaskAccepted = undefined;

        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        const task_id = try std.fmt.allocPrint(self.allocator, "task_{d:0>6}", .{self.next_id});
        errdefer self.allocator.free(task_id);

        try self.tasks.append(self.allocator, .{
            .id = task_id,
            .command = try self.allocator.dupe(u8, command),
            .request_id = if (request_id) |value| try self.allocator.dupe(u8, value) else null,
            .state = .queued,
        });

        self.next_id += 1;
        accepted = .{
            .task_id = task_id,
            .state = TaskState.queued.asText(),
        };

        const payload = try self.taskEventPayloadLocked(self.tasks.items[self.tasks.items.len - 1]);
        defer self.allocator.free(payload);
        self.emitEvent("task.queued", payload);
        return accepted;
    }

    pub fn submitJob(self: *Self, command: []const u8, request_id: ?[]const u8, job: TaskJob) anyerror!TaskAccepted {
        const accepted = try self.submit(command, request_id);

        const execution = try self.allocator.create(AsyncExecution);
        errdefer self.allocator.destroy(execution);
        execution.* = .{
            .runner = self,
            .task_id = try self.allocator.dupe(u8, accepted.task_id),
            .job = job,
        };

        const thread = std.Thread.spawn(.{}, taskThreadMain, .{execution}) catch |err| {
            job.deinit(self.allocator);
            self.allocator.free(execution.task_id);
            self.allocator.destroy(execution);
            try self.markFailed(accepted.task_id, "TASK_SPAWN_FAILED");
            return err;
        };

        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();
        try self.threads.append(self.allocator, thread);
        return accepted;
    }

    pub fn markRunning(self: *Self, id: []const u8) anyerror!void {
        try self.transitionToRunning(id);
    }

    pub fn markSucceeded(self: *Self, id: []const u8) anyerror!void {
        try self.transitionToSucceeded(id, null);
    }

    pub fn markSucceededWithResult(self: *Self, id: []const u8, result_json: []u8) anyerror!void {
        try self.transitionToSucceeded(id, result_json);
    }

    pub fn markFailed(self: *Self, id: []const u8, error_code: ?[]const u8) anyerror!void {
        const owned_error_code = if (error_code) |value| try self.allocator.dupe(u8, value) else null;
        errdefer if (owned_error_code) |value| self.allocator.free(value);
        try self.transitionToFailed(id, owned_error_code);
    }

    pub fn cancel(self: *Self, id: []const u8) anyerror!void {
        var payload: []u8 = undefined;

        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        const task = self.findMutableByIdLocked(id) orelse return error.TaskNotFound;
        if (task.state == .succeeded or task.state == .failed or task.state == .cancelled) {
            return error.InvalidTaskTransition;
        }

        task.state = .cancelled;
        if (task.started_at_ms == null) {
            task.started_at_ms = (blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); });
        }
        task.finished_at_ms = (blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); });
        payload = try self.taskEventPayloadLocked(task.*);
        defer self.allocator.free(payload);
        self.emitEvent("task.cancelled", payload);
    }

    pub fn snapshotById(self: *Self, allocator: std.mem.Allocator, id: []const u8) anyerror!?TaskSummary {
        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        const task = self.findByIdLocked(id) orelse return null;
        return try task.cloneSummary(allocator);
    }

    pub fn snapshotByRequestId(self: *Self, allocator: std.mem.Allocator, request_id: []const u8) anyerror!?TaskSummary {
        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        const task = self.findByRequestIdLocked(request_id) orelse return null;
        return try task.cloneSummary(allocator);
    }

    pub fn countByState(self: *Self, state: TaskState) usize {
        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        var total: usize = 0;
        for (self.tasks.items) |task| {
            if (task.state == state) {
                total += 1;
            }
        }
        return total;
    }

    pub fn latest(self: *Self, allocator: std.mem.Allocator) anyerror!?TaskSummary {
        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        if (self.tasks.items.len == 0) {
            return null;
        }
        return try self.tasks.items[self.tasks.items.len - 1].cloneSummary(allocator);
    }

    pub fn snapshot(self: *Self, allocator: std.mem.Allocator) anyerror![]TaskSummary {
        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        const summaries = try allocator.alloc(TaskSummary, self.tasks.items.len);
        errdefer allocator.free(summaries);

        for (self.tasks.items, 0..) |task, index| {
            summaries[index] = try task.cloneSummary(allocator);
        }

        return summaries;
    }

    pub fn waitForCompletion(self: *Self, allocator: std.mem.Allocator, id: []const u8, timeout_ms: u64) anyerror!TaskSummary {
        const started = (blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); });

        while ((blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); }) - started <= @as(i64, @intCast(timeout_ms))) {
            if (try self.snapshotById(allocator, id)) |summary| {
                if (summary.state.isTerminal()) {
                    return summary;
                }
                var mutable_summary = summary;
                mutable_summary.deinit(allocator);
            }
            std.Thread.sleep(5 * std.time.ns_per_ms);
        }

        return error.TaskWaitTimeout;
    }

    pub fn count(self: *Self) usize {
        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();
        return self.tasks.items.len;
    }

    fn transitionToRunning(self: *Self, id: []const u8) anyerror!void {
        var payload: []u8 = undefined;

        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        const task = self.findMutableByIdLocked(id) orelse return error.TaskNotFound;
        if (task.state != .queued) {
            return error.InvalidTaskTransition;
        }
        task.state = .running;
        task.started_at_ms = (blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); });
        payload = try self.taskEventPayloadLocked(task.*);
        defer self.allocator.free(payload);
        self.emitEvent("task.running", payload);
    }

    fn transitionToSucceeded(self: *Self, id: []const u8, result_json: ?[]u8) anyerror!void {
        var payload: []u8 = undefined;

        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        const task = self.findMutableByIdLocked(id) orelse return error.TaskNotFound;
        if (task.state != .running and task.state != .queued) {
            return error.InvalidTaskTransition;
        }
        task.state = .succeeded;
        if (task.started_at_ms == null) {
            task.started_at_ms = (blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); });
        }
        task.finished_at_ms = (blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); });
        if (task.error_code) |error_code| {
            self.allocator.free(error_code);
            task.error_code = null;
        }
        if (task.result_json) |old_result| {
            self.allocator.free(old_result);
            task.result_json = null;
        }
        if (result_json) |owned_result| {
            task.result_json = owned_result;
        }
        payload = try self.taskEventPayloadLocked(task.*);
        defer self.allocator.free(payload);
        self.emitEvent("task.succeeded", payload);
    }

    fn transitionToFailed(self: *Self, id: []const u8, owned_error_code: ?[]u8) anyerror!void {
        var payload: []u8 = undefined;

        while (!self.mutex.tryLock()) {}
        defer self.mutex.unlock();

        const task = self.findMutableByIdLocked(id) orelse {
            if (owned_error_code) |value| self.allocator.free(value);
            return error.TaskNotFound;
        };
        if (task.state != .running and task.state != .queued) {
            if (owned_error_code) |value| self.allocator.free(value);
            return error.InvalidTaskTransition;
        }
        task.state = .failed;
        if (task.started_at_ms == null) {
            task.started_at_ms = (blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); });
        }
        task.finished_at_ms = (blk: { const io = std.Io.Threaded.global_single_threaded.*.io(); break :blk std.Io.Timestamp.now(io, .real).toMilliseconds(); });
        if (task.error_code) |existing| self.allocator.free(existing);
        task.error_code = owned_error_code;
        if (task.result_json) |result_json| {
            self.allocator.free(result_json);
            task.result_json = null;
        }
        payload = try self.taskEventPayloadLocked(task.*);
        defer self.allocator.free(payload);
        self.emitEvent("task.failed", payload);
    }

    fn findByIdLocked(self: *const Self, id: []const u8) ?*const TaskRecord {
        for (self.tasks.items) |*task| {
            if (std.mem.eql(u8, task.id, id)) {
                return task;
            }
        }
        return null;
    }

    fn findMutableByIdLocked(self: *Self, id: []const u8) ?*TaskRecord {
        for (self.tasks.items) |*task| {
            if (std.mem.eql(u8, task.id, id)) {
                return task;
            }
        }
        return null;
    }

    fn findByRequestIdLocked(self: *const Self, request_id: []const u8) ?*const TaskRecord {
        for (self.tasks.items) |*task| {
            if (task.request_id) |value| {
                if (std.mem.eql(u8, value, request_id)) {
                    return task;
                }
            }
        }
        return null;
    }

    fn taskEventPayloadLocked(self: *Self, task: TaskRecord) anyerror![]u8 {
        var buf: std.ArrayListUnmanaged(u8) = .empty;
        defer buf.deinit(self.allocator);

        const writer = buf.writer(self.allocator);
        try writer.writeAll("{\"taskId\":");
        try writeJsonString(writer, task.id);
        try writer.writeAll(",\"command\":");
        try writeJsonString(writer, task.command);
        try writer.writeAll(",\"state\":");
        try writeJsonString(writer, task.state.asText());
        if (task.request_id) |request_id| {
            try writer.writeAll(",\"requestId\":");
            try writeJsonString(writer, request_id);
        }
        if (task.started_at_ms) |started_at_ms| {
            try writer.print(",\"startedAtMs\":{d}", .{started_at_ms});
        }
        if (task.finished_at_ms) |finished_at_ms| {
            try writer.print(",\"finishedAtMs\":{d}", .{finished_at_ms});
        }
        if (task.started_at_ms != null and task.finished_at_ms != null and task.finished_at_ms.? >= task.started_at_ms.?) {
            try writer.print(",\"durationMs\":{d}", .{task.finished_at_ms.? - task.started_at_ms.?});
        }
        if (task.error_code) |error_code| {
            try writer.writeAll(",\"errorCode\":");
            try writeJsonString(writer, error_code);
        }
        if (task.result_json) |result_json| {
            try writer.writeAll(",\"result\":");
            try writer.writeAll(result_json);
        }
        try writer.writeByte('}');
        return self.allocator.dupe(u8, buf.items);
    }

    fn emitEvent(self: *Self, topic: []const u8, payload_json: []const u8) void {
        if (self.event_bus) |event_bus| {
            _ = event_bus.publish(topic, payload_json) catch {};
        }
        if (self.observer) |observer| {
            observer.record(topic, payload_json) catch {};
        }
    }

    fn taskThreadMain(execution: *AsyncExecution) void {
        defer {
            execution.job.deinit(execution.runner.allocator);
            execution.runner.allocator.free(execution.task_id);
            execution.runner.allocator.destroy(execution);
        }

        execution.runner.markRunning(execution.task_id) catch {
            return;
        };

        const result_json = execution.job.run(execution.runner.allocator) catch |err| {
            execution.runner.markFailed(execution.task_id, @errorName(err)) catch {};
            return;
        };

        execution.runner.markSucceededWithResult(execution.task_id, result_json) catch {
            execution.runner.allocator.free(result_json);
        };
    }
};

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

test "task runner accepts and stores queued tasks" {
    var runner = TaskRunner.init(std.testing.allocator);
    defer runner.deinit();

    const accepted = try runner.submit("diagnostics.doctor", "req_01");
    const summary = (try runner.snapshotById(std.testing.allocator, accepted.task_id)).?;
    defer {
        var mutable_summary = summary;
        mutable_summary.deinit(std.testing.allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), runner.count());
    try std.testing.expectEqualStrings("queued", accepted.state);
    try std.testing.expectEqual(TaskState.queued, summary.state);
}

test "task runner supports state transitions and request lookup" {
    var runner = TaskRunner.init(std.testing.allocator);
    defer runner.deinit();

    const accepted = try runner.submit("diagnostics.doctor", "req_02");
    try runner.markRunning(accepted.task_id);
    try runner.markFailed(accepted.task_id, "RUNTIME_TASK_FAILED");

    const by_id = (try runner.snapshotById(std.testing.allocator, accepted.task_id)).?;
    defer {
        var mutable_summary = by_id;
        mutable_summary.deinit(std.testing.allocator);
    }
    const by_request = (try runner.snapshotByRequestId(std.testing.allocator, "req_02")).?;
    defer {
        var mutable_summary = by_request;
        mutable_summary.deinit(std.testing.allocator);
    }

    try std.testing.expectEqual(TaskState.failed, by_id.state);
    try std.testing.expectEqualStrings("req_02", by_request.request_id.?);
    try std.testing.expectEqual(@as(usize, 1), runner.countByState(.failed));
}

test "task runner can cancel and snapshot tasks" {
    var runner = TaskRunner.init(std.testing.allocator);
    defer runner.deinit();

    const accepted = try runner.submit("logs.export", null);
    try runner.cancel(accepted.task_id);

    const snapshots = try runner.snapshot(std.testing.allocator);
    defer {
        for (snapshots) |*snapshot| {
            snapshot.deinit(std.testing.allocator);
        }
        std.testing.allocator.free(snapshots);
    }

    const latest = (try runner.latest(std.testing.allocator)).?;
    defer {
        var mutable_summary = latest;
        mutable_summary.deinit(std.testing.allocator);
    }

    try std.testing.expectEqual(@as(usize, 1), snapshots.len);
    try std.testing.expectEqual(TaskState.cancelled, snapshots[0].state);
    try std.testing.expectEqual(TaskState.cancelled, latest.state);
}

test "task runner executes async jobs and stores result" {
    const Job = struct {
        message: []const u8,

        fn run(ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]u8 {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            std.Thread.sleep(10 * std.time.ns_per_ms);
            return allocator.dupe(u8, self.message);
        }

        fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
            const self: *@This() = @ptrCast(@alignCast(ptr));
            allocator.destroy(self);
        }
    };

    var observer = observer_model.MemoryObserver.init(std.testing.allocator);
    defer observer.deinit();
    var event_bus = event_bus_model.MemoryEventBus.init(std.testing.allocator);
    defer event_bus.deinit();

    var runner = TaskRunner.initWithObservability(std.testing.allocator, observer.asObserver(), event_bus.asEventBus());
    defer runner.deinit();

    const job = try std.testing.allocator.create(Job);
    job.* = .{ .message = "{\"ok\":true}" };

    const accepted = try runner.submitJob("diagnostics.doctor", "req_async", .{
        .ptr = @ptrCast(job),
        .vtable = &.{
            .run = Job.run,
            .deinit = Job.deinit,
        },
    });

    const summary = try runner.waitForCompletion(std.testing.allocator, accepted.task_id, 1000);
    defer {
        var mutable_summary = summary;
        mutable_summary.deinit(std.testing.allocator);
    }

    const events = try event_bus.snapshot(std.testing.allocator);
    defer {
        for (events) |*event| event.deinit(std.testing.allocator);
        std.testing.allocator.free(events);
    }

    try std.testing.expectEqual(TaskState.succeeded, summary.state);
    try std.testing.expectEqualStrings("{\"ok\":true}", summary.result_json.?);
    try std.testing.expect(observer.count() >= 3);
    try std.testing.expect(event_bus.count() >= 3);
}


