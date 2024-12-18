const std = @import("std");
const term = @import("term.zig");
const cmds = @import("cmds.zig");
const cmdTable = cmds.cmdTable;
const ascii = std.ascii.control_code;

const MAXARGS = 16;
const CMDBUF_SIZE_BYTES = 128;

var got_line:bool = false;
var cmdbuf:[CMDBUF_SIZE_BYTES+1]u8 = .{0} ** (CMDBUF_SIZE_BYTES+1);
var cmdbuf_len:usize = 0;

// type definitions
pub const ArgList = [][]const u8;
pub const CmdHandler = *const fn(args:ArgList) CmdErr!void; // function pointer

// comptime helper to contruct handler table
pub fn makeCmd(comptime name:[] const u8, comptime handler: CmdHandler) Cmd {
    return Cmd{
        .name = name,
        .handler = handler,
    };
}

pub const CmdErr = error{
    BadArgs,
    Fail
};

pub const Cmd = struct{
    name: [] const u8,
    handler: CmdHandler,
};

pub fn banner() !void {
    try term.write("zig-embshell: type help or press tab!\n");
}

pub fn prompt() !void {
    try term.write("> ");
}

pub fn init() !void {
    got_line = false;
    cmdbuf_len = 0;
    cmdbuf[cmdbuf_len] = 0;

    try banner();
    try prompt();
}

// given an ArgList, take action
fn runcmd(args:ArgList) !void {
    if (args.len > 0) {
        for (cmdTable) |cmd| {
            if (std.mem.eql(u8, cmd.name, args[0])) {
                if (cmd.handler(args)) {    // execute command handler
                    try term.write("OK\n");
                    return;
                } else |err| switch(err) {  // report error from command handler
                    CmdErr.BadArgs => try term.write("\nBad arguments\n"),
                    CmdErr.Fail => try term.write("\nFailed\n"),
                }
            }
        }
        // special case for help, generate it automatically from cmdTable
        if (std.mem.eql(u8, args[0], "help")) {
            for (cmdTable) |cmd| {
                try term.write(cmd.name);
                try term.write("\n");
            }
        }
    }
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
    try runcmd(argv[0..argc]);
}

pub fn loop() !void {
    // try to get a key from terminal
    const key:?u8 = term.getch();
    if (key != null) {
        if (got_line) {
            // buffer is already full
            return;
        }
        switch(key.?) {
            ascii.etx => {  // ctrl-c
                std.process.exit(0); // FIXME, should return error from loop?
            },
            ascii.cr, ascii.lf => {
                got_line = true;
                try term.write("\n");
            },
            ascii.del, ascii.bs => {
                if (cmdbuf_len > 0) {
                    cmdbuf_len = cmdbuf_len-1;
                    cmdbuf[cmdbuf_len] = 0;

                    const bs: [3]u8 = .{ascii.bs, ' ', ascii.bs};
                    try term.write(&bs);
                }
            },
            ascii.ht => { // Tab
                var matches:[cmdTable.len] usize = .{undefined} ** (cmdTable.len);  // indices of matching commands
                var numMatches:usize = 0;
                // look for matches
                for (cmdTable, 0..) |cmd, index| {
                    if (std.mem.startsWith(u8, cmd.name, cmdbuf[0..cmdbuf_len])) {
                        matches[numMatches] = index;
                        numMatches += 1;
                    }
                }
                if (numMatches > 0) {
                    switch(numMatches) {
                        1 => {  // exactly one match
                            const cmd = cmdTable[matches[0]];
                            try term.write(cmd.name[cmdbuf_len..]);
                            std.mem.copyForwards(u8, &cmdbuf, cmd.name);
                            cmdbuf_len = cmd.name.len;
                            cmdbuf[cmdbuf_len] = 0;
                        },
                        else => { // multiple matches
                            try term.write("\n");
                            for (matches) |match| {
                                const cmd = cmdTable[match];
                                try term.write(cmd.name);
                                try term.write("\n");
                            }
                            try prompt();
                            try term.write(cmdbuf[0..cmdbuf_len]);
                        }
                    }
                }
            },
            else => {
                // echo
                if (cmdbuf_len < CMDBUF_SIZE_BYTES) {
                    try term.write(@as(*const[1]u8, @ptrCast(&key.?)));  // u8 to single-item slice

                    cmdbuf[cmdbuf_len] = key.?;
                    cmdbuf_len = cmdbuf_len + 1;
                    cmdbuf[cmdbuf_len] = 0;
                } else {
                    const bel:u8 = ascii.bel;
                    try term.write(@as(*const[1]u8, @ptrCast(&bel)));    // u8 to single-item slice
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

