const std = @import("std");
const embshell = @import("embshell");

var original_termios: ?std.posix.termios = null;

pub fn raw_mode_start() !void {
    const stdin_reader = std.io.getStdIn();
    const handle = stdin_reader.handle;
    var termios = try std.posix.tcgetattr(handle);
    original_termios = termios;

    termios.iflag.BRKINT = false;
    termios.iflag.ICRNL = false;
    termios.iflag.INPCK = false;
    termios.iflag.ISTRIP = false;
    termios.iflag.IXON = false;
    termios.oflag.OPOST = false;
    termios.lflag.ECHO = false;
    termios.lflag.ICANON = false;
    termios.lflag.IEXTEN = false;
    termios.lflag.ISIG = false;
    termios.cflag.CSIZE = .CS8;
    termios.cc[@intFromEnum(std.posix.V.TIME)] = 0;
    termios.cc[@intFromEnum(std.posix.V.MIN)] = 1;

    try std.posix.tcsetattr(handle, .FLUSH, termios);
}

pub fn raw_mode_stop() void {
    const stdout_writer = std.io.getStdOut().writer();
    const stdin_reader = std.io.getStdIn();
    if (original_termios) |termios| {
        std.posix.tcsetattr(stdin_reader.handle, .FLUSH, termios) catch {};
    }
    _ = stdout_writer.print("\r\n", .{}) catch 0;
}

fn runcmd(args:[][]const u8) anyerror!void {
    const stdout_writer = std.io.getStdOut().writer();
    for (args, 0..) |arg, i| {
        try stdout_writer.print("args[{d}]='{s}' ", .{i, arg});
    }
    try stdout_writer.print("\r\n", .{});
}

fn write(buf:[]const u8) void {
    const stdout_writer = std.io.getStdOut().writer();
    _ = stdout_writer.write(buf) catch 0;
}


pub fn main() !void {
    var done:bool = false;
    const stdin_reader = std.io.getStdIn();
    // setup raw mode on terminal so we can handle individual keypresses
    try raw_mode_start();
    defer raw_mode_stop();

    // setup embshell with write and run callbacks
    try embshell.init(write, runcmd);

    outer: while (!done) {
        var fds = [_]std.posix.pollfd{
            .{
                .fd = stdin_reader.handle,
                .events = std.posix.POLL.IN,
                .revents = undefined,
            }
        };
        const ready = std.posix.poll(&fds, 1000) catch 0;
        if (ready > 0) {
            if (fds[0].revents == std.posix.POLL.IN) {
                var buf: [4096]u8 = undefined;
                const count = stdin_reader.read(&buf) catch 0;
                if (count > 0) {
                    embshell.loop(buf[0..count]) catch |err| switch(err) {
                        else => {
                            done = true;
                            continue :outer;
                        }
                    };
                } else {
                    done = true;
                    continue :outer;
                }
            }
        }
    }
}
