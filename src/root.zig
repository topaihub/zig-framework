//! framework — reusable Zig application framework scaffold.

const std = @import("std");

pub const PACKAGE_NAME = "framework";
pub const PACKAGE_VERSION = "0.1.0";

pub const core = @import("core/root.zig");
pub const config = @import("config/root.zig");
pub const observability = @import("observability/root.zig");
pub const runtime = @import("runtime/root.zig");
pub const app = @import("app/root.zig");
pub const contracts = @import("contracts/root.zig");

pub const AppError = core.error_model.AppError;
pub const Envelope = contracts.envelope.Envelope;
pub const EnvelopeMeta = contracts.envelope.EnvelopeMeta;
pub const TaskAccepted = contracts.envelope.TaskAccepted;
pub const ObservedEvent = observability.ObservedEvent;
pub const Observer = observability.Observer;
pub const MemoryObserver = observability.MemoryObserver;
pub const MultiObserver = observability.MultiObserver;
pub const LogObserver = observability.LogObserver;
pub const JsonlFileObserver = observability.JsonlFileObserver;
pub const MetricsSnapshot = observability.MetricsSnapshot;
pub const MetricsObserver = observability.MetricsObserver;
pub const LogLevel = core.logging.LogLevel;
pub const LogField = core.logging.LogField;
pub const LogFieldValue = core.logging.LogFieldValue;
pub const LogRecord = core.logging.LogRecord;
pub const LogSink = core.logging.LogSink;
pub const MemorySink = core.logging.MemorySink;
pub const ConsoleStyle = core.logging.ConsoleStyle;
pub const ConsoleSink = core.logging.ConsoleSink;
pub const JsonlFileSink = core.logging.JsonlFileSink;
pub const MultiSink = core.logging.MultiSink;
pub const RedactMode = core.logging.RedactMode;
pub const Logger = core.logging.Logger;
pub const LoggerOptions = core.logging.LoggerOptions;
pub const TraceContext = core.logging.TraceContext;
pub const TraceContextProvider = core.logging.TraceContextProvider;
pub const SubsystemLogger = core.logging.SubsystemLogger;
pub const ValidationIssue = core.validation.ValidationIssue;
pub const ValidationSeverity = core.validation.ValidationSeverity;
pub const ValidationReport = core.validation.ValidationReport;
pub const ValidationMode = core.validation.ValidationMode;
pub const ValueKind = core.validation.ValueKind;
pub const ValidationField = core.validation.ValidationField;
pub const ValidationValue = core.validation.ValidationValue;
pub const ValidationRule = core.validation.ValidationRule;
pub const RuleContext = core.validation.RuleContext;
pub const FieldDefinition = core.validation.FieldDefinition;
pub const ValidatorOptions = core.validation.ValidatorOptions;
pub const ConfigRule = core.validation.ConfigRule;
pub const Validator = core.validation.Validator;
pub const Authority = app.Authority;
pub const RequestSource = app.RequestSource;
pub const CommandExecutionMode = app.CommandExecutionMode;
pub const CommandRequest = app.CommandRequest;
pub const RequestContext = app.RequestContext;
pub const CommandSchema = app.CommandSchema;
pub const AsyncCommandHandler = app.AsyncCommandHandler;
pub const CommandDefinition = app.CommandDefinition;
pub const CommandRegistry = app.CommandRegistry;
pub const CommandContext = app.CommandContext;
pub const CommandDispatchResult = app.CommandDispatchResult;
pub const CommandEnvelope = app.CommandEnvelope;
pub const CommandDispatcher = app.CommandDispatcher;
pub const TaskState = runtime.TaskState;
pub const TaskRecord = runtime.TaskRecord;
pub const TaskSummary = runtime.TaskSummary;
pub const AppBootstrapConfig = runtime.AppBootstrapConfig;
pub const AppContext = runtime.AppContext;
pub const RuntimeEvent = runtime.RuntimeEvent;
pub const EventBatch = runtime.EventBatch;
pub const EventBus = runtime.EventBus;
pub const MemoryEventBus = runtime.MemoryEventBus;
pub const TaskRunner = runtime.TaskRunner;
pub const TaskJob = runtime.TaskJob;
pub const ConfigWritePipeline = config.ConfigWritePipeline;
pub const ConfigWriteAttempt = config.ConfigWriteAttempt;
pub const ConfigSideEffect = config.ConfigSideEffect;
pub const ConfigSideEffectRecord = config.ConfigSideEffectRecord;
pub const MemoryConfigSideEffectSink = config.MemoryConfigSideEffectSink;
pub const ConfigPostWriteSummary = config.ConfigPostWriteSummary;
pub const ConfigPostWriteHook = config.ConfigPostWriteHook;
pub const MemoryConfigPostWriteHookSink = config.MemoryConfigPostWriteHookSink;
pub const ConfigChangeKind = config.ConfigChangeKind;
pub const ConfigSideEffectKind = config.ConfigSideEffectKind;
pub const ConfigStore = config.ConfigStore;
pub const ConfigWriteStats = config.ConfigWriteStats;
pub const ConfigDiffSummary = config.ConfigDiffSummary;
pub const ConfigChange = config.ConfigChange;
pub const ConfigChangeLog = config.ConfigChangeLog;
pub const ConfigChangeLogEntry = config.ConfigChangeLogEntry;
pub const MemoryConfigStore = config.MemoryConfigStore;
pub const MemoryConfigChangeLog = config.MemoryConfigChangeLog;
pub const ConfigDefaultEntry = config.ConfigDefaultEntry;
pub const ConfigDefaults = config.ConfigDefaults;
pub const ConfigLoader = config.ConfigLoader;
pub const ConfigValueSource = config.ConfigValueSource;
pub const LoadedConfigValue = config.LoadedConfigValue;
pub const ConfigValueParser = config.ConfigValueParser;

test {
    std.testing.refAllDecls(@This());
}

test "framework metadata is non-empty" {
    try std.testing.expect(PACKAGE_NAME.len > 0);
    try std.testing.expect(PACKAGE_VERSION.len > 0);
}

test "framework module scaffold exports are available" {
    try std.testing.expectEqualStrings("core", core.MODULE_NAME);
    try std.testing.expectEqualStrings("config", config.MODULE_NAME);
    try std.testing.expectEqualStrings("observability", observability.MODULE_NAME);
    try std.testing.expectEqualStrings("runtime", runtime.MODULE_NAME);
    try std.testing.expectEqualStrings("app", app.MODULE_NAME);
    try std.testing.expectEqualStrings("contracts", contracts.MODULE_NAME);
    try std.testing.expectEqualStrings("CORE_INTERNAL_ERROR", core.error_model.code.CORE_INTERNAL_ERROR);
    try std.testing.expectEqualStrings("logging", core.logging.MODULE_NAME);
}
