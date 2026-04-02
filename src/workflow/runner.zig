const std = @import("std");
const builtin = @import("builtin");
const app = @import("../app/root.zig");
const core = @import("../core/root.zig");
const effects = @import("../effects/root.zig");
const framework = @import("../root.zig");
const runtime = @import("../runtime/root.zig");
const checkpoint_store = @import("checkpoint_store.zig");
const definition = @import("definition.zig");
const state = @import("state.zig");
const step_types = @import("step_types.zig");

pub const WorkflowRunner = struct {
    allocator: std.mem.Allocator,
    dispatcher: app.CommandDispatcher,
    effects: *effects.EffectsRuntime,
    logger: ?*core.logging.Logger = null,
    event_bus: ?runtime.EventBus = null,
    task_runner: ?*runtime.TaskRunner = null,
    checkpoints: ?checkpoint_store.WorkflowCheckpointStore = null,

    pub fn init(
        allocator: std.mem.Allocator,
        dispatcher: app.CommandDispatcher,
        effects_runtime: *effects.EffectsRuntime,
        logger: ?*core.logging.Logger,
        event_bus: ?runtime.EventBus,
        task_runner: ?*runtime.TaskRunner,
        checkpoints: ?checkpoint_store.WorkflowCheckpointStore,
    ) WorkflowRunner {
        return .{
            .allocator = allocator,
            .dispatcher = dispatcher,
            .effects = effects_runtime,
            .logger = logger,
            .event_bus = event_bus,
            .task_runner = task_runner,
            .checkpoints = checkpoints,
        };
    }

    pub fn run(self: *WorkflowRunner, workflow: definition.WorkflowDefinition) !state.WorkflowRunResult {
        const run_id = try std.fmt.allocPrint(self.allocator, "{s}:{d}", .{ workflow.id, std.time.milliTimestamp() });
        defer self.allocator.free(run_id);
        return self.runWithCheckpoint(workflow, run_id, null);
    }

    pub fn runWithCheckpoint(
        self: *WorkflowRunner,
        workflow: definition.WorkflowDefinition,
        run_id: []const u8,
        resume_from: ?state.WorkflowCheckpoint,
    ) !state.WorkflowRunResult {
        var method_trace: ?framework.MethodTrace = null;
        var summary_trace: ?framework.SummaryTrace = null;
        if (self.logger) |logger| {
            method_trace = try framework.MethodTrace.begin(
                self.allocator,
                logger,
                "WorkflowRunner.run",
                workflow.id,
                500,
            );
            summary_trace = try framework.SummaryTrace.begin(
                self.allocator,
                logger,
                "WorkflowRunner.run",
                500,
            );
        }
        defer {
            if (method_trace) |*trace| trace.deinit();
            if (summary_trace) |*trace| trace.deinit();
        }

        var step_statuses = try self.allocator.alloc(state.WorkflowStepStatus, workflow.steps.len);
        defer self.allocator.free(step_statuses);
        @memset(step_statuses, .pending);

        var result: state.WorkflowRunResult = .{
            .status = .running,
            .completed_steps = 0,
            .run_id = try self.allocator.dupe(u8, run_id),
        };
        errdefer {
            result.deinit(self.allocator);
            result.status = .failed;
            if (method_trace) |*trace| trace.finishError("WorkflowRunFailed", null, false);
            if (summary_trace) |*trace| trace.finishError(.system);
        }

        var next_step_index: usize = 0;
        if (resume_from) |checkpoint| {
            if (checkpoint.workflow_status == .succeeded or checkpoint.workflow_status == .failed) {
                return error.WorkflowRunAlreadyTerminal;
            }
            if (!std.mem.eql(u8, checkpoint.workflow_id, workflow.id)) {
                return error.WorkflowCheckpointMismatch;
            }
            if (checkpoint.step_statuses.len != workflow.steps.len) {
                return error.WorkflowCheckpointMismatch;
            }
            @memcpy(step_statuses, checkpoint.step_statuses);
            next_step_index = checkpoint.current_step_index;
            result.status = checkpoint.workflow_status;
            result.completed_steps = countCompletedSteps(step_statuses);
            if (checkpoint.last_output_json) |value| result.last_output_json = try self.allocator.dupe(u8, value);
            if (checkpoint.last_error_code) |value| result.last_error_code = try self.allocator.dupe(u8, value);
        } else {
            try self.emitEvent("workflow.started", workflow.id, null);
            self.logInfo("workflow started", workflow.id, &.{
                framework.LogField.int("step_count", @intCast(workflow.steps.len)),
            });
        }

        try self.saveCheckpoint(.{
            .run_id = try self.allocator.dupe(u8, run_id),
            .workflow_id = try self.allocator.dupe(u8, workflow.id),
            .workflow_status = .running,
            .current_step_index = next_step_index,
            .step_statuses = try self.allocator.dupe(state.WorkflowStepStatus, step_statuses),
            .last_output_json = if (result.last_output_json) |value| try self.allocator.dupe(u8, value) else null,
            .last_error_code = if (result.last_error_code) |value| try self.allocator.dupe(u8, value) else null,
        });

        var index = next_step_index;
        while (index < workflow.steps.len) : (index += 1) {
            step_statuses[index] = .running;
            try self.saveCheckpoint(.{
                .run_id = try self.allocator.dupe(u8, run_id),
                .workflow_id = try self.allocator.dupe(u8, workflow.id),
                .workflow_status = .running,
                .current_step_index = index,
                .step_statuses = try self.allocator.dupe(state.WorkflowStepStatus, step_statuses),
                .last_output_json = if (result.last_output_json) |value| try self.allocator.dupe(u8, value) else null,
                .last_error_code = if (result.last_error_code) |value| try self.allocator.dupe(u8, value) else null,
            });

            switch (workflow.steps[index]) {
                .command => |command_step| {
                    const output = try self.executeCommand(command_step);
                    if (result.last_output_json) |value| self.allocator.free(value);
                    result.last_output_json = output;
                },
                .shell => |shell_step| {
                    const output = try self.executeShell(shell_step);
                    if (result.last_output_json) |value| self.allocator.free(value);
                    result.last_output_json = output;
                },
                .emit_event => |event_step| {
                    _ = try (self.event_bus orelse return error.EventBusNotConfigured).publish(event_step.topic, event_step.payload_json);
                },
                .retry => |retry_step| {
                    const output = try self.executeRetry(retry_step);
                    if (result.last_output_json) |value| self.allocator.free(value);
                    result.last_output_json = output;
                },
            }

            step_statuses[index] = .succeeded;
            result.completed_steps += 1;
            try self.saveCheckpoint(.{
                .run_id = try self.allocator.dupe(u8, run_id),
                .workflow_id = try self.allocator.dupe(u8, workflow.id),
                .workflow_status = .running,
                .current_step_index = index + 1,
                .step_statuses = try self.allocator.dupe(state.WorkflowStepStatus, step_statuses),
                .last_output_json = if (result.last_output_json) |value| try self.allocator.dupe(u8, value) else null,
                .last_error_code = if (result.last_error_code) |value| try self.allocator.dupe(u8, value) else null,
            });
        }

        result.status = .succeeded;
        try self.emitEvent("workflow.completed", workflow.id, null);
        self.logInfo("workflow completed", workflow.id, &.{
            framework.LogField.int("completed_steps", @intCast(result.completed_steps)),
        });
        try self.saveCheckpoint(.{
            .run_id = try self.allocator.dupe(u8, run_id),
            .workflow_id = try self.allocator.dupe(u8, workflow.id),
            .workflow_status = .succeeded,
            .current_step_index = workflow.steps.len,
            .step_statuses = try self.allocator.dupe(state.WorkflowStepStatus, step_statuses),
            .last_output_json = if (result.last_output_json) |value| try self.allocator.dupe(u8, value) else null,
            .last_error_code = if (result.last_error_code) |value| try self.allocator.dupe(u8, value) else null,
        });

        if (method_trace) |*trace| trace.finishSuccess(result.last_output_json orelse "", false);
        if (summary_trace) |*trace| trace.finishSuccess();
        return result;
    }

    pub fn resumeRun(self: *WorkflowRunner, workflow: definition.WorkflowDefinition, run_id: []const u8) !state.WorkflowRunResult {
        const store = self.checkpoints orelse return error.WorkflowCheckpointStoreNotConfigured;
        var checkpoint = (try store.load(self.allocator, run_id)) orelse return error.WorkflowCheckpointNotFound;
        defer checkpoint.deinit(self.allocator);
        return self.runWithCheckpoint(workflow, checkpoint.run_id, checkpoint);
    }

    pub fn submit(self: *WorkflowRunner, workflow: definition.WorkflowDefinition) !framework.TaskAccepted {
        const runner = self.task_runner orelse return error.TaskRunnerNotConfigured;
        const job = try self.allocator.create(WorkflowJobData);
        errdefer self.allocator.destroy(job);
        job.* = try WorkflowJobData.init(self.allocator, self, workflow);

        return runner.submitJob("workflow.run", workflow.id, .{
            .ptr = @ptrCast(job),
            .vtable = &.{
                .run = WorkflowJobData.run,
                .deinit = WorkflowJobData.deinit,
            },
        });
    }

    fn executeCommand(self: *WorkflowRunner, step: step_types.CommandStep) ![]u8 {
        var envelope = try self.dispatcher.dispatch(.{
            .request_id = "workflow_command_step",
            .method = step.method,
            .params = step.params,
            .source = .@"test",
            .authority = .public,
        }, false);
        defer if (envelope.result) |*result| {
            switch (result.*) {
                .success_json => |json| self.allocator.free(json),
                else => {},
            }
        };

        if (!envelope.ok) {
            return error.WorkflowStepFailed;
        }
        return switch (envelope.result.?) {
            .success_json => |json| try self.allocator.dupe(u8, json),
            else => error.WorkflowStepFailed,
        };
    }

    fn executeShell(self: *WorkflowRunner, step: step_types.ShellStep) ![]u8 {
        var result = try self.effects.process_runner.run(self.allocator, .{
            .argv = step.argv,
            .cwd = step.cwd,
        });
        defer result.deinit(self.allocator);
        if (result.exit_code != 0) return error.WorkflowStepFailed;
        return try self.allocator.dupe(u8, result.stdout);
    }

    fn executeRetry(self: *WorkflowRunner, step: step_types.RetryStep) ![]u8 {
        var last_err: anyerror = error.WorkflowRetryExhausted;
        var attempt: usize = 0;
        while (attempt < step.attempts) : (attempt += 1) {
            const output = switch (step.target) {
                .command => |command_step| self.executeCommand(command_step),
                .shell => |shell_step| self.executeShell(shell_step),
            } catch |err| {
                last_err = err;
                if (step.delay_ms > 0) self.effects.clock.sleepMs(step.delay_ms);
                continue;
            };
            return output;
        }
        return last_err;
    }

    fn saveCheckpoint(self: *WorkflowRunner, checkpoint: state.WorkflowCheckpoint) !void {
        const store = self.checkpoints orelse {
            var mutable = checkpoint;
            mutable.deinit(self.allocator);
            return;
        };
        defer {
            var mutable = checkpoint;
            mutable.deinit(self.allocator);
        }
        try store.save(self.allocator, checkpoint);
    }

    fn emitEvent(self: *WorkflowRunner, topic: []const u8, workflow_id: []const u8, error_code: ?[]const u8) !void {
        const bus = self.event_bus orelse return;
        const payload = if (error_code) |code|
            try std.fmt.allocPrint(self.allocator, "{{\"workflow_id\":\"{s}\",\"error_code\":\"{s}\"}}", .{ workflow_id, code })
        else
            try std.fmt.allocPrint(self.allocator, "{{\"workflow_id\":\"{s}\"}}", .{workflow_id});
        defer self.allocator.free(payload);
        _ = try bus.publish(topic, payload);
    }

    fn logInfo(self: *WorkflowRunner, message: []const u8, workflow_id: []const u8, fields: []const framework.LogField) void {
        const logger = self.logger orelse return;
        logger.child("workflow").child("runner").withField(framework.LogField.string("workflow_id", workflow_id)).info(message, fields);
    }
};

