const core = @import("../core/root.zig");

pub const CommandStep = struct {
    method: []const u8,
    params: []const core.validation.ValidationField = &.{},
};

pub const ShellStep = struct {
    argv: []const []const u8,
    cwd: ?[]const u8 = null,
};

pub const EmitEventStep = struct {
    topic: []const u8,
    payload_json: []const u8,
};

pub const RetryTarget = union(enum) {
    command: CommandStep,
    shell: ShellStep,
};

pub const RetryStep = struct {
    attempts: usize,
    delay_ms: u64 = 0,
    target: RetryTarget,
};

pub const BranchPredicate = enum {
    last_output_exists,
    last_output_equals,
    last_output_contains,
};

pub const BranchStep = struct {
    predicate: BranchPredicate,
    operand: ?[]const u8 = null,
    on_true: BranchTarget,
    on_false: BranchTarget,
};

pub const ParallelTarget = union(enum) {
    command: CommandStep,
    shell: ShellStep,
    emit_event: EmitEventStep,
    retry: RetryStep,
};

pub const ParallelStep = struct {
    targets: []const ParallelTarget,
    fail_fast: bool = true,
};

pub const BranchTarget = union(enum) {
    command: CommandStep,
    shell: ShellStep,
    emit_event: EmitEventStep,
    retry: RetryStep,
    parallel: ParallelStep,
};

pub const WaitEventStep = struct {
    topic_filters: []const []const u8,
    timeout_ms: u64 = 0,
};

pub const AskPermissionStep = struct {
    permission: []const u8,
    patterns: []const []const u8 = &.{},
    metadata_json: []const u8 = "{}",
};

pub const AskQuestionStep = struct {
    question_id: []const u8,
    prompt: []const u8,
    schema_json: []const u8 = "{}",
};

pub const WorkflowStep = union(enum) {
    command: CommandStep,
    shell: ShellStep,
    emit_event: EmitEventStep,
    retry: RetryStep,
    branch: BranchStep,
    parallel: ParallelStep,
    wait_event: WaitEventStep,
    ask_permission: AskPermissionStep,
    ask_question: AskQuestionStep,
};
