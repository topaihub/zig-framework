const framework = @import("framework");

pub fn main() !void {
    var sink = framework.ConsoleSink.init(.info, .compact);
    var logger = framework.Logger.initWithOptions(sink.asLogSink(), .{
        .min_level = .info,
        .redact_mode = .strict,
    });
    defer logger.deinit();

    logger.child("demo").info("redaction demo", &.{
        framework.LogField.sensitiveString("project_root", "E:/secret/workspace"),
        framework.LogField.string("api_key", "top-secret"),
        framework.LogField.string("model", "gpt-5"),
    });
}
