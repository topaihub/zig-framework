const std = @import("std");

pub const MODULE_NAME = "agentkit";
pub const provider_types = @import("provider_types.zig");
pub const provider_registry = @import("provider_registry.zig");
pub const provider_selection = @import("provider_selection.zig");

pub const ModelRef = provider_types.ModelRef;
pub const ProviderAuthKind = provider_types.ProviderAuthKind;
pub const ProviderDefinition = provider_types.ProviderDefinition;
pub const ProviderHealth = provider_types.ProviderHealth;
pub const ProviderHealthState = provider_types.ProviderHealthState;
pub const ProviderModelInfo = provider_types.ProviderModelInfo;
pub const ProviderCatalogEntry = provider_types.ProviderCatalogEntry;
pub const ProviderRegistry = provider_registry.ProviderRegistry;
pub const isProviderReady = provider_selection.isProviderReady;
pub const isModelReady = provider_selection.isModelReady;
pub const defaultReadyModel = provider_selection.defaultReadyModel;

pub const ModuleStage = enum {
    scaffold,
};

pub const MODULE_STAGE: ModuleStage = .scaffold;

test {
    std.testing.refAllDecls(@This());
}

test "agentkit scaffold exports are stable" {
    try std.testing.expectEqualStrings("agentkit", MODULE_NAME);
    try std.testing.expect(MODULE_STAGE == .scaffold);
    try std.testing.expectEqualStrings("ready", ProviderHealthState.ready.asText());
}
