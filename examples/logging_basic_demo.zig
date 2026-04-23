const framework = @import("framework");

pub fn main() !void {
    var sink = framework.ConsoleSink.init(.debug, .compact);
    var logger = framework.Logger.init(sink.asLogSink(), .debug);
    defer logger.deinit();

    logger.child("demo").info("basic log", &.{
        framework.LogField.string("mode", "basic"),
        framework.LogField.boolean("ok", true),
    });
}


