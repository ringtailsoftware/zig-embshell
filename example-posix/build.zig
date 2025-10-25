const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "example-posix",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    exe.addIncludePath(b.path("src/"));

    const embshell_dep = b.dependency("embshell", .{
        .target = target,
        .optimize = optimize,
    });
    const embshell_mod = embshell_dep.module("embshell");
    exe.root_module.addImport("embshell", embshell_mod);

    b.installArtifact(exe);

    const run = b.step("run", "Run the demo");
    const run_cmd = b.addRunArtifact(exe);
    run.dependOn(&run_cmd.step);
}
