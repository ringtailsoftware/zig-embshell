const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.standardTargetOptions(.{});
    _ = b.standardOptimizeOption(.{});

    _ = b.addModule("embshell", .{
        .root_source_file = b.path("src/embshell.zig"),
    });
}