fn countCompletedSteps(step_statuses: []const state.WorkflowStepStatus) usize {
    var count: usize = 0;
    for (step_statuses) |item| {
        if (item == .succeeded or item == .skipped) count += 1;
    }
    return count;
}

const WorkflowJobData = struct {
    runner: *WorkflowRunner,
    workflow_id: []u8,
    description: []u8,
    steps: []step_types.WorkflowStep,

    fn init(allocator: std.mem.Allocator, runner: *WorkflowRunner, workflow: definition.WorkflowDefinition) !WorkflowJobData {
        const steps = try allocator.alloc(step_types.WorkflowStep, workflow.steps.len);
        errdefer allocator.free(steps);
        @memcpy(steps, workflow.steps);

        return .{
            .runner = runner,
            .workflow_id = try allocator.dupe(u8, workflow.id),
            .description = try allocator.dupe(u8, workflow.description),
            .steps = steps,
        };
    }

    fn run(ptr: *anyopaque, allocator: std.mem.Allocator) anyerror![]u8 {
        const self: *WorkflowJobData = @ptrCast(@alignCast(ptr));
        var result = try self.runner.run(.{
            .id = self.workflow_id,
            .description = self.description,
            .steps = self.steps,
        });
        defer result.deinit(allocator);

        return std.fmt.allocPrint(allocator, "{{\"status\":{f},\"completed_steps\":{d},\"run_id\":{f}}}", .{
            std.json.fmt(result.status.asText(), .{}),
            result.completed_steps,
            std.json.fmt(result.run_id orelse "", .{}),
        });
    }

    fn deinit(ptr: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *WorkflowJobData = @ptrCast(@alignCast(ptr));
        allocator.free(self.workflow_id);
        allocator.free(self.description);
        allocator.free(self.steps);
        allocator.destroy(self);
    }
};

