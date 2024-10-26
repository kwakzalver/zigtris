pub usingnamespace @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});

pub inline fn int(a: anytype) c_int {
    return @as(c_int, @intCast(a));
}
