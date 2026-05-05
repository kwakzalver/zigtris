const std = @import("std");
const zigtris = @import("game.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    try zigtris.sdl3_game(io);
}

test {
    std.testing.refAllDecls(@This());
}
