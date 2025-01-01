# EmbShell

A very small interactive command shell for (embedded) Zig programs.

EmbShell makes an ideal system monitor for debugging and interacting with a small embedded system. It interactively takes lines of text, parses commands and makes callbacks into handler functions.

Compared with Readline, Linenoise and Editline - EmbShell is tiny. It lacks most of their features, but it does have:

 - Tab completion for command names
 - Backspace for line editing
 - No reliance on libc and very little use of Zig's `std` (ie. no fancy print formatting)
 - Very little RAM use (just a configurable buffer for the incoming command line)

In EmbShell:

 - All commands and configuration are set at `comptime` to optimise footprint
 - All arguments are separated by whitespace, there is no support for quoted strings, multiline commands or escaped data
 - All handler arguments are strings, leaving it to the app to decide how to parse them
 - No runtime memory allocations

## Using

Developed with `zig 0.14.0`

### Run the sample

    cd example-posix
    zig build run

```
myshell> help
echo
led
myshell> echo hello world
You said: { echo, hello, world }
OK
myshell> led 1
If we had an LED it would be set to true
OK
```

## Using in your own project

First add the library as a dependency in your `build.zig.zon` file.

`zig fetch --save git+https://github.com/ringtailsoftware/zig-embshell.git`

And add it to `build.zig` file.
```zig
const embshell_dep = b.dependency("embshell", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("embshell", embshell_dep.module("embshell"));
```

`@import` the module and provide a configuration.

 - `.prompt` is the string shown to the user before each command is entered
 - `.maxargs` is the maximum number of arguments EmbShell will process (e.g. "mycmd foo bar" is 3 arguments)
 - `.maxlinelen` is the maximum length of a line to be handled, a buffer of this size will be created
 - `.cmdtable` an array of names and handler function for commands

```zig
const EmbShell = @import("embshell").EmbShellFixed(.{
    .prompt = "myshell> ",
    .maxargs = 16,
    .maxlinelen = 128,
    .cmdtable = &.{
        .{ .name = "echo", .handler = echoHandler },
        .{ .name = "led", .handler = ledHandler },
    },
});
```


Each handler function is in the following form. EmbShell prints "OK" after successfully executing each function and "Failed" if an error is returned.

```zig
fn myHandler(args:[][]const u8) anyerror!void {
    // process args
    // optionally return error
}
```

Next, call `.init()` and provide a write callback to allow EmbShell to emit data

```zig
fn write(data:[]const u8) void {
    // emit data to terminal
}

var shell = try EmbShell.init(write);
```

Finally, feed EmbShell with incoming data from the terminal to be processed

```zig
const buf = readFromMyTerminal();
shell.feed(buf)
```



