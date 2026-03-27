const std = @import("std");
const framework = @import("framework");

pub fn main() !void {
    var app_context = try framework.AppContext.init(std.heap.page_allocator, .{
        .console_log_enabled = true,
    });
    defer app_context.deinit();

    const Demo = struct {
        fn call(ctx: *const framework.CommandContext) anyerror![]u8 {
            var step = try framework.StepTrace.begin(
                ctx.allocator,
                ctx.logger.logger,
                "workflow/demo",
                "command",
                100,
            );
            defer step.deinit();
            step.finish(null);
            return ctx.allocator.dupe(u8, "{\"workflow\":true}");
        }
    };

    try app_context.command_registry.register(.{
        .id = "demo.workflow.trace",
        .method = "demo.workflow.trace",
        .handler = Demo.call,
    });

    var effects_runtime = framework.EffectsRuntime.init(.{});
    var request_trace = try framework.observability.request_trace.begin(
        std.heap.page_allocator,
        app_context.logger,
        .cli,
        "workflow_obs_demo",
        "RUN",
        "workflow.demo",
        null,
    );
    defer request_trace.deinit();

    var runner = framework.WorkflowRunner.init(
        std.heap.page_allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
    );

    const steps = [_]framework.WorkflowStep{
        .{ .command = .{ .method = "demo.workflow.trace" } },
    };
    var result = try runner.run(.{
        .id = "workflow.obs.demo",
        .steps = steps[0..],
    });
    defer result.deinit(std.heap.page_allocator);

    framework.observability.request_trace.complete(app_context.logger, &request_trace, 200, null);
}
