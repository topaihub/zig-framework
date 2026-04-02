const std = @import("std");
const types = @import("provider_types.zig");

pub const ProviderCatalogEntry = types.ProviderCatalogEntry;
pub const ModelRef = types.ModelRef;
pub const ProviderHealthState = types.ProviderHealthState;

pub fn isProviderReady(catalog: []const ProviderCatalogEntry, provider_id: []const u8) bool {
    for (catalog) |entry| {
        if (std.mem.eql(u8, entry.definition.id, provider_id)) {
            return entry.health.state == .ready;
        }
    }
    return false;
}

pub fn isModelReady(catalog: []const ProviderCatalogEntry, ref: ModelRef) bool {
    for (catalog) |entry| {
        if (!std.mem.eql(u8, entry.definition.id, ref.provider_id)) continue;
        if (entry.health.state != .ready) return false;
        if (entry.models.len == 0) {
            return std.mem.eql(u8, entry.definition.default_model.model_id, ref.model_id);
        }
        for (entry.models) |model| {
            if (std.mem.eql(u8, model.provider_id, ref.provider_id) and std.mem.eql(u8, model.model_id, ref.model_id)) {
                return true;
            }
        }
        return false;
    }
    return false;
}

pub fn defaultReadyModel(catalog: []const ProviderCatalogEntry) ?ModelRef {
    for (catalog) |entry| {
        if (entry.health.state == .ready) return entry.definition.default_model;
    }
    if (catalog.len == 0) return null;
    return catalog[0].definition.default_model;
}

test "agentkit provider selection prefers ready models" {
    const models = [_]types.ProviderModelInfo{
        .{ .provider_id = "openai", .model_id = "gpt-5", .label = "GPT-5" },
    };
    const catalog = [_]ProviderCatalogEntry{
        .{
            .definition = .{
                .id = "anthropic",
                .label = "Anthropic",
                .default_model = .{ .provider_id = "anthropic", .model_id = "claude-sonnet-4-5" },
                .auth_kind = .api_key,
            },
            .health = .{ .provider_id = "anthropic", .state = .needs_auth },
            .models = &.{},
        },
        .{
            .definition = .{
                .id = "openai",
                .label = "OpenAI",
                .default_model = .{ .provider_id = "openai", .model_id = "gpt-5" },
                .auth_kind = .api_key,
            },
            .health = .{ .provider_id = "openai", .state = .ready },
            .models = models[0..],
        },
    };

    try std.testing.expect(isProviderReady(catalog[0..], "openai"));
    try std.testing.expect(!isProviderReady(catalog[0..], "anthropic"));
    try std.testing.expect(isModelReady(catalog[0..], .{ .provider_id = "openai", .model_id = "gpt-5" }));
    try std.testing.expect(!isModelReady(catalog[0..], .{ .provider_id = "anthropic", .model_id = "claude-sonnet-4-5" }));
    const default_model = defaultReadyModel(catalog[0..]).?;
    try std.testing.expectEqualStrings("openai", default_model.provider_id);
}
