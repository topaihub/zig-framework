const std = @import("std");
const framework = @import("../src/root.zig");

pub fn main() !void {
    var app_context = try framework.AppContext.init(std.heap.page_allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();

    const Demo = struct {
        fn call(_: *const framework.CommandContext) anyerror![]const u8 {
            return std.heap.page_allocator.dupe(u8, "{\"ok\":true}");
        }
    };

    try app_context.command_registry.register(.{
        .id = "demo.workflow.checkpoint",
        .method = "demo.workflow.checkpoint",
        .handler = Demo.call,
    });

    var effects_runtime = framework.EffectsRuntime.init(.{});
    const store_ref = framework.MemoryCheckpointStore.init(std.heap.page_allocator);
    defer store_ref.deinit();

    var runner = framework.WorkflowRunner.init(
        std.heap.page_allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        store_ref.asCheckpointStore(),
    );

    const workflow = framework.WorkflowDefinition{
        .id = "workflow.demo.checkpoint",
        .description = "checkpoint demo",
        .steps = &[_]framework.WorkflowStep{
            .{ .command = .{ .method = "demo.workflow.checkpoint" } },
            .{ .emit_event = .{ .topic = "demo.workflow.done", .payload_json = "{\"phase\":\"done\"}" } },
        },
    };

    var result = try runner.run(workflow);
    defer result.deinit(std.heap.page_allocator);

    const checkpoint = (try store_ref.load(std.heap.page_allocator, result.run_id.?)).?;
    defer {
        var mutable = checkpoint;
        mutable.deinit(std.heap.page_allocator);
    }

    try std.fs.File.stdout().writeAll("workflow checkpoint demo\n");
    try std.fs.File.stdout().writeAll("run id: ");
    try std.fs.File.stdout().writeAll(result.run_id.?);
    try std.fs.File.stdout().writeAll("\nstatus: ");
    try std.fs.File.stdout().writeAll(checkpoint.workflow_status.asText());
    try std.fs.File.stdout().writeAll("\n");
}
