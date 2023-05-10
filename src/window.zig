const C = @import("c.zig");
const std = @import("std");
const definitions = @import("definitions.zig");
const game = @import("game.zig");

const Piece = definitions.Piece;
const PieceType = definitions.PieceType;
const Rotation = definitions.Rotation;

const Color = definitions.Color;
const Colorname = definitions.Colorname;
const Colorscheme = definitions.Colorscheme;
const Style = definitions.Style;

const G = game.G;

const TARGET_FPS = 60;
const TARGET_FPS_DELAY = @divFloor(std.time.ns_per_s, TARGET_FPS);
const FONT_BYTES = @embedFile("assets/font.ttf");

// aspect ratio for width : height
const RATIO_WIDTH: usize = 18;
const RATIO_HEIGHT: usize = 22;

// feature flags, enable or disable at will
const ENABLE_RENDER_TIME = false;

const ENABLE_GRAVITY = true;
const GRAVITY_DELAY = std.time.ns_per_s;

// simple SDL renderer wrapper
const Renderer = struct {
    const Self = @This();
    renderer: ?*C.SDL_Renderer = null,
    color: Color = undefined,
    font: ?*C.TTF_Font = null,
    force_redraw: u8 = 0,

    fn set_color(self: *Self, c: Color) void {
        self.color = c;
        _ = C.SDL_SetRenderDrawColor(
            self.renderer,
            c.red,
            c.green,
            c.blue,
            0xff,
        );
    }

    fn clear(self: *Self) void {
        _ = C.SDL_RenderClear(self.renderer);
    }

    fn fill_rectangle(
        self: *Self,
        x: usize,
        y: usize,
        width: usize,
        height: usize,
    ) void {
        var rectangle = C.SDL_Rect{
            .x = @intCast(i32, x),
            .y = @intCast(i32, y),
            .w = @intCast(i32, width),
            .h = @intCast(i32, height),
        };
        _ = C.SDL_RenderFillRect(self.renderer, &rectangle);
    }

    fn fill_square(self: *Self, x: usize, y: usize) void {
        switch (G.current_style) {
            Style.Solid => {
                self.fill_rectangle(
                    G.BSIZE + x * G.BSIZE,
                    G.BSIZE + y * G.BSIZE,
                    G.SIZE,
                    G.SIZE,
                );
            },
            Style.Gridless => {
                self.fill_rectangle(
                    G.BSIZE + x * G.BSIZE,
                    G.BSIZE + y * G.BSIZE,
                    G.SIZE,
                    G.SIZE,
                );
            },
            Style.Boxes => {
                const c = self.color;
                self.fill_rectangle(
                    G.BSIZE + x * G.BSIZE,
                    G.BSIZE + y * G.BSIZE,
                    G.SIZE,
                    G.SIZE,
                );
                self.set_color(G.current_colorscheme.palette.bg_prim);
                self.fill_rectangle(
                    G.BSIZE + x * G.BSIZE + (G.SIZE >> 2),
                    G.BSIZE + y * G.BSIZE + (G.SIZE >> 2),
                    G.SIZE >> 1,
                    G.SIZE >> 1,
                );
                self.set_color(c);
            },
            Style.Edges => {
                const c = self.color;
                self.fill_rectangle(
                    G.BSIZE + x * G.BSIZE,
                    G.BSIZE + y * G.BSIZE,
                    G.SIZE,
                    G.SIZE,
                );
                self.set_color(G.current_colorscheme.palette.bg_prim);
                self.fill_rectangle(
                    G.BSIZE + x * G.BSIZE + 8 * G.BORDER,
                    G.BSIZE + y * G.BSIZE + 8 * G.BORDER,
                    G.SIZE - 16 * G.BORDER,
                    G.SIZE - 16 * G.BORDER,
                );
                self.set_color(c);
            },
        }
    }

    fn draw_dot(self: *Self, x: usize, y: usize) void {
        self.fill_rectangle(x, y, G.BORDER, G.BORDER);
    }

    fn draw_lines_cleared(self: *Self, current_lines: u64) anyerror!void {
        const S = struct {
            var colorname: Colorname = undefined;
            var lines: u64 = 1 << 63;
            var text: ?*C.SDL_Texture = null;
            var rect: C.SDL_Rect = undefined;
        };
        const lines_equal = current_lines == S.lines;
        const colors_equal = S.colorname == G.current_colorscheme.name;
        if (lines_equal and colors_equal) {
            // re-use renderered
            if (self.force_redraw == 0) {
                _ = C.SDL_RenderCopy(
                    self.renderer,
                    S.text,
                    null,
                    &S.rect,
                );
                return;
            }
            self.force_redraw -= 1;
        }

        var local_buffer: [64]u8 = .{0} ** 64;
        var buf = local_buffer[0..];
        var col_offset = G.BSIZE * game.COLUMNS + 3 * G.SIZE;
        var row_offset = G.BSIZE * (game.ROWS - 6);
        _ = std.fmt.bufPrint(
            buf,
            "{any}",
            .{current_lines},
        ) catch unreachable;
        const c_string = buf;
        const c = G.current_colorscheme.palette.fg_prim;
        const color = C.SDL_Color{
            .r = c.red,
            .g = c.green,
            .b = c.blue,
            .a = 0xff,
        };
        var surface = C.TTF_RenderText_Blended(
            self.font,
            c_string,
            color,
        ) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        defer C.SDL_FreeSurface(surface);
        var text = C.SDL_CreateTextureFromSurface(
            self.renderer,
            surface,
        ) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        const tw = surface.*.w;
        const th = surface.*.h;
        var r = C.SDL_Rect{
            .x = @intCast(i32, col_offset),
            .y = @intCast(i32, row_offset),
            .w = tw,
            .h = th,
        };
        _ = C.SDL_RenderCopy(self.renderer, text, null, &r);

        // keep previous rendered stuff
        C.SDL_DestroyTexture(S.text);
        S.colorname = G.current_colorscheme.name;
        S.lines = current_lines;
        S.text = text;
        S.rect = r;
    }

    fn draw_time_passed(
        self: *Self,
        current_time: u64,
        highlight: bool,
    ) anyerror!void {
        const S = struct {
            var colorname: Colorname = undefined;
            var time: u64 = 1 << 63;
            var text: ?*C.SDL_Texture = null;
            var rect: C.SDL_Rect = undefined;
        };
        const time_equal = current_time == S.time;
        const colors_equal = S.colorname == G.current_colorscheme.name;
        if (time_equal and colors_equal) {
            // re-use renderered
            if (self.force_redraw == 0) {
                _ = C.SDL_RenderCopy(
                    self.renderer,
                    S.text,
                    null,
                    &S.rect,
                );
                return;
            }
            self.force_redraw -= 1;
        }

        var local_buffer: [64]u8 = .{0} ** 64;
        var buf = local_buffer[0..];
        var col_offset = G.BSIZE * game.COLUMNS + 3 * G.SIZE;
        var row_offset = G.BSIZE * (game.ROWS - 4);
        _ = std.fmt.bufPrint(
            buf,
            "{any}",
            .{current_time},
        ) catch unreachable;
        const c_string = buf;
        const c = switch (highlight) {
            false => G.current_colorscheme.palette.fg_prim,
            true => G.current_colorscheme.palette.piece_T,
        };
        const color = C.SDL_Color{
            .r = c.red,
            .g = c.green,
            .b = c.blue,
            .a = 0xff,
        };
        var surface = C.TTF_RenderText_Blended(
            self.font,
            c_string,
            color,
        ) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        defer C.SDL_FreeSurface(surface);
        var text = C.SDL_CreateTextureFromSurface(
            self.renderer,
            surface,
        ) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        const tw = surface.*.w;
        const th = surface.*.h;
        var r = C.SDL_Rect{
            .x = @intCast(i32, col_offset),
            .y = @intCast(i32, row_offset),
            .w = tw,
            .h = th,
        };
        _ = C.SDL_RenderCopy(self.renderer, text, null, &r);

        // keep previous rendered stuff
        C.SDL_DestroyTexture(S.text);
        S.colorname = G.current_colorscheme.name;
        S.time = current_time;
        S.text = text;
        S.rect = r;
    }

    fn draw_frame_render_time(
        self: *Self,
        current_time: u64,
    ) anyerror!void {
        const S = struct {
            var colorname: Colorname = undefined;
            var time: u64 = 1 << 63;
            var text: ?*C.SDL_Texture = null;
            var rect: C.SDL_Rect = undefined;
        };
        const time_equal = current_time == S.time;
        const colors_equal = S.colorname == G.current_colorscheme.name;
        if (time_equal and colors_equal) {
            // re-use renderered
            if (self.force_redraw == 0) {
                _ = C.SDL_RenderCopy(
                    self.renderer,
                    S.text,
                    null,
                    &S.rect,
                );
                return;
            }
            self.force_redraw -= 1;
        }

        var local_buffer: [64]u8 = .{0} ** 64;
        var buf = local_buffer[0..];
        var col_offset = RATIO_WIDTH * G.BSIZE - (G.SIZE >> 1);
        var row_offset = G.BSIZE - (G.SIZE >> 1);
        _ = std.fmt.bufPrint(
            buf,
            "{any} ms",
            .{current_time},
        ) catch unreachable;
        const c_string = buf;
        const c = G.current_colorscheme.palette.piece_O;
        const color = C.SDL_Color{
            .r = c.red,
            .g = c.green,
            .b = c.blue,
            .a = 0xff,
        };
        var surface = C.TTF_RenderText_Blended(
            self.font,
            c_string,
            color,
        ) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        defer C.SDL_FreeSurface(surface);
        var text = C.SDL_CreateTextureFromSurface(
            self.renderer,
            surface,
        ) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        const tw = surface.*.w;
        const th = surface.*.h;
        var r = C.SDL_Rect{
            .x = @intCast(i32, col_offset) - tw,
            .y = @intCast(i32, row_offset),
            .w = tw,
            .h = th,
        };
        _ = C.SDL_RenderCopy(self.renderer, text, null, &r);

        // keep previous rendered stuff
        C.SDL_DestroyTexture(S.text);
        S.colorname = G.current_colorscheme.name;
        S.time = current_time;
        S.text = text;
        S.rect = r;
    }

    fn draw_grid(self: *Self) void {
        // basically the outline
        switch (G.current_style) {
            Style.Solid => {
                self.set_color(G.current_colorscheme.palette.fg_prim);
                self.fill_rectangle(
                    G.SIZE,
                    G.SIZE,
                    game.COLUMNS * G.BSIZE + G.BORDER,
                    game.ROWS * G.BSIZE + G.BORDER,
                );
            },
            else => {},
        }

        var r: u64 = 0;
        while (r != game.ROWS) : (r += 1) {
            var c: u64 = 0;
            while (c != game.COLUMNS) : (c += 1) {
                const t = G.Grid[r][c];
                const color = G.current_colorscheme.from_piecetype(t);
                self.set_color(color);
                self.fill_square(c, r);
            }
        }
    }

    fn draw_ghost(
        self: *Self,
        col: i8,
        row: i8,
        p: PieceType,
        r: Rotation,
    ) void {
        const timestamp: f64 = @intToFloat(
            f64,
            std.time.milliTimestamp(),
        ) / 1024;
        const ratio: u8 = @floatToInt(
            u8,
            96 * @fabs(@sin(3.141592 * timestamp)),
        );
        const piece_color = Color.combine(
            G.current_colorscheme.from_piecetype(p),
            G.current_colorscheme.palette.bg_seco,
            ratio,
        );
        self.set_color(piece_color);
        self.draw_tetromino(col, row, p, r);
    }

    fn draw_tetromino(
        self: *Self,
        col: i8,
        row: i8,
        p: PieceType,
        r: Rotation,
    ) void {
        const data = PieceType.piecetype_rotation_matrix(p, r);
        for (data) |drow, dr| {
            for (drow) |e, dc| {
                if (e != PieceType.None) {
                    const ci = @intCast(usize, col + @intCast(i8, dc));
                    const ri = @intCast(usize, row + @intCast(i8, dr));
                    self.fill_square(ci, ri);
                }
            }
        }
    }

    fn show(self: *Self) void {
        C.SDL_RenderPresent(self.renderer);
        C.SDL_Delay(0);
    }
};