test "workflow runner executes sequential steps successfully" {
    const Demo = struct {
        fn call(_: *const app.CommandContext) anyerror![]const u8 {
            return std.testing.allocator.dupe(u8, "{\"ok\":true}");
        }
    };

    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();
    try app_context.command_registry.register(.{
        .id = "demo.workflow",
        .method = "demo.workflow",
        .handler = Demo.call,
    });

    var effects_runtime = effects.EffectsRuntime.init(.{});
    const store_ref = checkpoint_store.MemoryCheckpointStore.init(std.testing.allocator);
    defer store_ref.deinit();

    var runner = WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        store_ref.asCheckpointStore(),
    );

    const steps = [_]step_types.WorkflowStep{
        .{ .command = .{ .method = "demo.workflow" } },
        .{ .emit_event = .{ .topic = "demo.event", .payload_json = "{\"phase\":\"done\"}" } },
    };
    var result = try runner.run(.{
        .id = "workflow.demo",
        .steps = steps[0..],
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(state.WorkflowStatus.succeeded, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.completed_steps);
    try std.testing.expectEqualStrings("{\"ok\":true}", result.last_output_json.?);
    try std.testing.expect(result.run_id != null);
}

test "workflow runner saves checkpoint after step completion" {
    const Demo = struct {
        fn call(_: *const app.CommandContext) anyerror![]const u8 {
            return std.testing.allocator.dupe(u8, "{\"saved\":true}");
        }
    };

    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();
    try app_context.command_registry.register(.{
        .id = "demo.checkpoint",
        .method = "demo.checkpoint",
        .handler = Demo.call,
    });

    var effects_runtime = effects.EffectsRuntime.init(.{});
    const store_ref = checkpoint_store.MemoryCheckpointStore.init(std.testing.allocator);
    defer store_ref.deinit();

    var runner = WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        store_ref.asCheckpointStore(),
    );

    const workflow = definition.WorkflowDefinition{
        .id = "workflow.checkpoint",
        .steps = &[_]step_types.WorkflowStep{
            .{ .command = .{ .method = "demo.checkpoint" } },
        },
    };

    var result = try runner.run(workflow);
    defer result.deinit(std.testing.allocator);

    var checkpoint = (try store_ref.load(std.testing.allocator, result.run_id.?)).?;
    defer checkpoint.deinit(std.testing.allocator);
    try std.testing.expectEqual(state.WorkflowStatus.succeeded, checkpoint.workflow_status);
    try std.testing.expectEqual(@as(usize, 1), checkpoint.current_step_index);
}

