const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const logging_dep = b.dependency("zig-logging", .{ .target = target, .optimize = optimize });
    const logging_mod = logging_dep.module("zig-logging");

    const lib_mod = b.addModule("framework", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("zig-logging", logging_mod);

    const exe = b.addExecutable(.{
        .name = "framework",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("framework", lib_mod);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the framework executable");
    run_step.dependOn(&run_cmd.step);

    const root_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    root_tests.root_module.addImport("framework", lib_mod);
    root_tests.root_module.addImport("zig-logging", logging_mod);
    const run_root_tests = b.addRunArtifact(root_tests);

    const test_step = b.step("test", "Run framework unit tests");
    test_step.dependOn(&run_root_tests.step);

    const release_dep = b.dependency("zig-release", .{});
    const zig_release = @import("zig-release");
    zig_release.addReleaseStep(b, release_dep, .{});
}
