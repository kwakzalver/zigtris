const std = @import("std");
const zigtris = @import("game.zig");

pub fn main() !void {
    try zigtris.sdl3_game();
}

test {
    std.testing.refAllDecls(@This());
}
