const std = @import("std");
const ascii = std.ascii.control_code;

pub fn EmbShellFixedParams(dataT: type) type {
    return struct {
        const EmbShellCmd = struct { name: []const u8, handler: *const fn (userdata: dataT, args: [][]const u8) anyerror!void };

        prompt: []const u8,
        maxlinelen: usize,
        maxargs: usize,
        cmdtable: []const EmbShellCmd,
        userdataT: type,
    };
}

// returns an EmbShell setup according to EmbShellFixedParams
pub fn EmbShellFixed(comptime params: anytype) type {
    return struct {
        const Self = @This();

        got_line: bool,
        cmdbuf: [params.maxlinelen + 1]u8 = undefined,
        cmdbuf_len: usize,
        writeFn: *const fn (data: []const u8) void,
        userdata: params.userdataT,

        pub const Cmd = struct {
            name: []const u8,
            handler: *const fn (args: [][]const u8) anyerror!void,
        };

        pub fn prompt(self: *const Self) !void {
            self.writeFn(params.prompt);
        }

        pub fn init(wfn: *const fn (data: []const u8) void, userdata: params.userdataT) !Self {
            const self = Self{
                .writeFn = wfn,
                .got_line = false,
                .cmdbuf_len = 0,
                .cmdbuf = .{0} ** (params.maxlinelen + 1),
                .userdata = userdata,
            };
            try self.prompt();
            return self;
        }

        fn runcmd(self: *Self, args: [][]const u8) !void {
            if (args.len > 0) {
                for (params.cmdtable) |cmd| {
                    if (std.mem.eql(u8, cmd.name, args[0])) {
                        // exec cmd handler
                        cmd.handler(self.userdata, args) catch {
                            self.writeFn("Failed\r\n");
                            return;
                        };
                        self.writeFn("OK\r\n");
                        return;
                    }
                }
                // special case for help, generate it automatically from cmdtable
                if (std.mem.eql(u8, args[0], "help")) {
                    for (params.cmdtable) |cmd| {
                        self.writeFn(cmd.name);
                        self.writeFn("\r\n");
                    }
                }
            }
        }

        // execute a command line
        fn execline(self: *Self, line: []const u8) !void {
            // tokenize, returns iterator to slices
            var tokens = std.mem.tokenizeAny(u8, line, " ");
            // setup argv array to hold tokens
            var argv: [params.maxargs][]const u8 = .{undefined} ** params.maxargs;
            var argc: u8 = 0;

            while (tokens.next()) |chunk| : (argc += 1) {
                if (argc >= params.maxargs) {
                    break;
                }
                argv[argc] = chunk;
            }
            try self.runcmd(argv[0..argc]);
        }

        pub fn feed(self: *Self, data: []const u8) !void {
            for (data) |key| {
                if (self.got_line) {
                    // buffer is already full
                    return;
                }
                switch (key) {
                    ascii.etx => { // ctrl-c
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

                            const bs: [3]u8 = .{ ascii.bs, ' ', ascii.bs };
                            self.writeFn(&bs);
                        }
                    },
                    ascii.ht => { // Tab
                        var matches: [params.cmdtable.len]usize = .{undefined} ** (params.cmdtable.len); // indices of matching commands
                        var numMatches: usize = 0;
                        // look for matches
                        for (params.cmdtable, 0..) |cmd, index| {
                            if (std.mem.startsWith(u8, cmd.name, self.cmdbuf[0..self.cmdbuf_len])) {
                                matches[numMatches] = index;
                                numMatches += 1;
                            }
                        }
                        if (numMatches > 0) {
                            switch (numMatches) {
                                1 => { // exactly one match
                                    const cmd = params.cmdtable[matches[0]];
                                    self.writeFn(cmd.name[self.cmdbuf_len..]);
                                    std.mem.copyForwards(u8, &self.cmdbuf, cmd.name);
                                    self.cmdbuf_len = cmd.name.len;
                                    self.cmdbuf[self.cmdbuf_len] = 0;
                                },
                                else => { // multiple matches
                                    self.writeFn("\r\n");
                                    for (matches) |match| {
                                        const cmd = params.cmdtable[match];
                                        self.writeFn(cmd.name);
                                        self.writeFn("\r\n");
                                    }
                                    try self.prompt();
                                    self.writeFn(self.cmdbuf[0..self.cmdbuf_len]);
                                },
                            }
                        }
                    },
                    else => {
                        // echo
                        if (self.cmdbuf_len < params.maxlinelen) {
                            self.writeFn(@as(*const [1]u8, @ptrCast(&key))); // u8 to single-item slice

                            self.cmdbuf[self.cmdbuf_len] = key;
                            self.cmdbuf_len += 1;
                            self.cmdbuf[self.cmdbuf_len] = 0;
                        } else {
                            const bel: u8 = ascii.bel;
                            self.writeFn(@as(*const [1]u8, @ptrCast(&bel))); // u8 to single-item slice
                        }
                    },
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
}
