const std = @import("std");
const framework = @import("framework");

pub fn main() !void {
    var memory = framework.MemorySink.init(std.heap.page_allocator, 8);
    defer memory.deinit();

    var console = framework.ConsoleSink.init(.trace, .pretty);
    var multi = try framework.MultiSink.init(std.heap.page_allocator, &.{
        memory.asLogSink(),
        console.asLogSink(),
    });
    defer multi.deinit();

    var logger = framework.Logger.init(multi.asLogSink(), .trace);
    defer logger.deinit();

    logger.child("demo").info("multi sink", &.{
        framework.LogField.string("sink_count", "2"),
    });
}


