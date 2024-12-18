const std = @import("std");
const ascii = std.ascii.control_code;

const MAXARGS = 16;
const CMDBUF_SIZE_BYTES = 128;

pub const EmbShell = struct {
    const Self = @This();

    got_line:bool,
    cmdbuf:[CMDBUF_SIZE_BYTES+1]u8,
    cmdbuf_len:usize,
    writeFn:*const fn(data:[]const u8) void,
    runFn:*const fn(args:[][]const u8) anyerror!void,
    prompt_str:[]const u8,

    pub fn prompt(self: *const Self) !void {
        self.writeFn(self.prompt_str);
    }

    pub fn init(wfn: *const fn(data:[]const u8) void, rfn: *const fn(args:[][]const u8) anyerror!void, prompt_str:[]const u8) !Self {
        const self = Self{ 
            .runFn = rfn,
            .writeFn = wfn,
            .got_line = false,
            .cmdbuf_len = 0,
            .cmdbuf = .{0} ** (CMDBUF_SIZE_BYTES+1),
            .prompt_str = prompt_str,
        };
        try self.prompt();
        return self;
    }

    // execute a command line
    fn execline(self: *Self, line:[]const u8) !void {
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
        try self.runFn(argv[0..argc]);
    }

    pub fn loop(self: *Self, data:[]const u8) !void {
        for (data) |key| {
            if (self.got_line) {
                // buffer is already full
                return;
            }
            switch(key) {
                ascii.etx => {  // ctrl-c
                    return error.embshellCtrlC;
                },
                ascii.cr, ascii.lf => {
                    self.got_line = true;
                    self.writeFn("\r\n");
                },
                ascii.del, ascii.bs => {
                    if (self.cmdbuf_len > 0) {
                        self.cmdbuf_len -= 1;
                        self.cmdbuf[self.cmdbuf_len] = 0;

                        const bs: [3]u8 = .{ascii.bs, ' ', ascii.bs};
                        self.writeFn(&bs);
                    }
                },
                else => {
                    // echo
                    if (self.cmdbuf_len < CMDBUF_SIZE_BYTES) {
                        self.writeFn(@as(*const[1]u8, @ptrCast(&key)));  // u8 to single-item slice

                        self.cmdbuf[self.cmdbuf_len] = key;
                        self.cmdbuf_len += 1;
                        self.cmdbuf[self.cmdbuf_len] = 0;
                    } else {
                        const bel:u8 = ascii.bel;
                        self.writeFn(@as(*const[1]u8, @ptrCast(&bel)));    // u8 to single-item slice
                    }
                }
            }
        }
        if (self.got_line) {
            if (self.cmdbuf_len > 0) {
                try self.execline(self.cmdbuf[0..self.cmdbuf_len]);
            }
            self.cmdbuf_len = 0;
            self.cmdbuf[self.cmdbuf_len] = 0;
            try self.prompt();
            self.got_line = false;
        }
    }

};




