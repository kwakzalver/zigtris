const std = @import("std");
const zigtris = @import("game.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    try zigtris.sdl2_game(arena.allocator());
}
