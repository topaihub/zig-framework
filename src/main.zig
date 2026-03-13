const std = @import("std");
const framework = @import("framework");

pub fn main() !void {
    _ = framework;
    try std.fs.File.stdout().writeAll("framework bootstrap ready\n");
}