const Keyboard = struct {
    const Self = @This();
    // assuming 60 fps: 7 frames before repeat kicks in -> feels great to me.
    var initial_delay: u64 = 112 * std.time.ns_per_ms;
    // this basically means instant transmission
    var repeat_delay: u64 = 0 * std.time.ns_per_ms;
    var holding: [C.SDL_NUM_SCANCODES]bool = .{false} ** C.SDL_NUM_SCANCODES;
    var repeating = false;
    keyboard: [*c]const u8,
    timer: std.time.Timer,

    fn single(self: *Self, k: C.SDL_Scancode) bool {
        var v: bool = false;
        if (self.keyboard[k] != 0) {
            if (!Keyboard.holding[k]) {
                v = true;
                Keyboard.holding[k] = true;
                self.timer.reset();
            }
        } else {
            Keyboard.holding[k] = false;
        }
        return v;
    }

    fn repeats(self: *Self, k: C.SDL_Scancode, delay: u64) bool {
        var v: bool = false;
        if (self.keyboard[k] != 0) {
            if (!Keyboard.holding[k]) {
                v = true;
                Keyboard.holding[k] = true;
                self.timer.reset();
            } else {
                const duration = self.timer.read();
                if (Keyboard.repeating and duration >= delay) {
                    self.timer.reset();
                    v = true;
                }
                if (duration >= initial_delay) {
                    Keyboard.repeating = true;
                }
            }
        } else {
            Keyboard.holding[k] = false;
        }
        return v;
    }

    fn handle_input(self: *Self, renderer: *Renderer) bool {
        var event: C.SDL_Event = undefined;

        while (C.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                C.SDL_QUIT => {
                    return true;
                },
                C.SDL_WINDOWEVENT => {
                    switch (event.window.event) {
                        C.SDL_WINDOWEVENT_SIZE_CHANGED => {
                            // we resize based on the smaller dimension, but
                            // keep the width : height ratio into account
                            const d1 = @intCast(usize, event.window.data1);
                            const d2 = @intCast(usize, event.window.data2);
                            const width = @divFloor(
                                d1 * RATIO_HEIGHT,
                                RATIO_WIDTH,
                            );
                            const height = d2;
                            const dimension = std.math.min(width, height);
                            G.SIZE = @intCast(usize, @divFloor(
                                dimension - @intCast(
                                    usize,
                                    G.BORDER,
                                ) * RATIO_HEIGHT,
                                RATIO_HEIGHT,
                            ));
                            G.BORDER = std.math.max(@divFloor(G.SIZE, 42), 1);
                            G.BSIZE = G.SIZE + G.BORDER;
                            const font = sdl2_ttf() catch unreachable;
                            renderer.font = font;
                            renderer.force_redraw = 3;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        if (self.single(C.SDL_SCANCODE_GRAVE)) {
            G.zigtris_bot = !G.zigtris_bot;
        }

        if (self.single(C.SDL_SCANCODE_ESCAPE)) {
            return true;
        }

        if (self.single(C.SDL_SCANCODE_TAB)) {
            G.current_colorscheme.next();
        }

        if (self.single(C.SDL_SCANCODE_BACKSPACE)) {
            G.current_colorscheme.previous();
        }

        if (self.single(C.SDL_SCANCODE_1)) {
            G.current_style = Style.iter[0];
        }

        if (self.single(C.SDL_SCANCODE_2)) {
            G.current_style = Style.iter[1];
        }

        if (self.single(C.SDL_SCANCODE_3)) {
            G.current_style = Style.iter[2];
        }

        if (self.single(C.SDL_SCANCODE_4)) {
            G.current_style = Style.iter[3];
        }

        if (self.single(C.SDL_SCANCODE_R)) {
            _ = game.reset_game();
        }

        if (G.zigtris_bot) {
            game.fully_automatic();
            return false;
        }

        // Player controls start here.

        if (self.single(C.SDL_SCANCODE_RCTRL)) {
            _ = game.hold_piece();
        }

        if (self.single(C.SDL_SCANCODE_A)) {
            _ = game.rotate_left();
        }

        if (self.single(C.SDL_SCANCODE_D)) {
            _ = game.rotate_spin();
        }

        if (self.single(C.SDL_SCANCODE_UP)) {
            _ = game.rotate_right();
        }

        if (self.repeats(C.SDL_SCANCODE_DOWN, 0)) {
            _ = game.move_down();
        }

        if (self.repeats(C.SDL_SCANCODE_LEFT, repeat_delay)) {
            _ = game.move_left();
        }

        if (self.repeats(C.SDL_SCANCODE_RIGHT, repeat_delay)) {
            _ = game.move_right();
        }

        if (self.single(C.SDL_SCANCODE_SPACE)) {
            _ = game.hard_drop();
        }

        const S = struct {
            const interest = [3]C.SDL_Scancode{
                C.SDL_SCANCODE_DOWN,
                C.SDL_SCANCODE_LEFT,
                C.SDL_SCANCODE_RIGHT,
            };
        };
        var h: bool = false;
        for (S.interest) |k| {
            h = h or Keyboard.holding[k];
        }
        Keyboard.repeating = Keyboard.repeating and h;

        return false;
    }
};

fn sdl2_ttf() anyerror!*C.TTF_Font {
    const S = struct {
        var last_font: ?*C.TTF_Font = null;
    };

    const font_memory = C.SDL_RWFromConstMem(
        FONT_BYTES,
        FONT_BYTES.len,
    ) orelse {
        C.SDL_Log("Unable to SDL_RWFromConstMem: %s", C.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    if (C.TTF_Init() != 0) {
        C.SDL_Log("Unable to initialize TTF: %s", C.TTF_GetError());
        return error.SDLInitializationFailed;
    }

    const font: *C.TTF_Font = C.TTF_OpenFontRW(
        font_memory,
        0,
        @intCast(i32, G.SIZE),
    ) orelse {
        C.SDL_Log("Unable to TTF_OpenFontRW: %s", C.TTF_GetError());
        return error.SDLInitializationFailed;
    };

    C.TTF_CloseFont(S.last_font);
    S.last_font = font;

    return font;
}

pub fn sdl2_game() anyerror!void {
    if (C.SDL_Init(C.SDL_INIT_VIDEO) != 0) {
        C.SDL_Log("Unable to initialize SDL: %s", C.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer C.SDL_Quit();

    const WINDOW_WIDTH: usize = RATIO_WIDTH * G.BSIZE;
    const WINDOW_HEIGHT: usize = RATIO_HEIGHT * G.BSIZE;

    // TODO
    // try SDL_WINDOW_VULKAN, if fails
    // try SDL_WINDOW_OPENGL, if fails
    // just call it quits
    const screen = C.SDL_CreateWindow(
        "Zigtris",
        C.SDL_WINDOWPOS_UNDEFINED,
        C.SDL_WINDOWPOS_UNDEFINED,
        @intCast(i32, WINDOW_WIDTH),
        @intCast(i32, WINDOW_HEIGHT),
        C.SDL_WINDOW_VULKAN | C.SDL_WINDOW_RESIZABLE,
    ) orelse {
        C.SDL_Log("Unable to create window: %s", C.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer C.SDL_DestroyWindow(screen);

    const renderer = C.SDL_CreateRenderer(screen, -1, 0) orelse {
        C.SDL_Log("Unable to create renderer: %s", C.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer C.SDL_DestroyRenderer(renderer);

    const font = sdl2_ttf() catch unreachable;
    defer C.TTF_Quit();

    var r = Renderer{
        .renderer = renderer,
        .font = font,
    };

    const keyboard = C.SDL_GetKeyboardState(null);
    var timer = try std.time.Timer.start();
    var k = Keyboard{
        .keyboard = keyboard,
        .timer = timer,
    };

    G.game_timer = try std.time.Timer.start();
    var gravity_timer = try std.time.Timer.start();
    G.xoshiro = std.rand.DefaultPrng.init(@intCast(
        u64,
        std.time.milliTimestamp(),
    ));
    G.rngesus = G.xoshiro.random();
    game.reset_game();

    var last_frame_drawn = try std.time.Timer.start();
    // NOTE unused variable if comptime ENABLE_RENDER_TIME not true
    var render_time = last_frame_drawn.read() / std.time.ns_per_ms;

    var quit = false;
    while (!quit) {
        quit = k.handle_input(&r);

        if (comptime ENABLE_GRAVITY) {
            const gravity_tick = gravity_timer.read() >= GRAVITY_DELAY;
            if (gravity_tick) {
                game.gravity_tick();
                gravity_timer.reset();
            }
        }

        if (last_frame_drawn.read() >= TARGET_FPS_DELAY) {
            last_frame_drawn.reset();
            // keep abstracting every bit of rendering
            r.set_color(G.current_colorscheme.palette.bg_prim);
            r.clear();

            r.draw_grid();

            const ghost_row = game.ghost_drop();
            r.draw_ghost(
                G.current_piece.col,
                ghost_row,
                G.current_piece.type,
                G.current_piece.rotation,
            );

            const ratio: u8 = 32;
            const piece_color = Color.combine(
                G.current_colorscheme.from_piecetype(G.current_piece.type),
                G.current_colorscheme.palette.fg_prim,
                ratio,
            );
            r.set_color(piece_color);
            r.draw_tetromino(
                G.current_piece.col,
                G.current_piece.row,
                G.current_piece.type,
                G.current_piece.rotation,
            );

            const col_offset = game.COLUMNS + 2;
            for (G.current_queue) |p, dr| {
                const row_offset = @intCast(i8, 1 + 3 * dr);
                r.set_color(G.current_colorscheme.from_piecetype(p));
                r.draw_tetromino(
                    col_offset,
                    row_offset,
                    p,
                    Rotation.None,
                );
            }

            r.set_color(
                G.current_colorscheme.from_piecetype(G.current_holding),
            );
            r.draw_tetromino(
                col_offset,
                @intCast(i8, 1 + 4 * G.current_queue.len),
                G.current_holding,
                Rotation.None,
            );

            r.draw_lines_cleared(G.lines_cleared) catch unreachable;

            // the game is a 40-line sprint + normal game by default, once you
            // clear 40 lines, the time in milliseconds will remain on the
            // screen for the rest of that session, R will reset the game.
            // during the sprint, only seconds will be shown, because seeing
            // milliseconds printed on the screen at all times is very annoying
            if (!G.sprint_finished) {
                if (G.lines_cleared < 40) {
                    const nanoseconds = G.game_timer.read();
                    const seconds = nanoseconds / std.time.ns_per_s;
                    G.sprint_time = seconds;
                } else {
                    const nanoseconds = G.game_timer.read();
                    const milliseconds = nanoseconds / std.time.ns_per_ms;
                    G.sprint_time = milliseconds;
                    G.sprint_finished = true;
                }
            }
            r.draw_time_passed(
                G.sprint_time,
                G.sprint_finished,
            ) catch unreachable;

            if (comptime ENABLE_RENDER_TIME) {
                r.draw_frame_render_time(
                    std.math.max(1, render_time),
                ) catch unreachable;
            }

            r.show();

            if (comptime ENABLE_RENDER_TIME) {
                render_time = last_frame_drawn.read() / std.time.ns_per_ms;
            }
        }

        if (!G.zigtris_bot) {
            C.SDL_Delay(@divFloor(TARGET_FPS_DELAY, std.time.ns_per_ms * 4));
        }
    }

    // free up stuff
    C.TTF_CloseFont(r.font);
}