test "workflow runner can resume from stored checkpoint" {
    const Demo = struct {
        var calls: usize = 0;

        fn call(_: *const app.CommandContext) anyerror![]const u8 {
            calls += 1;
            return std.testing.allocator.dupe(u8, "{\"resumed\":true}");
        }
    };

    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();
    try app_context.command_registry.register(.{
        .id = "demo.resume",
        .method = "demo.resume",
        .handler = Demo.call,
    });

    var effects_runtime = effects.EffectsRuntime.init(.{});
    const store_ref = checkpoint_store.MemoryCheckpointStore.init(std.testing.allocator);
    defer store_ref.deinit();

    var runner = WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        store_ref.asCheckpointStore(),
    );

    const workflow = definition.WorkflowDefinition{
        .id = "workflow.resume",
        .steps = &[_]step_types.WorkflowStep{
            .{ .command = .{ .method = "demo.resume" } },
            .{ .command = .{ .method = "demo.resume" } },
        },
    };

    var stored = state.WorkflowCheckpoint{
        .run_id = try std.testing.allocator.dupe(u8, "resume_run_01"),
        .workflow_id = try std.testing.allocator.dupe(u8, "workflow.resume"),
        .workflow_status = .running,
        .current_step_index = 1,
        .step_statuses = try std.testing.allocator.dupe(state.WorkflowStepStatus, &[_]state.WorkflowStepStatus{ .succeeded, .pending }),
        .last_output_json = try std.testing.allocator.dupe(u8, "{\"resumed\":true}"),
    };
    defer stored.deinit(std.testing.allocator);
    try store_ref.save(stored);

    Demo.calls = 0;
    var result = try runner.resumeRun(workflow, "resume_run_01");
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), Demo.calls);
    try std.testing.expectEqual(state.WorkflowStatus.succeeded, result.status);
    try std.testing.expectEqual(@as(usize, 2), result.completed_steps);
}

