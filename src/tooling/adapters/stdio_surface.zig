const std = @import("std");
const app = @import("../../app/root.zig");
const checkpoint_store = @import("../../workflow/checkpoint_store.zig");
const core = @import("../../core/root.zig");
const effects = @import("../../effects/root.zig");
const runtime = @import("../../runtime/root.zig");
const workflow = @import("../../workflow/root.zig");
const tool_runner = @import("../tool_runner.zig");

pub const RequestKind = enum {
    tool,
    workflow,
};

pub const StdioRequest = struct {
    kind: RequestKind,
    request_id: []const u8,
    authority: app.Authority = .public,
    tool_id: ?[]const u8 = null,
    workflow_id: ?[]const u8 = null,
    params: []const core.validation.ValidationField = &.{},
    workflow: ?workflow.WorkflowDefinition = null,
};

pub const StdioSuccess = struct {
    ok: bool = true,
    kind: RequestKind,
    request_id: []const u8,
    output_json: ?[]const u8 = null,
    run_id: ?[]const u8 = null,
    status: ?[]const u8 = null,

    pub fn deinit(self: *StdioSuccess, allocator: std.mem.Allocator) void {
        if (self.output_json) |value| allocator.free(value);
        if (self.run_id) |value| allocator.free(value);
        if (self.status) |value| allocator.free(value);
    }
};

pub const StdioFailure = struct {
    ok: bool = false,
    request_id: []const u8,
    error_code: []const u8,
    message: []const u8,
};

pub const StdioResponse = union(enum) {
    success: StdioSuccess,
    failure: StdioFailure,

    pub fn deinit(self: *StdioResponse, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .success => |*value| value.deinit(allocator),
            .failure => {},
        }
    }
};

pub const StdioSurface = struct {
    allocator: std.mem.Allocator,
    tool_runner: *tool_runner.ToolRunner,
    workflow_runner: *workflow.WorkflowRunner,
    event_bus: runtime.EventBus,

    pub fn init(
        allocator: std.mem.Allocator,
        tool_runner_ref: *tool_runner.ToolRunner,
        workflow_runner_ref: *workflow.WorkflowRunner,
        event_bus: runtime.EventBus,
    ) StdioSurface {
        return .{
            .allocator = allocator,
            .tool_runner = tool_runner_ref,
            .workflow_runner = workflow_runner_ref,
            .event_bus = event_bus,
        };
    }

    pub fn execute(self: *StdioSurface, request: StdioRequest) !StdioResponse {
        return switch (request.kind) {
            .tool => self.executeTool(request),
            .workflow => self.executeWorkflow(request),
        };
    }

    pub fn renderResponse(self: *StdioSurface, response: StdioResponse) ![]u8 {
        var buffer: std.ArrayListUnmanaged(u8) = .empty;
        defer buffer.deinit(self.allocator);
        const writer = buffer.writer(self.allocator);

        switch (response) {
            .success => |value| {
                try writer.writeByte('{');
                try writer.print("\"ok\":true,\"kind\":{f},\"request_id\":{f}", .{
                    std.json.fmt(@tagName(value.kind), .{}),
                    std.json.fmt(value.request_id, .{}),
                });
                if (value.output_json) |output_json| {
                    try writer.writeAll(",\"output_json\":");
                    try writer.writeAll(output_json);
                }
                if (value.run_id) |run_id| {
                    try writer.print(",\"run_id\":{f}", .{std.json.fmt(run_id, .{})});
                }
                if (value.status) |status| {
                    try writer.print(",\"status\":{f}", .{std.json.fmt(status, .{})});
                }
                try writer.writeByte('}');
            },
            .failure => |value| {
                try writer.print("{{\"ok\":false,\"request_id\":{f},\"error_code\":{f},\"message\":{f}}}", .{
                    std.json.fmt(value.request_id, .{}),
                    std.json.fmt(value.error_code, .{}),
                    std.json.fmt(value.message, .{}),
                });
            },
        }

        return try self.allocator.dupe(u8, buffer.items);
    }

    fn executeTool(self: *StdioSurface, request: StdioRequest) !StdioResponse {
        const tool_id = request.tool_id orelse return .{
            .failure = .{
                .request_id = request.request_id,
                .error_code = "STDIO_TOOL_ID_REQUIRED",
                .message = "tool_id is required",
            },
        };

        var result = self.tool_runner.run(.{
            .tool_id = tool_id,
            .request = .{
                .request_id = request.request_id,
                .source = .service,
                .authority = request.authority,
            },
            .params = request.params,
        }) catch |err| {
            return .{
                .failure = .{
                    .request_id = request.request_id,
                    .error_code = @errorName(err),
                    .message = "tool execution failed",
                },
            };
        };
        defer result.deinit(self.allocator);

        return .{
            .success = .{
                .kind = .tool,
                .request_id = request.request_id,
                .output_json = try self.allocator.dupe(u8, result.output_json),
            },
        };
    }

    fn executeWorkflow(self: *StdioSurface, request: StdioRequest) !StdioResponse {
        const workflow_def = request.workflow orelse return .{
            .failure = .{
                .request_id = request.request_id,
                .error_code = "STDIO_WORKFLOW_REQUIRED",
                .message = "workflow definition is required",
            },
        };

        var result = self.workflow_runner.run(workflow_def) catch |err| {
            return .{
                .failure = .{
                    .request_id = request.request_id,
                    .error_code = @errorName(err),
                    .message = "workflow execution failed",
                },
            };
        };
        defer result.deinit(self.allocator);

        return .{
            .success = .{
                .kind = .workflow,
                .request_id = request.request_id,
                .output_json = if (result.last_output_json) |value| try self.allocator.dupe(u8, value) else null,
                .run_id = if (result.run_id) |value| try self.allocator.dupe(u8, value) else null,
                .status = try self.allocator.dupe(u8, result.status.asText()),
            },
        };
    }
};

