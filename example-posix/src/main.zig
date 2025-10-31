const std = @import("std");

const EmbShellT = @import("embshell").EmbShellFixedParams(u32);
const EmbShell = @import("embshell").EmbShellFixed(EmbShellT{
    .prompt = "myshell> ",
    .maxargs = 16,
    .maxlinelen = 128,
    .cmdtable = &.{
        .{ .name = "echo", .handler = echoHandler },
        .{ .name = "led", .handler = ledHandler },
    },
    .userdataT = u32,
});

var stdin_reader:*std.Io.Reader = undefined;
const stdin_reader_handle = std.fs.File.stdin().handle;

var stdout_writer:*std.Io.Writer = undefined;

// handler for the "echo" command
fn echoHandler(userdata: u32, args: [][]const u8) anyerror!void {
    try stdout_writer.print("userdata={any} You said: {any}\r\n", .{ userdata, args });
    try stdout_writer.flush();
}

// handler for the "led" command
fn ledHandler(userdata: u32, args: [][]const u8) anyerror!void {
    if (args.len < 2) {
        // check that there are the right number of arguments
        try stdout_writer.print("userdata={any} {s} <0|1>\r\n", .{ userdata, args[0] });
        try stdout_writer.flush();
        return error.BadArgs;
    }

    const val = std.fmt.parseInt(u32, args[1], 10) catch 0; // if it parses and > 0, default to 0
    try stdout_writer.print("If we had an LED it would be set to {}\r\n", .{val > 0});
    try stdout_writer.flush();
}

var original_termios: ?std.posix.termios = null;

// setup terminal in raw mode, for instant feedback on typed characters
pub fn raw_mode_start() !void {
    const handle = stdin_reader_handle;
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

// return to original terminal mode
pub fn raw_mode_stop() void {
    if (original_termios) |termios| {
        std.posix.tcsetattr(stdin_reader_handle, .FLUSH, termios) catch {};
    }
    _ = stdout_writer.print("\r\n", .{}) catch 0;
    _ = stdout_writer.flush() catch 0;
}

// callback for EmbShell to write bytes
fn write(buf: []const u8) void {
    _ = stdout_writer.write(buf) catch 0;
    _ = stdout_writer.flush() catch 0;
}

pub fn main() !void {
    var done: bool = false;
    var stdoutwrbuf: [512]u8 = undefined;
    var w = std.fs.File.stdout().writer(&stdoutwrbuf);
    stdout_writer = &w.interface;

    var stdinrdbuf:[512]u8 = undefined;
    var r = std.fs.File.stdin().reader(&stdinrdbuf);
    stdin_reader = &r.interface;

    // setup raw mode on terminal so we can handle individual keypresses
    try raw_mode_start();
    defer raw_mode_stop();

    // setup embshell with write callback
    var shell = try EmbShell.init(write, 42);

    // read from keyboard
    outer: while (!done) {
        var fds = [_]std.posix.pollfd{.{
            .fd = stdin_reader_handle,
            .events = std.posix.POLL.IN,
            .revents = undefined,
        }};
        const ready = std.posix.poll(&fds, 1000) catch 0;
        if (ready > 0) {
            if (fds[0].revents == std.posix.POLL.IN) {
                var buf:[128]u8 = undefined;
                const count = try std.posix.read(stdin_reader_handle, &buf);

                if (count > 0) {
                    // send bytes to EmbShell for processing
                    shell.feed(buf[0..count]) catch |err| switch (err) {
                        else => {
                            done = true;
                            continue :outer;
                        },
                    };
                } else {
                    done = true;
                    continue :outer;
                }
            }
        }
    }
}
