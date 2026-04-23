//! MCP protocol server — stub for phase 2.
//! TODO: Extract from hermes-zig/src/tools/mcp/server.zig
const std = @import("std");

pub const McpServer = struct {
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) McpServer {
        return .{ .allocator = allocator };
    }
};
