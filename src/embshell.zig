const std = @import("std");
const ascii = std.ascii.control_code;

const MAXARGS = 16;
const CMDBUF_SIZE_BYTES = 128;

var got_line:bool = false;
var cmdbuf:[CMDBUF_SIZE_BYTES+1]u8 = .{0} ** (CMDBUF_SIZE_BYTES+1);
var cmdbuf_len:usize = 0;
var writeFn:*const fn(data:[]const u8) void = undefined;
var runFn:*const fn(args:[][]const u8) anyerror!void = undefined;


pub fn prompt() !void {
    writeFn("> ");
}

pub fn init(wfn: *const fn(data:[]const u8) void, rfn: *const fn(args:[][]const u8) anyerror!void) !void {
    runFn = rfn;
    writeFn = wfn;
    got_line = false;
    cmdbuf_len = 0;
    cmdbuf[cmdbuf_len] = 0;

    try prompt();
}

// execute a command line
fn execline(line:[]const u8) !void {
    // tokenize, returns iterator to slices
    var tokens = std.mem.tokenize(u8, line, " ");
    // setup argv array to hold tokens
    var argv:[MAXARGS] []const u8 = .{undefined} ** MAXARGS;
    var argc:u8 = 0;

    while (tokens.next()) |chunk| : (argc += 1) {
        if (argc >= MAXARGS) {
            break;
        }
        argv[argc] = chunk;
    }
    try runFn(argv[0..argc]);
}

pub fn loop(data:[]const u8) !void {
    for (data) |key| {
        if (got_line) {
            // buffer is already full
            return;
        }
        switch(key) {
            ascii.etx => {  // ctrl-c
                return error.embshellCtrlC;
            },
            ascii.cr, ascii.lf => {
                got_line = true;
                writeFn("\r\n");
            },
            ascii.del, ascii.bs => {
                if (cmdbuf_len > 0) {
                    cmdbuf_len = cmdbuf_len-1;
                    cmdbuf[cmdbuf_len] = 0;

                    const bs: [3]u8 = .{ascii.bs, ' ', ascii.bs};
                    writeFn(&bs);
                }
            },
            else => {
                // echo
                if (cmdbuf_len < CMDBUF_SIZE_BYTES) {
                    writeFn(@as(*const[1]u8, @ptrCast(&key)));  // u8 to single-item slice

                    cmdbuf[cmdbuf_len] = key;
                    cmdbuf_len = cmdbuf_len + 1;
                    cmdbuf[cmdbuf_len] = 0;
                } else {
                    const bel:u8 = ascii.bel;
                    writeFn(@as(*const[1]u8, @ptrCast(&bel)));    // u8 to single-item slice
                }
            }
        }
    }
    if (got_line) {
        if (cmdbuf_len > 0) {
            try execline(cmdbuf[0..cmdbuf_len]);
        }
        cmdbuf_len = 0;
        cmdbuf[cmdbuf_len] = 0;
        try prompt();
        got_line = false;
    }
}