test "workflow runner cannot resume terminal checkpoint" {
    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();

    var effects_runtime = effects.EffectsRuntime.init(.{});
    const store_ref = checkpoint_store.MemoryCheckpointStore.init(std.testing.allocator);
    defer store_ref.deinit();

    var runner = WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        store_ref.asCheckpointStore(),
    );

    var stored = state.WorkflowCheckpoint{
        .run_id = try std.testing.allocator.dupe(u8, "terminal_run_01"),
        .workflow_id = try std.testing.allocator.dupe(u8, "workflow.terminal"),
        .workflow_status = .succeeded,
        .current_step_index = 1,
        .step_statuses = try std.testing.allocator.dupe(state.WorkflowStepStatus, &[_]state.WorkflowStepStatus{.succeeded}),
    };
    defer stored.deinit(std.testing.allocator);
    try store_ref.save(stored);

    try std.testing.expectError(error.WorkflowRunAlreadyTerminal, runner.resumeRun(.{
        .id = "workflow.terminal",
        .steps = &[_]step_types.WorkflowStep{
            .{ .emit_event = .{ .topic = "noop", .payload_json = "{}" } },
        },
    }, "terminal_run_01"));
}

test "workflow runner retries and succeeds" {
    const Demo = struct {
        var attempts: usize = 0;
        fn call(_: *const app.CommandContext) anyerror![]const u8 {
            attempts += 1;
            if (attempts < 2) return error.AccessDenied;
            return std.testing.allocator.dupe(u8, "{\"retry\":true}");
        }
    };

    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();
    try app_context.command_registry.register(.{
        .id = "demo.retry",
        .method = "demo.retry",
        .handler = Demo.call,
    });

    var effects_runtime = effects.EffectsRuntime.init(.{});
    var runner = WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        null,
    );

    const steps = [_]step_types.WorkflowStep{
        .{ .retry = .{
            .attempts = 3,
            .target = .{ .command = .{ .method = "demo.retry" } },
        } },
    };
    var result = try runner.run(.{
        .id = "workflow.retry",
        .steps = steps[0..],
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expectEqual(state.WorkflowStatus.succeeded, result.status);
    try std.testing.expectEqualStrings("{\"retry\":true}", result.last_output_json.?);
}

test "workflow runner retry fails after budget" {
    const command = switch (builtin.os.tag) {
        .windows => "exit /B 9",
        else => "exit 9",
    };

    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();

    var effects_runtime = effects.EffectsRuntime.init(.{});
    var runner = WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        null,
    );

    const shell_args = switch (builtin.os.tag) {
        .windows => &[_][]const u8{ "cmd.exe", "/C", command },
        else => &[_][]const u8{ "sh", "-c", command },
    };

    const steps = [_]step_types.WorkflowStep{
        .{ .retry = .{
            .attempts = 2,
            .target = .{ .shell = .{ .argv = shell_args[0..] } },
        } },
    };

    try std.testing.expectError(error.WorkflowStepFailed, runner.run(.{
        .id = "workflow.retry.fail",
        .steps = steps[0..],
    }));
}

test "workflow runner can submit async workflow task" {
    const Demo = struct {
        fn call(_: *const app.CommandContext) anyerror![]const u8 {
            return std.testing.allocator.dupe(u8, "{\"submitted\":true}");
        }
    };

    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();
    try app_context.command_registry.register(.{
        .id = "demo.async",
        .method = "demo.async",
        .handler = Demo.call,
    });

    var effects_runtime = effects.EffectsRuntime.init(.{});
    var runner = WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        null,
    );

    const steps = [_]step_types.WorkflowStep{
        .{ .command = .{ .method = "demo.async" } },
    };
    const accepted = try runner.submit(.{
        .id = "workflow.async",
        .steps = steps[0..],
    });

    try std.testing.expectEqualStrings("queued", accepted.state);
    var summary = try app_context.task_runner.waitForCompletion(std.testing.allocator, accepted.task_id, 2000);
    defer summary.deinit(std.testing.allocator);
    try std.testing.expect(summary.state.isTerminal());
    try std.testing.expectEqual(runtime.TaskState.succeeded, summary.state);
}
