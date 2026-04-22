const std = @import("std");

pub const MODULE_NAME = "servicekit";

pub const ModuleStage = enum {
    scaffold,
};

pub const MODULE_STAGE: ModuleStage = .scaffold;

test {
    std.testing.refAllDecls(@This());
}

test "servicekit scaffold exports are stable" {
    try std.testing.expectEqualStrings("servicekit", MODULE_NAME);
    try std.testing.expect(MODULE_STAGE == .scaffold);
}


