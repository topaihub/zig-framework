const std = @import("std");

pub const MODULE_NAME = "runtime";
pub const app_context = @import("app_context.zig");
pub const event_bus = @import("event_bus.zig");
pub const task_runner = @import("task_runner.zig");

pub const AppBootstrapConfig = app_context.AppBootstrapConfig;
pub const AppContext = app_context.AppContext;
pub const RuntimeEvent = event_bus.RuntimeEvent;
pub const EventBatch = event_bus.EventBatch;
pub const EventBus = event_bus.EventBus;
pub const MemoryEventBus = event_bus.MemoryEventBus;
pub const TaskState = task_runner.TaskState;
pub const TaskJob = task_runner.TaskJob;
pub const TaskRecord = task_runner.TaskRecord;
pub const TaskSummary = task_runner.TaskSummary;
pub const TaskRunner = task_runner.TaskRunner;

pub const ModuleStage = enum {
    scaffold,
};

pub const MODULE_STAGE: ModuleStage = .scaffold;

test "runtime scaffold exports are stable" {
    try std.testing.expectEqualStrings("runtime", MODULE_NAME);
    try std.testing.expect(MODULE_STAGE == .scaffold);
    try std.testing.expectEqualStrings("queued", TaskState.queued.asText());
    _ = MemoryEventBus;
    _ = AppContext;
}
