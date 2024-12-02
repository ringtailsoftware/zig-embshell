# zig-embshell

Toby Jaffey https://mastodon.me.uk/@tobyjaffey

A small interactive command line for Zig programs.

Every microcontroller project I do ends up with a command shell on the UART. This is an implementation of a similar system in zig.

**Note**: zig-embshell is my first ever program in zig. For me, it's a learning exercise.

## Running

Developed with `zig 0.13.0`

    zig build run

## Adding commands

Edit `src/cmds.zig`

Each handler is registered in `cmdTable` which is `const` and constructed at `comptime`. Every handler is passed `argc` (the number of arguments) and an `argv` array. `argv[0]` is the command name, the arguments follow.

## Features

 - Basic tab completion (command names only)
 - Backspace for basic line editing

## Aims

 - Learn some zig
 - Be reasonably readable
 - Target a tiny system with no heap
 - Keep term.zig small and portable

## Non-Aims

 - Don't be readline/linenoise (no history, nothing fancy)
 - No live adding of new commands, everything compiled in

