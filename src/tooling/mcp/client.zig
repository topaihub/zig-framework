//! MCP protocol client — stub for phase 2.
//! TODO: Extract from hermes-zig/src/tools/mcp/client.zig
const std = @import("std");

pub const McpClient = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) McpClient {
        return .{ .allocator = allocator };
    }
};
