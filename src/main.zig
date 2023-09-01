const std = @import("std");
const window = @import("window.zig");

pub fn main() anyerror!void {
    window.sdl2_game() catch unreachable;
}
