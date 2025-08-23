const Standard = @import("std");

pub usingnamespace @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});

pub inline fn int(a: anytype) c_int {
    return @intCast(a);
}

pub inline fn float(a: anytype) f32 {
    return @floatFromInt(a);
}
