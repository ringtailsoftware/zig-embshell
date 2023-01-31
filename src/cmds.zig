const std = @import("std");
const shell = @import("shell.zig");

fn echoCmd(args:shell.ArgList) shell.CmdErr!void {
    std.debug.print("You said: {s}\n", .{args});
}

fn ledCmd(args:shell.ArgList) shell.CmdErr!void {
    if (args.len < 2) {
        std.debug.print("{s} <0|1>", .{args[0]});
        return shell.CmdErr.BadArgs;
    }

    // "be liberal in what you accept"
    const val = std.fmt.parseInt(u32, args[1], 10) catch 0;   // if it parses and > 0, default to 0
    std.debug.print("If we had an LED it would be set to {}\n", .{val > 0});
}

// register commands with shell (comptime)
pub const cmdTable = [_]shell.Cmd {
    shell.makeCmd("echo", echoCmd),
    shell.makeCmd("led", ledCmd),
};


