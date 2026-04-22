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
    try tool_registry.register(framework.ScriptMarkdownFetchTool.definition());

    var host = framework.tooling.script_host.ScriptHost.init(
        std.heap.page_allocator,
        effects_runtime.process_runner,
        app_context.logger,
        app_context.eventBus(),
    );
    var runner = framework.ToolRunner.init(
        std.heap.page_allocator,
        &tool_registry,
        &effects_runtime,
        &host,
        app_context.logger,
        app_context.eventBus(),
    );

    const fields = [_]framework.ValidationField{
        .{ .key = "url", .value = .{ .string = "https://example.com/post" } },
    };

    var result = try runner.run(.{
        .tool_id = framework.ScriptMarkdownFetchTool.tool_id,
        .request = .{
            .request_id = "script_markdown_demo_01",
            .source = .cli,
            .authority = .public,
        },
        .params = fields[0..],
    });
    defer result.deinit(std.heap.page_allocator);

    try std.fs.File.stdout().writeAll(result.output_json);
    try std.fs.File.stdout().writeAll("\n");
}


