const std = @import("std");
const framework = @import("framework");

pub fn main() !void {
    var app_context = try framework.AppContext.init(std.heap.page_allocator, .{
        .console_log_enabled = true,
    });
    defer app_context.deinit();

    var effects_runtime = framework.EffectsRuntime.init(.{});
    var tool_registry = framework.ToolRegistry.init(std.heap.page_allocator);
    defer tool_registry.deinit();
    try tool_registry.register(framework.defineTool(framework.RepoHealthCheckTool));

    var runner = framework.ToolRunner.init(
        std.heap.page_allocator,
        &tool_registry,
        &effects_runtime,
        null,
        app_context.logger,
        app_context.eventBus(),
    );

    const fields = [_]framework.ValidationField{
        .{ .key = "path", .value = .{ .string = "." } },
    };

    var result = try runner.run(.{
        .tool_id = framework.RepoHealthCheckTool.tool_id,
        .request = .{
            .request_id = "repo_health_demo_01",
            .source = .cli,
            .authority = .public,
        },
        .params = fields[0..],
    });
    defer result.deinit(std.heap.page_allocator);

    try std.fs.File.stdout().writeAll(result.output_json);
    try std.fs.File.stdout().writeAll("\n");
}
