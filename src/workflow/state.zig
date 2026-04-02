const std = @import("std");

pub const WorkflowStatus = enum {
    idle,
    running,
    waiting,
    succeeded,
    failed,

    pub fn asText(self: WorkflowStatus) []const u8 {
        return switch (self) {
            .idle => "idle",
            .running => "running",
            .waiting => "waiting",
            .succeeded => "succeeded",
            .failed => "failed",
        };
    }
};

pub const WorkflowStepStatus = enum {
    pending,
    running,
    succeeded,
    failed,
    skipped,

    pub fn asText(self: WorkflowStepStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .running => "running",
            .succeeded => "succeeded",
            .failed => "failed",
            .skipped => "skipped",
        };
    }
};

pub const WorkflowCheckpoint = struct {
    run_id: []u8,
    workflow_id: []u8,
    workflow_status: WorkflowStatus,
    current_step_index: usize,
    step_statuses: []WorkflowStepStatus,
    last_output_json: ?[]u8 = null,
    last_error_code: ?[]u8 = null,
    waiting_reason: ?[]u8 = null,

    pub fn clone(self: WorkflowCheckpoint, allocator: std.mem.Allocator) !WorkflowCheckpoint {
        const step_statuses = try allocator.alloc(WorkflowStepStatus, self.step_statuses.len);
        errdefer allocator.free(step_statuses);
        @memcpy(step_statuses, self.step_statuses);

        return .{
            .run_id = try allocator.dupe(u8, self.run_id),
            .workflow_id = try allocator.dupe(u8, self.workflow_id),
            .workflow_status = self.workflow_status,
            .current_step_index = self.current_step_index,
            .step_statuses = step_statuses,
            .last_output_json = if (self.last_output_json) |value| try allocator.dupe(u8, value) else null,
            .last_error_code = if (self.last_error_code) |value| try allocator.dupe(u8, value) else null,
            .waiting_reason = if (self.waiting_reason) |value| try allocator.dupe(u8, value) else null,
        };
    }

    pub fn deinit(self: *WorkflowCheckpoint, allocator: std.mem.Allocator) void {
        allocator.free(self.run_id);
        allocator.free(self.workflow_id);
        allocator.free(self.step_statuses);
        if (self.last_output_json) |value| allocator.free(value);
        if (self.last_error_code) |value| allocator.free(value);
        if (self.waiting_reason) |value| allocator.free(value);
    }
};

pub const WorkflowRunResult = struct {
    status: WorkflowStatus,
    completed_steps: usize,
    run_id: ?[]u8 = null,
    last_output_json: ?[]u8 = null,
    last_error_code: ?[]u8 = null,

    pub fn deinit(self: *WorkflowRunResult, allocator: std.mem.Allocator) void {
        if (self.run_id) |value| allocator.free(value);
        if (self.last_output_json) |value| allocator.free(value);
        if (self.last_error_code) |value| allocator.free(value);
    }
};

test "workflow statuses expose stable text values" {
    try std.testing.expectEqualStrings("idle", WorkflowStatus.idle.asText());
    try std.testing.expectEqualStrings("waiting", WorkflowStatus.waiting.asText());
    try std.testing.expectEqualStrings("pending", WorkflowStepStatus.pending.asText());
    try std.testing.expectEqualStrings("skipped", WorkflowStepStatus.skipped.asText());
}

test "workflow checkpoint can clone and deinit safely" {
    const step_statuses = [_]WorkflowStepStatus{ .succeeded, .pending };
    var checkpoint = WorkflowCheckpoint{
        .run_id = try std.testing.allocator.dupe(u8, "run_01"),
        .workflow_id = try std.testing.allocator.dupe(u8, "workflow.demo"),
        .workflow_status = .running,
        .current_step_index = 1,
        .step_statuses = try std.testing.allocator.dupe(WorkflowStepStatus, step_statuses[0..]),
        .last_output_json = try std.testing.allocator.dupe(u8, "{\"ok\":true}"),
        .last_error_code = null,
        .waiting_reason = try std.testing.allocator.dupe(u8, "none"),
    };
    defer checkpoint.deinit(std.testing.allocator);

    var cloned = try checkpoint.clone(std.testing.allocator);
    defer cloned.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("run_01", cloned.run_id);
    try std.testing.expectEqualStrings("workflow.demo", cloned.workflow_id);
    try std.testing.expectEqual(WorkflowStatus.running, cloned.workflow_status);
    try std.testing.expectEqual(@as(usize, 2), cloned.step_statuses.len);
    try std.testing.expectEqual(WorkflowStepStatus.pending, cloned.step_statuses[1]);
    try std.testing.expectEqualStrings("{\"ok\":true}", cloned.last_output_json.?);
    try std.testing.expectEqualStrings("none", cloned.waiting_reason.?);
}
