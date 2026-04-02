const std = @import("std");
const framework = @import("../src/root.zig");

pub fn main() !void {
    var app_context = try framework.AppContext.init(std.heap.page_allocator, .{
        .console_log_enabled = false,
    });
    defer app_context.deinit();

    const Seed = struct {
        fn call(_: *const framework.CommandContext) anyerror![]const u8 {
            return std.heap.page_allocator.dupe(u8, "{\"route\":\"parallel\"}");
        }
    };
    const First = struct {
        fn call(_: *const framework.CommandContext) anyerror![]const u8 {
            return std.heap.page_allocator.dupe(u8, "{\"id\":1}");
        }
    };
    const Second = struct {
        fn call(_: *const framework.CommandContext) anyerror![]const u8 {
            return std.heap.page_allocator.dupe(u8, "{\"id\":2}");
        }
    };

    try app_context.command_registry.register(.{
        .id = "demo.seed",
        .method = "demo.seed",
        .handler = Seed.call,
    });
    try app_context.command_registry.register(.{
        .id = "demo.parallel.1",
        .method = "demo.parallel.1",
        .handler = First.call,
    });
    try app_context.command_registry.register(.{
        .id = "demo.parallel.2",
        .method = "demo.parallel.2",
        .handler = Second.call,
    });

    var effects_runtime = framework.EffectsRuntime.init(.{});
    var runner = framework.WorkflowRunner.init(
        std.heap.page_allocator,
        app_context.makeDispatcher(),
        &effects_runtime,
        app_context.logger,
        app_context.eventBus(),
        app_context.task_runner,
        null,
    );

    var result = try runner.run(.{
        .id = "workflow.control.demo",
        .description = "branch and parallel demo",
        .steps = &[_]framework.WorkflowStep{
            .{ .command = .{ .method = "demo.seed" } },
            .{ .branch = .{
                .predicate = .last_output_contains,
                .operand = "\"parallel\"",
                .on_true = .{ .parallel = .{
                    .targets = &[_]framework.ParallelTarget{
                        .{ .command = .{ .method = "demo.parallel.1" } },
                        .{ .command = .{ .method = "demo.parallel.2" } },
                    },
                } },
                .on_false = .{ .emit_event = .{ .topic = "workflow.control.false", .payload_json = "{\"branch\":\"false\"}" } },
            } },
        },
    });
    defer result.deinit(std.heap.page_allocator);

    try std.fs.File.stdout().writeAll("workflow control flow demo\n");
    try std.fs.File.stdout().writeAll("status: ");
    try std.fs.File.stdout().writeAll(result.status.asText());
    try std.fs.File.stdout().writeAll("\noutput: ");
    try std.fs.File.stdout().writeAll(result.last_output_json orelse "null");
    try std.fs.File.stdout().writeAll("\n");
}
