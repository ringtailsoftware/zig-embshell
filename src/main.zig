const std = @import("std");
const shell = @import("shell.zig");
const term = @import("term.zig");

pub fn main() !void {
    // setup raw mode on terminal so we can handle individual keypresses
    term.init();
    try shell.init();

    while (true) {
        try shell.loop();
    }
}
