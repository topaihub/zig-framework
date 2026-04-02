const std = @import("std");

pub const ModelRef = struct {
    provider_id: []const u8,
    model_id: []const u8,

    pub fn clone(self: ModelRef, allocator: std.mem.Allocator) !ModelRef {
        return .{
            .provider_id = try allocator.dupe(u8, self.provider_id),
            .model_id = try allocator.dupe(u8, self.model_id),
        };
    }

    pub fn deinit(self: *ModelRef, allocator: std.mem.Allocator) void {
        allocator.free(self.provider_id);
        allocator.free(self.model_id);
    }
};

pub const ProviderAuthKind = enum {
    none,
    api_key,

    pub fn asText(self: ProviderAuthKind) []const u8 {
        return switch (self) {
            .none => "none",
            .api_key => "api_key",
        };
    }
};

pub const ProviderDefinition = struct {
    id: []const u8,
    label: []const u8,
    default_model: ModelRef,
    auth_kind: ProviderAuthKind = .none,
    supports_streaming: bool = false,
    supports_tools: bool = false,

    pub fn clone(self: ProviderDefinition, allocator: std.mem.Allocator) !ProviderDefinition {
        return .{
            .id = try allocator.dupe(u8, self.id),
            .label = try allocator.dupe(u8, self.label),
            .default_model = try self.default_model.clone(allocator),
            .auth_kind = self.auth_kind,
            .supports_streaming = self.supports_streaming,
            .supports_tools = self.supports_tools,
        };
    }

    pub fn deinit(self: *ProviderDefinition, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.label);
        self.default_model.deinit(allocator);
    }
};

pub const ProviderHealthState = enum {
    ready,
    needs_auth,
    degraded,
    unavailable,

    pub fn asText(self: ProviderHealthState) []const u8 {
        return switch (self) {
            .ready => "ready",
            .needs_auth => "needs_auth",
            .degraded => "degraded",
            .unavailable => "unavailable",
        };
    }
};

pub const ProviderHealth = struct {
    provider_id: []const u8,
    state: ProviderHealthState,
    message: ?[]const u8 = null,

    pub fn clone(self: ProviderHealth, allocator: std.mem.Allocator) !ProviderHealth {
        return .{
            .provider_id = try allocator.dupe(u8, self.provider_id),
            .state = self.state,
            .message = if (self.message) |value| try allocator.dupe(u8, value) else null,
        };
    }

    pub fn deinit(self: *ProviderHealth, allocator: std.mem.Allocator) void {
        allocator.free(self.provider_id);
        if (self.message) |value| allocator.free(value);
    }
};

pub const ProviderModelInfo = struct {
    provider_id: []const u8,
    model_id: []const u8,
    label: []const u8,
    supports_streaming: bool = false,
    supports_tools: bool = false,

    pub fn clone(self: ProviderModelInfo, allocator: std.mem.Allocator) !ProviderModelInfo {
        return .{
            .provider_id = try allocator.dupe(u8, self.provider_id),
            .model_id = try allocator.dupe(u8, self.model_id),
            .label = try allocator.dupe(u8, self.label),
            .supports_streaming = self.supports_streaming,
            .supports_tools = self.supports_tools,
        };
    }

    pub fn deinit(self: *ProviderModelInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.provider_id);
        allocator.free(self.model_id);
        allocator.free(self.label);
    }
};

pub const ProviderCatalogEntry = struct {
    definition: ProviderDefinition,
    health: ProviderHealth,
    models: []const ProviderModelInfo,

    pub fn clone(self: ProviderCatalogEntry, allocator: std.mem.Allocator) !ProviderCatalogEntry {
        const models = try allocator.alloc(ProviderModelInfo, self.models.len);
        errdefer allocator.free(models);
        for (self.models, 0..) |item, index| {
            models[index] = try item.clone(allocator);
        }

        return .{
            .definition = try self.definition.clone(allocator),
            .health = try self.health.clone(allocator),
            .models = models,
        };
    }

    pub fn deinit(self: *ProviderCatalogEntry, allocator: std.mem.Allocator) void {
        self.definition.deinit(allocator);
        self.health.deinit(allocator);
        for (self.models) |item| {
            var mutable = item;
            mutable.deinit(allocator);
        }
        allocator.free(self.models);
    }
};

test "agentkit provider substrate types are stable" {
    var definition = ProviderDefinition{
        .id = "demo",
        .label = "Demo Provider",
        .default_model = .{
            .provider_id = "demo",
            .model_id = "demo-model",
        },
        .auth_kind = .api_key,
        .supports_streaming = true,
    };
    defer definition.deinit(std.testing.allocator);
    definition = try definition.clone(std.testing.allocator);

    const health = ProviderHealth{
        .provider_id = "demo",
        .state = .ready,
    };
    const model = ProviderModelInfo{
        .provider_id = "demo",
        .model_id = "demo-model",
        .label = "Demo Model",
        .supports_streaming = true,
    };

    try std.testing.expectEqualStrings("demo", definition.id);
    try std.testing.expectEqualStrings("ready", health.state.asText());
    try std.testing.expectEqualStrings("demo-model", model.model_id);
}
