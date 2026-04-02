const std = @import("std");
const state = @import("state.zig");

pub const WorkflowCheckpointStore = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        save: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, checkpoint: state.WorkflowCheckpoint) anyerror!void,
        load: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, run_id: []const u8) anyerror!?state.WorkflowCheckpoint,
        deinit: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator) void,
    };

    pub fn save(self: WorkflowCheckpointStore, allocator: std.mem.Allocator, checkpoint: state.WorkflowCheckpoint) anyerror!void {
        return self.vtable.save(self.ptr, allocator, checkpoint);
    }

    pub fn load(self: WorkflowCheckpointStore, allocator: std.mem.Allocator, run_id: []const u8) anyerror!?state.WorkflowCheckpoint {
        return self.vtable.load(self.ptr, allocator, run_id);
    }

    pub fn deinit(self: WorkflowCheckpointStore, allocator: std.mem.Allocator) void {
        self.vtable.deinit(self.ptr, allocator);
    }
};

pub const MemoryCheckpointStore = struct {
    allocator: std.mem.Allocator,
    items: std.StringHashMapUnmanaged(state.WorkflowCheckpoint) = .empty,

    const Self = @This();

    const vtable = WorkflowCheckpointStore.VTable{
        .save = saveErased,
        .load = loadErased,
        .deinit = deinitErased,
    };

    pub fn init(allocator: std.mem.Allocator) *Self {
        const self = allocator.create(Self) catch @panic("OOM");
        self.* = .{
            .allocator = allocator,
        };
        return self;
    }

    pub fn asCheckpointStore(self: *Self) WorkflowCheckpointStore {
        return .{
            .ptr = @ptrCast(self),
            .vtable = &vtable,
        };
    }

    pub fn deinit(self: *Self) void {
        var iterator = self.items.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.allocator);
        }
        self.items.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    pub fn save(self: *Self, checkpoint: state.WorkflowCheckpoint) !void {
        if (self.items.getPtr(checkpoint.run_id)) |existing| {
            existing.deinit(self.allocator);
            existing.* = try checkpoint.clone(self.allocator);
            return;
        }
        try self.items.put(self.allocator, try self.allocator.dupe(u8, checkpoint.run_id), try checkpoint.clone(self.allocator));
    }

    pub fn load(self: *Self, allocator: std.mem.Allocator, run_id: []const u8) !?state.WorkflowCheckpoint {
        const existing = self.items.get(run_id) orelse return null;
        return try existing.clone(allocator);
    }

    fn saveErased(ptr: *anyopaque, _: std.mem.Allocator, checkpoint: state.WorkflowCheckpoint) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        try self.save(checkpoint);
    }

    fn loadErased(ptr: *anyopaque, allocator: std.mem.Allocator, run_id: []const u8) anyerror!?state.WorkflowCheckpoint {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.load(allocator, run_id);
    }

    fn deinitErased(ptr: *anyopaque, _: std.mem.Allocator) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.deinit();
    }
};

test "memory checkpoint store can save load and overwrite" {
    const store_ref = MemoryCheckpointStore.init(std.testing.allocator);
    defer store_ref.deinit();

    var checkpoint = state.WorkflowCheckpoint{
        .run_id = try std.testing.allocator.dupe(u8, "run_01"),
        .workflow_id = try std.testing.allocator.dupe(u8, "workflow.demo"),
        .workflow_status = .running,
        .current_step_index = 1,
        .step_statuses = try std.testing.allocator.dupe(state.WorkflowStepStatus, &[_]state.WorkflowStepStatus{ .succeeded, .pending }),
    };
    defer checkpoint.deinit(std.testing.allocator);

    try store_ref.save(checkpoint);

    var loaded = (try store_ref.load(std.testing.allocator, "run_01")).?;
    defer loaded.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("workflow.demo", loaded.workflow_id);
    try std.testing.expectEqual(@as(usize, 1), loaded.current_step_index);

    checkpoint.current_step_index = 2;
    checkpoint.workflow_status = .waiting;
    try store_ref.save(checkpoint);

    var updated = (try store_ref.load(std.testing.allocator, "run_01")).?;
    defer updated.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 2), updated.current_step_index);
    try std.testing.expectEqual(state.WorkflowStatus.waiting, updated.workflow_status);
}

test "memory checkpoint store returns null for missing run id" {
    const store_ref = MemoryCheckpointStore.init(std.testing.allocator);
    defer store_ref.deinit();

    try std.testing.expect((try store_ref.load(std.testing.allocator, "missing")) == null);
}
