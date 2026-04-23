const std = @import("std");
const framework = @import("framework");

pub fn main() !void {
    var app_context = try framework.AppContext.init(std.heap.page_allocator, .{
        .console_log_enabled = true,
    });
    defer app_context.deinit();

    var effects_runtime = framework.EffectsRuntime.init(.{});
    var registry = framework.ToolRegistry.init(std.heap.page_allocator);
    defer registry.deinit();
    try registry.register(framework.defineTool(framework.RepoHealthCheckTool));

    var runner = framework.ToolRunner.init(
        std.heap.page_allocator,
        &registry,
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
            .request_id = "tooling_obs_demo",
            .source = .cli,
            .authority = .public,
        },
        .params = fields[0..],
    });
    defer result.deinit(std.heap.page_allocator);
}