test "stdio surface executes tool request and renders success response" {
    const Demo = struct {
        fn call(ctx: *const @import("../tool_context.zig").ToolContext) ![]u8 {
            return ctx.allocator.dupe(u8, "{\"stdio\":true}");
        }
    };

    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();

    var effects_runtime = effects.EffectsRuntime.init(.{});
    var tools = @import("../tool_registry.zig").ToolRegistry.init(std.testing.allocator);
    defer tools.deinit();
    try tools.register(.{
        .id = "demo.stdio",
        .description = "stdio tool",
        .native_handler = Demo.call,
    });

    var tool_runner_ref = tool_runner.ToolRunner.init(
        std.testing.allocator,
        &tools,
        &effects_runtime,
        null,
        app_context.logger,
        app_context.eventBus(),
    );

    const store_ref = checkpoint_store.MemoryCheckpointStore.init(std.testing.allocator);
    defer store_ref.deinit();
    var workflow_runner_ref = workflow.WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        store_ref.asCheckpointStore(),
    );

    var surface = StdioSurface.init(
        std.testing.allocator,
        &tool_runner_ref,
        &workflow_runner_ref,
        app_context.eventBus(),
    );

    var response = try surface.execute(.{
        .kind = .tool,
        .request_id = "stdio_tool_01",
        .tool_id = "demo.stdio",
    });
    defer response.deinit(std.testing.allocator);

    const rendered = try surface.renderResponse(response);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "\"ok\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\"stdio\":true") != null);
}

test "stdio surface executes workflow request and returns run metadata" {
    const Demo = struct {
        fn call(_: *const app.CommandContext) anyerror![]const u8 {
            return std.testing.allocator.dupe(u8, "{\"workflow_stdio\":true}");
        }
    };

    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();
    try app_context.command_registry.register(.{
        .id = "demo.workflow.stdio",
        .method = "demo.workflow.stdio",
        .handler = Demo.call,
    });

    var effects_runtime = effects.EffectsRuntime.init(.{});
    var tools = @import("../tool_registry.zig").ToolRegistry.init(std.testing.allocator);
    defer tools.deinit();
    var tool_runner_ref = tool_runner.ToolRunner.init(
        std.testing.allocator,
        &tools,
        &effects_runtime,
        null,
        app_context.logger,
        app_context.eventBus(),
    );

    const store_ref = checkpoint_store.MemoryCheckpointStore.init(std.testing.allocator);
    defer store_ref.deinit();
    var workflow_runner_ref = workflow.WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        store_ref.asCheckpointStore(),
    );

    var surface = StdioSurface.init(
        std.testing.allocator,
        &tool_runner_ref,
        &workflow_runner_ref,
        app_context.eventBus(),
    );

    var response = try surface.execute(.{
        .kind = .workflow,
        .request_id = "stdio_workflow_01",
        .workflow = .{
            .id = "workflow.stdio.demo",
            .steps = &[_]workflow.WorkflowStep{
                .{ .command = .{ .method = "demo.workflow.stdio" } },
            },
        },
    });
    defer response.deinit(std.testing.allocator);

    const rendered = try surface.renderResponse(response);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "\"kind\":\"workflow\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "\"status\":\"succeeded\"") != null);
}

test "stdio surface returns structured failure for missing tool id" {
    var app_context = try runtime.AppContext.init(std.testing.allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();

    var effects_runtime = effects.EffectsRuntime.init(.{});
    var tools = @import("../tool_registry.zig").ToolRegistry.init(std.testing.allocator);
    defer tools.deinit();
    var tool_runner_ref = tool_runner.ToolRunner.init(
        std.testing.allocator,
        &tools,
        &effects_runtime,
        null,
        app_context.logger,
        app_context.eventBus(),
    );
    const store_ref = checkpoint_store.MemoryCheckpointStore.init(std.testing.allocator);
    defer store_ref.deinit();
    var workflow_runner_ref = workflow.WorkflowRunner.init(
        std.testing.allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        store_ref.asCheckpointStore(),
    );

    var surface = StdioSurface.init(
        std.testing.allocator,
        &tool_runner_ref,
        &workflow_runner_ref,
        app_context.eventBus(),
    );

    var response = try surface.execute(.{
        .kind = .tool,
        .request_id = "stdio_fail_01",
    });
    defer response.deinit(std.testing.allocator);

    const rendered = try surface.renderResponse(response);
    defer std.testing.allocator.free(rendered);

    try std.testing.expect(std.mem.indexOf(u8, rendered, "\"ok\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, rendered, "STDIO_TOOL_ID_REQUIRED") != null);
}
