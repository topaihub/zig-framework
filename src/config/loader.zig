const std = @import("std");
const defaults_model = @import("defaults.zig");
const store_model = @import("store.zig");

pub const ConfigDefaults = defaults_model.ConfigDefaults;
pub const ConfigStore = store_model.ConfigStore;

pub const ConfigValueSource = enum {
    runtime_store,
    bootstrap_default,
    unset,

    pub fn asText(self: ConfigValueSource) []const u8 {
        return switch (self) {
            .runtime_store => "runtime_store",
            .bootstrap_default => "bootstrap_default",
            .unset => "unset",
        };
    }

    pub fn hint(self: ConfigValueSource) []const u8 {
        return switch (self) {
            .runtime_store => "present in runtime config store",
            .bootstrap_default => "seeded by bootstrap defaults",
            .unset => "field is currently unset",
        };
    }
};

pub const LoadedConfigValue = struct {
    current_value_json: ?[]u8,
    default_value_json: ?[]u8,
    source: ConfigValueSource,

    pub fn deinit(self: *LoadedConfigValue, allocator: std.mem.Allocator) void {
        if (self.current_value_json) |owned| allocator.free(owned);
        if (self.default_value_json) |owned| allocator.free(owned);
    }

    pub fn effectiveValueJson(self: *const LoadedConfigValue) ?[]const u8 {
        return self.current_value_json orelse self.default_value_json;
    }

    pub fn present(self: *const LoadedConfigValue) bool {
        return self.current_value_json != null;
    }
};

pub const ConfigLoader = struct {
    allocator: std.mem.Allocator,
    store: ConfigStore,
    defaults: ConfigDefaults,

    pub fn init(allocator: std.mem.Allocator, store: ConfigStore, defaults: ConfigDefaults) ConfigLoader {
        return .{ .allocator = allocator, .store = store, .defaults = defaults };
    }

    pub fn loadValue(self: ConfigLoader, path: []const u8) anyerror!LoadedConfigValue {
        const current_value_json = try self.store.readValueJson(self.allocator, path);
        const default_value_json = try self.defaults.valueJson(self.allocator, path);
        const source: ConfigValueSource = blk: {
            if (current_value_json) |current| {
                if (default_value_json) |default_value| {
                    if (std.mem.eql(u8, current, default_value)) break :blk .bootstrap_default;
                }
                break :blk .runtime_store;
            }
            if (default_value_json != null) break :blk .bootstrap_default;
            break :blk .unset;
        };

        return .{
            .current_value_json = current_value_json,
            .default_value_json = default_value_json,
            .source = source,
        };
    }
};

test "config loader resolves runtime value before default" {
    var store = store_model.MemoryConfigStore.init(std.testing.allocator);
    defer store.deinit();
    _ = try store.applyValidatedWrites(&.{
        .{ .key = "gateway.host", .value = .{ .string = "0.0.0.0" } },
    });

    const defaults = ConfigDefaults{ .entries = &.{
        .{ .path = "gateway.host", .value_kind = .string, .value_json = "\"127.0.0.1\"" },
    } };

    var loaded = try ConfigLoader.init(std.testing.allocator, store.asConfigStore(), defaults).loadValue("gateway.host");
    defer loaded.deinit(std.testing.allocator);
    try std.testing.expectEqual(ConfigValueSource.runtime_store, loaded.source);
    try std.testing.expectEqualStrings("\"0.0.0.0\"", loaded.effectiveValueJson().?);
}

test "config loader preserves bootstrap default source when runtime value matches default" {
    var store = store_model.MemoryConfigStore.init(std.testing.allocator);
    defer store.deinit();
    _ = try store.applyValidatedWrites(&.{
        .{ .key = "gateway.port", .value = .{ .integer = 8080 } },
    });

    const defaults = ConfigDefaults{ .entries = &.{
        .{ .path = "gateway.port", .value_kind = .integer, .value_json = "8080" },
    } };

    var loaded = try ConfigLoader.init(std.testing.allocator, store.asConfigStore(), defaults).loadValue("gateway.port");
    defer loaded.deinit(std.testing.allocator);
    try std.testing.expectEqual(ConfigValueSource.bootstrap_default, loaded.source);
}

test "config loader falls back to bootstrap default" {
    var store = store_model.MemoryConfigStore.init(std.testing.allocator);
    defer store.deinit();

    const defaults = ConfigDefaults{ .entries = &.{
        .{ .path = "gateway.port", .value_kind = .integer, .value_json = "8080" },
    } };

    var loaded = try ConfigLoader.init(std.testing.allocator, store.asConfigStore(), defaults).loadValue("gateway.port");
    defer loaded.deinit(std.testing.allocator);
    try std.testing.expectEqual(ConfigValueSource.bootstrap_default, loaded.source);
    try std.testing.expectEqualStrings("8080", loaded.effectiveValueJson().?);
}
