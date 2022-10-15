const C = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});

const std = @import("std");

// TODO initialize the random generator to make it less reproducible?
var prng = std.rand.DefaultPrng.init(0);
const rngesus = prng.random();

const FONT_BYTES = @embedFile("../assets/font.ttf");

var SIZE: usize = 64;
var BORDER: usize = 3;

const TARGET_FPS = 60;
const TARGET_FPS_DELAY = @divFloor(1000, TARGET_FPS) * std.time.ns_per_ms;

// const stdout = std.io.getStdOut().writer();
// var buffer = std.io.bufferedWriter(stdout);
// var bufio = buffer.writer();

const Color = struct {
    red: u8,
    green: u8,
    blue: u8,
    alpha: u8 = 0xff,

    pub fn from_u24(rgb: u24) Color {
        return Color{
            .red = @intCast(u8, (rgb >> 16) & 0xff),
            .green = @intCast(u8, (rgb >> 8) & 0xff),
            .blue = @intCast(u8, (rgb >> 0) & 0xff),
            .alpha = 0xff,
        };
    }

    pub fn merge(lhs: Color, rhs: Color, l: f64) Color {
        const r = (1.0 - l);
        const lr = @intToFloat(f64, lhs.red);
        const lg = @intToFloat(f64, lhs.green);
        const lb = @intToFloat(f64, lhs.blue);
        const la = @intToFloat(f64, lhs.alpha);
        const rr = @intToFloat(f64, rhs.red);
        const rg = @intToFloat(f64, rhs.green);
        const rb = @intToFloat(f64, rhs.blue);
        const ra = @intToFloat(f64, rhs.alpha);

        return Color{
            .red = @floatToInt(u8, lr * l + rr * r),
            .green = @floatToInt(u8, lg * l + rg * r),
            .blue = @floatToInt(u8, lb * l + rb * r),
            .alpha = @floatToInt(u8, la * l + ra * r),
        };
    }
};

const Rotation = enum {
    None,
    Right,
    Spin,
    Left,

    pub fn rotate(self: Rotation, other: Rotation) Rotation {
        switch (other) {
            Rotation.None => {
                return self;
            },
            Rotation.Right => {
                return self.rotate_right();
            },
            Rotation.Spin => {
                return self.rotate_spin();
            },
            Rotation.Left => {
                return self.rotate_left();
            },
        }
    }

    pub fn rotate_right(self: Rotation) Rotation {
        switch (self) {
            Rotation.None => {
                return Rotation.Right;
            },
            Rotation.Right => {
                return Rotation.Spin;
            },
            Rotation.Spin => {
                return Rotation.Left;
            },
            Rotation.Left => {
                return Rotation.None;
            },
        }
    }

    pub fn rotate_left(self: Rotation) Rotation {
        switch (self) {
            Rotation.None => {
                return Rotation.Left;
            },
            Rotation.Right => {
                return Rotation.None;
            },
            Rotation.Spin => {
                return Rotation.Right;
            },
            Rotation.Left => {
                return Rotation.Spin;
            },
        }
    }

    pub fn rotate_spin(self: Rotation) Rotation {
        switch (self) {
            Rotation.None => {
                return Rotation.Spin;
            },
            Rotation.Right => {
                return Rotation.Left;
            },
            Rotation.Spin => {
                return Rotation.None;
            },
            Rotation.Left => {
                return Rotation.Right;
            },
        }
    }

    const iter = [4]Rotation{
        Rotation.None,
        Rotation.Right,
        Rotation.Spin,
        Rotation.Left,
    };
};

const PieceType = enum {
    None,
    I,
    O,
    J,
    L,
    S,
    Z,
    T,

    const iter = [7]PieceType{
        PieceType.I,
        PieceType.O,
        PieceType.J,
        PieceType.L,
        PieceType.S,
        PieceType.Z,
        PieceType.T,
    };

    pub fn random() PieceType {
        const S = struct {
            var index: usize = 0;
            var types = [7]PieceType{
                PieceType.I,
                PieceType.O,
                PieceType.J,
                PieceType.L,
                PieceType.S,
                PieceType.Z,
                PieceType.T,
            };
        };
        if (S.index == 0) {
            rngesus.shuffle(PieceType, S.types[0..]);
        }
        S.index = (S.index + 1) % S.types.len;
        return S.types[S.index];
    }
};

const Colorname = enum {
    const Self = @This();
    habamax,
    gruvbox_dark,
    gruvbox_light,
    onedark,

    const iter = [_]Colorname{
        Colorname.habamax,
        Colorname.gruvbox_dark,
        Colorname.gruvbox_light,
        Colorname.onedark,
    };

    // TODO is there a beautiful and idiomatic iter.index_of?
    pub fn to_index(s: Self) usize {
        for (Colorname.iter) |c, i| {
            if (s == c) {
                return i;
            }
        }
        return 0;
    }
};

const Colorscheme = struct {
    const Self = @This();
    index: usize,
    foreground_light: Color,
    foreground_dark: Color,
    background_light: Color,
    background_dark: Color,
    piece_I: Color,
    piece_O: Color,
    piece_J: Color,
    piece_L: Color,
    piece_S: Color,
    piece_Z: Color,
    piece_T: Color,

    pub fn next(s: *Self) Colorscheme {
        s.index = (s.index + Colorname.iter.len + 1) % Colorname.iter.len;
        const name = Colorname.iter[s.index];
        return Colorscheme.from_name(name);
    }

    pub fn previous(s: *Self) Colorscheme {
        s.index = (s.index + Colorname.iter.len - 1) % Colorname.iter.len;
        const name = Colorname.iter[s.index];
        return Colorscheme.from_name(name);
    }

    pub fn from_name(n: Colorname) Colorscheme {
        switch (n) {
            .habamax => {
                return Colorscheme.habamax();
            },
            .gruvbox_dark => {
                return Colorscheme.gruvbox_dark();
            },
            .gruvbox_light => {
                return Colorscheme.gruvbox_light();
            },
            .onedark => {
                return Colorscheme.onedark();
            },
        }
    }

    pub fn from_piecetype(s: *Self, p: PieceType) Color {
        switch (p) {
            PieceType.None => {
                return s.background_dark;
            },
            PieceType.I => {
                return s.piece_I;
            },
            PieceType.O => {
                return s.piece_O;
            },
            PieceType.J => {
                return s.piece_J;
            },
            PieceType.L => {
                return s.piece_L;
            },
            PieceType.S => {
                return s.piece_S;
            },
            PieceType.Z => {
                return s.piece_Z;
            },
            PieceType.T => {
                return s.piece_T;
            },
        }
    }

    pub fn habamax() Colorscheme {
        return Colorscheme{
            .index = Colorname.habamax.to_index(),
            .foreground_light = Color.from_u24(0xbcbcbc), // #bcbcbc
            .foreground_dark = Color.from_u24(0x898989), // #898989
            .background_light = Color.from_u24(0x454545), // #454545
            .background_dark = Color.from_u24(0x1c1c1c), // #1c1c1c
            .piece_I = Color.from_u24(0xd75f5f), // #d75f5f
            .piece_J = Color.from_u24(0xbc796c), // #bc796c
            .piece_L = Color.from_u24(0xa19379), // #a19379
            .piece_O = Color.from_u24(0x87af87), // #87af87
            .piece_S = Color.from_u24(0x79a194), // #79a194
            .piece_T = Color.from_u24(0x6b93a1), // #6b93a1
            .piece_Z = Color.from_u24(0x5f87af), // #5f87af
        };
    }

    pub fn gruvbox_dark() Colorscheme {
        return Colorscheme{
            .index = Colorname.gruvbox_dark.to_index(),
            .foreground_light = Color.from_u24(0xebdbb2), // #ebdbb2
            .foreground_dark = Color.from_u24(0xb6ac90), // #b6ac90
            .background_light = Color.from_u24(0x5b5648), // #5b5648
            .background_dark = Color.from_u24(0x282828), // #282828
            .piece_I = Color.from_u24(0xcc241d), // #cc241d
            .piece_J = Color.from_u24(0xd65d0e), // #d65d0e
            .piece_L = Color.from_u24(0xd79921), // #d79921
            .piece_O = Color.from_u24(0x98971a), // #98971a
            .piece_S = Color.from_u24(0x689d6a), // #689d6a
            .piece_T = Color.from_u24(0x458588), // #458588
            .piece_Z = Color.from_u24(0xb16286), // #b16286
        };
    }

    pub fn gruvbox_light() Colorscheme {
        return Colorscheme{
            .index = Colorname.gruvbox_light.to_index(),
            .foreground_light = Color.from_u24(0x282828), // #282828
            .foreground_dark = Color.from_u24(0x5b5648), // #5b5648
            .background_dark = Color.from_u24(0xebdbb2), // #ebdbb2
            .background_light = Color.from_u24(0xb6ac90), // #b6ac90
            .piece_I = Color.from_u24(0xcc241d), // #cc241d
            .piece_J = Color.from_u24(0xd65d0e), // #d65d0e
            .piece_L = Color.from_u24(0xd79921), // #d79921
            .piece_O = Color.from_u24(0x98971a), // #98971a
            .piece_S = Color.from_u24(0x689d6a), // #689d6a
            .piece_T = Color.from_u24(0x458588), // #458588
            .piece_Z = Color.from_u24(0xb16286), // #b16286
        };
    }

    pub fn onedark() Colorscheme {
        return Colorscheme{
            .index = Colorname.onedark.to_index(),
            .foreground_light = Color.from_u24(0xabb2bf), // #abb2bf
            .foreground_dark = Color.from_u24(0x8c94a2), // #8c94a2
            .background_light = Color.from_u24(0x464a51), // #464a51
            .background_dark = Color.from_u24(0x282c34), // #282c34
            .piece_I = Color.from_u24(0xe06c75), // #e06c75
            .piece_J = Color.from_u24(0xe29678), // #e29678
            .piece_L = Color.from_u24(0xe5c07b), // #e5c07b
            .piece_O = Color.from_u24(0x98c379), // #98c379
            .piece_S = Color.from_u24(0x56b6c2), // #56b6c2
            .piece_T = Color.from_u24(0x61afef), // #61afef
            .piece_Z = Color.from_u24(0xc678dd), // #c678dd
        };
    }
};

fn generate_piece(t: PieceType, r: Rotation) [4][4]PieceType {
    const B = PieceType.None;
    const I = PieceType.I;
    const O = PieceType.O;
    const J = PieceType.J;
    const L = PieceType.L;
    const S = PieceType.S;
    const Z = PieceType.Z;
    const T = PieceType.T;
    switch (t) {
        I => {
            switch (r) {
                .None => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ I, I, I, I },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Right => {
                    const data = [4][4]PieceType{
                        .{ B, B, I, B },
                        .{ B, B, I, B },
                        .{ B, B, I, B },
                        .{ B, B, I, B },
                    };
                    return data;
                },
                .Spin => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                        .{ I, I, I, I },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Left => {
                    const data = [4][4]PieceType{
                        .{ B, I, B, B },
                        .{ B, I, B, B },
                        .{ B, I, B, B },
                        .{ B, I, B, B },
                    };
                    return data;
                },
            }
        },
        O => {
            switch (r) {
                .None => {
                    const data = [4][4]PieceType{
                        .{ O, O, B, B },
                        .{ O, O, B, B },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Right => {
                    const data = [4][4]PieceType{
                        .{ B, O, O, B },
                        .{ B, O, O, B },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Spin => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ B, O, O, B },
                        .{ B, O, O, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Left => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ O, O, B, B },
                        .{ O, O, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
            }
        },
        J => {
            switch (r) {
                .None => {
                    const data = [4][4]PieceType{
                        .{ J, B, B, B },
                        .{ J, J, J, B },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Right => {
                    const data = [4][4]PieceType{
                        .{ B, J, J, B },
                        .{ B, J, B, B },
                        .{ B, J, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Spin => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ J, J, J, B },
                        .{ B, B, J, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Left => {
                    const data = [4][4]PieceType{
                        .{ B, J, B, B },
                        .{ B, J, B, B },
                        .{ J, J, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
            }
        },
        L => {
            switch (r) {
                .None => {
                    const data = [4][4]PieceType{
                        .{ B, B, L, B },
                        .{ L, L, L, B },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Right => {
                    const data = [4][4]PieceType{
                        .{ B, L, B, B },
                        .{ B, L, B, B },
                        .{ B, L, L, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Spin => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ L, L, L, B },
                        .{ L, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Left => {
                    const data = [4][4]PieceType{
                        .{ L, L, B, B },
                        .{ B, L, B, B },
                        .{ B, L, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
            }
        },
        S => {
            switch (r) {
                .None => {
                    const data = [4][4]PieceType{
                        .{ B, S, S, B },
                        .{ S, S, B, B },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Right => {
                    const data = [4][4]PieceType{
                        .{ B, S, B, B },
                        .{ B, S, S, B },
                        .{ B, B, S, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Spin => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ B, S, S, B },
                        .{ S, S, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Left => {
                    const data = [4][4]PieceType{
                        .{ S, B, B, B },
                        .{ S, S, B, B },
                        .{ B, S, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
            }
        },
        Z => {
            switch (r) {
                .None => {
                    const data = [4][4]PieceType{
                        .{ Z, Z, B, B },
                        .{ B, Z, Z, B },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Right => {
                    const data = [4][4]PieceType{
                        .{ B, B, Z, B },
                        .{ B, Z, Z, B },
                        .{ B, Z, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Spin => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ Z, Z, B, B },
                        .{ B, Z, Z, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Left => {
                    const data = [4][4]PieceType{
                        .{ B, Z, B, B },
                        .{ Z, Z, B, B },
                        .{ Z, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
            }
        },
        T => {
            switch (r) {
                .None => {
                    const data = [4][4]PieceType{
                        .{ B, T, B, B },
                        .{ T, T, T, B },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Right => {
                    const data = [4][4]PieceType{
                        .{ B, T, B, B },
                        .{ B, T, T, B },
                        .{ B, T, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Spin => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ T, T, T, B },
                        .{ B, T, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
                .Left => {
                    const data = [4][4]PieceType{
                        .{ B, T, B, B },
                        .{ T, T, B, B },
                        .{ B, T, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
            }
        },
        B => {
            switch (r) {
                else => {
                    const data = [4][4]PieceType{
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                        .{ B, B, B, B },
                    };
                    return data;
                },
            }
        },
    }
}

const MinMaxRC = struct {
    min_row: i8,
    min_col: i8,
    max_row: i8,
    max_col: i8,

    fn minmax_rowcol(t: PieceType, r: Rotation) MinMaxRC {
        // TODO generate a lookup-table at comptime for efficiency at runtime
        const data = generate_piece(t, r);
        const B = PieceType.None;

        var min_row: u8 = 0;
        var min_col: u8 = 0;
        var max_row: u8 = 3;
        var max_col: u8 = 3;

        // TODO how to make a beautiful all-are-equal-to function?
        while (data[max_row][0] == B and data[max_row][1] == B and data[max_row][2] == B and data[max_row][3] == B) : (max_row -= 1) {}
        while (data[min_row][0] == B and data[min_row][1] == B and data[min_row][2] == B and data[min_row][3] == B) : (min_row += 1) {}
        while (data[0][max_col] == B and data[1][max_col] == B and data[2][max_col] == B and data[3][max_col] == B) : (max_col -= 1) {}
        while (data[0][min_col] == B and data[1][min_col] == B and data[2][min_col] == B and data[3][min_col] == B) : (min_col += 1) {}

        return MinMaxRC{
            .min_row = @intCast(i8, min_row),
            .min_col = @intCast(i8, min_col),
            .max_row = @intCast(i8, max_row),
            .max_col = @intCast(i8, max_col),
        };
    }
};

const Piece = struct {
    const Self = @This();
    type: PieceType,
    rotation: Rotation,
    col: i8,
    row: i8,

    pub fn from_piecetype(t: PieceType) Piece {
        return Piece{
            .type = t,
            .rotation = Rotation.None,
            .col = 3,
            .row = 0,
        };
    }

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        if (fmt.len != 0) {
            @compileError("Unknown format string: '" ++ fmt ++ "'");
        }
        _ = options;
        return std.fmt.format(writer, "{any} {any}@({d},{d})", .{
            self.type,
            self.rotation,
            self.x,
            self.y,
        });
    }
};

// the game (you just lost)
const ROWS: u8 = 20;
const COLUMNS: u8 = 10;

var Grid = [1][COLUMNS]PieceType{
    .{PieceType.None} ** COLUMNS,
} ** ROWS;

var game_timer: std.time.Timer = undefined;

// dummy placeholder, just call next_piece at the start
var current_piece = Piece{
    .type = PieceType.None,
    .rotation = Rotation.None,
    .col = 3,
    .row = 0,
};

var current_holding = PieceType.None;

var current_queue = [4]PieceType{
    PieceType.None,
    PieceType.None,
    PieceType.None,
    PieceType.None,
};

var lines_cleared: u64 = 0;
var pieces_locked: u64 = 0;
var sprint_time: u64 = undefined;
var sprint_finished: bool = false;
var current_colorscheme = Colorscheme.habamax();

fn collision() bool {
    const row = current_piece.row;
    const col = current_piece.col;
    const mmrc = MinMaxRC.minmax_rowcol(current_piece.type, current_piece.rotation);

    if (col + mmrc.min_col < 0 or col + mmrc.max_col >= COLUMNS) {
        return true;
    }

    if (row + mmrc.min_row < 0 or row + mmrc.max_row >= ROWS) {
        return true;
    }

    // collision with pieces on the grid?
    const B = PieceType.None;
    const data = generate_piece(current_piece.type, current_piece.rotation);
    for (data) |drow, dr| {
        for (drow) |e, dc| {
            if (e != B) {
                const c = @intCast(usize, col + @intCast(i8, dc));
                const r = @intCast(usize, row + @intCast(i8, dr));
                if (Grid[r][c] != B) {
                    return true;
                }
            }
        }
    }

    return false;
}

fn move_left() bool {
    const col = current_piece.col;
    current_piece.col -= 1;
    if (collision()) {
        current_piece.col = col;
        return false;
    }
    return true;
}

fn move_right() bool {
    const col = current_piece.col;
    current_piece.col += 1;
    if (collision()) {
        current_piece.col = col;
        return false;
    }
    return true;
}

fn move_down() bool {
    const row = current_piece.row;
    current_piece.row += 1;
    if (collision()) {
        current_piece.row = row;
        return false;
    }
    return true;
}

// :^)
fn move_up() bool {
    const row = current_piece.row;
    current_piece.row -= 1;
    if (collision()) {
        current_piece.row = row;
        return false;
    }
    return true;
}

fn materialize() void {
    // TODO push current piece onto a stack for bookkeeping
    // * useful for in a bot, and maybe replays.
    const data = generate_piece(current_piece.type, current_piece.rotation);
    const col = current_piece.col;
    const row = current_piece.row;
    for (data) |drow, dr| {
        for (drow) |e, dc| {
            if (e != PieceType.None) {
                const c = @intCast(usize, col + @intCast(i8, dc));
                const r = @intCast(usize, row + @intCast(i8, dr));
                Grid[r][c] = e;
            }
        }
    }
}

fn next_piece() void {
    current_piece = Piece.from_piecetype(current_queue[0]);
    current_queue[0] = current_queue[1];
    current_queue[1] = current_queue[2];
    current_queue[2] = current_queue[3];
    current_queue[3] = PieceType.random();
}

fn hold_piece() void {
    const t = current_piece.type;
    current_piece = Piece.from_piecetype(current_holding);
    current_holding = t;
}

fn clear_grid() void {
    for (Grid) |Row, r| {
        for (Row) |_, c| {
            Grid[r][c] = PieceType.None;
        }
    }
}

fn reset_game() void {
    clear_grid();

    pieces_locked = 0;
    lines_cleared = 0;

    current_piece = Piece.from_piecetype(PieceType.random());
    current_holding = PieceType.random();
    current_queue[0] = PieceType.random();
    current_queue[1] = PieceType.random();
    current_queue[2] = PieceType.random();
    current_queue[3] = PieceType.random();

    game_timer.reset();

    sprint_time = undefined;
    sprint_finished = false;
}

fn piece_lock() void {
    materialize();
    pieces_locked += 1;
    lines_cleared += clear_lines();
    next_piece();
}

fn ghost_drop() i8 {
    const backup_row = current_piece.row;
    while (move_down()) {}
    const ghost_row = current_piece.row;
    current_piece.row = backup_row;
    return ghost_row;
}

fn hard_drop() void {
    while (move_down()) {}
    piece_lock();
}

const Delta = struct {
    row: i8 = 0,
    col: i8 = 0,
};

fn unstuck() bool {
    const S = struct {
        const deltas = [16]Delta{
            // same level
            .{ .row = 0, .col = 0 },
            .{ .row = 0, .col = 1 },
            .{ .row = 0, .col = -1 },
            // one deeper
            .{ .row = 1, .col = 0 },
            .{ .row = 1, .col = 1 },
            .{ .row = 1, .col = -1 },
            // two deeper
            .{ .row = 2, .col = 0 },
            .{ .row = 2, .col = 1 },
            .{ .row = 2, .col = -1 },
            .{ .row = 2, .col = 2 },
            .{ .row = 2, .col = -2 },
            // back up
            .{ .row = -1, .col = 0 },
            .{ .row = -1, .col = 1 },
            .{ .row = -1, .col = -1 },
            .{ .row = -1, .col = 2 },
            .{ .row = -1, .col = -2 },
        };
    };

    const col = current_piece.col;
    const row = current_piece.row;
    for (S.deltas) |delta| {
        current_piece.col += delta.col;
        current_piece.row += delta.row;
        if (!collision()) {
            return true;
        }
        current_piece.col = col;
        current_piece.row = row;
    }
    return false;
}

fn rotate_right() void {
    const r = current_piece.rotation;
    current_piece.rotation = r.rotate_right();
    if (!unstuck()) {
        current_piece.rotation = r;
    }
}

fn rotate_left() void {
    const r = current_piece.rotation;
    current_piece.rotation = r.rotate_left();
    if (!unstuck()) {
        current_piece.rotation = r;
    }
}

fn rotate_spin() void {
    const r = current_piece.rotation;
    current_piece.rotation = r.rotate_spin();
    if (!unstuck()) {
        current_piece.rotation = r;
    }
}

fn clear_lines() u8 {
    // std.log.info("clear_lines()", .{});
    var cleared: u8 = 0;
    var r: u8 = ROWS - 1;
    while (r != 0) {
        var clear: bool = true;
        var c: u8 = 0;
        while (clear and c != COLUMNS) : (c += 1) {
            clear = clear and Grid[r][c] != PieceType.None;
        }
        if (clear) {
            var up: u8 = r - 1;
            while (up != 0) {
                c = 0;
                while (c != COLUMNS) : (c += 1) {
                    Grid[up + 1][c] = Grid[up][c];
                }
                up -= 1;
            }
            // when up == 0
            c = 0;
            while (c != COLUMNS) : (c += 1) {
                Grid[up + 1][c] = Grid[up][c];
                Grid[up][c] = PieceType.None;
            }
            cleared += 1;
        } else {
            r -= 1;
        }
    }
    return cleared;
}

// simple SDL renderer wrapper
const Renderer = struct {
    const Self = @This();
    renderer: *C.SDL_Renderer = undefined,
    color: Color = undefined,
    font: *C.TTF_Font = undefined,
    force_redraw: u8 = 0,

    pub fn set_color(self: *Self, c: Color) void {
        self.color = c;
        _ = C.SDL_SetRenderDrawColor(
            self.renderer,
            c.red,
            c.green,
            c.blue,
            c.alpha,
        );
    }

    pub fn clear(self: *Self) void {
        _ = C.SDL_RenderClear(self.renderer);
    }

    pub fn fill_rectangle(
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
        _ = C.SDL_SetRenderDrawColor(
            self.renderer,
            self.color.red,
            self.color.green,
            self.color.blue,
            self.color.alpha,
        );
        _ = C.SDL_RenderFillRect(self.renderer, &rectangle);
    }

    pub fn fill_square(self: *Self, x: usize, y: usize) void {
        self.fill_rectangle(
            BORDER + SIZE + x * (BORDER + SIZE),
            BORDER + SIZE + y * (BORDER + SIZE),
            SIZE,
            SIZE,
        );
    }

    pub fn draw_dot(self: *Self, x: usize, y: usize) void {
        self.fill_rectangle(x, y, BORDER, BORDER);
    }

    pub fn draw_lines_cleared(self: *Self, lines: u64) anyerror!void {
        const S = struct {
            var last_colorscheme_index: usize = undefined;
            var last_lines: u64 = 1 << 63;
            var last_text: *C.SDL_Texture = undefined;
            var last_rect: C.SDL_Rect = undefined;
        };
        if (lines == S.last_lines and S.last_colorscheme_index == current_colorscheme.index) {
            // re-use renderered
            if (self.force_redraw == 0) {
                _ = C.SDL_RenderCopy(self.renderer, S.last_text, null, &S.last_rect);
                return;
            }
            self.force_redraw -= 1;
        }

        var local_buffer: [64]u8 = .{0} ** 64;
        var buf = local_buffer[0..];
        var col_offset = (BORDER + SIZE) * COLUMNS + 3 * SIZE;
        var row_offset = (BORDER + SIZE) * (ROWS - 6);
        _ = std.fmt.bufPrint(buf, "{any}", .{lines}) catch {};
        const c_string = buf;
        const c = current_colorscheme.foreground_light;
        const color = C.SDL_Color{ .r = c.red, .g = c.green, .b = c.blue, .a = c.alpha };
        var surface = C.TTF_RenderText_Blended(
            self.font,
            c_string,
            color,
        ) orelse {
            C.SDL_Log("Unable to TTF_RenderText_Blended: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        defer C.SDL_FreeSurface(surface);
        var text = C.SDL_CreateTextureFromSurface(
            self.renderer,
            surface,
        ) orelse {
            C.SDL_Log("Unable to SDL_CreateTextureFromSurface: %s", C.SDL_GetError());
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
        if (S.last_text != undefined) {
            C.SDL_DestroyTexture(S.last_text);
        }
        S.last_colorscheme_index = current_colorscheme.index;
        S.last_lines = lines;
        S.last_text = text;
        S.last_rect = r;
    }

    pub fn draw_time_passed(self: *Self, seconds: u64) anyerror!void {
        const S = struct {
            var last_colorscheme_index: usize = undefined;
            var last_seconds: u64 = 1 << 63;
            var last_text: *C.SDL_Texture = undefined;
            var last_rect: C.SDL_Rect = undefined;
        };
        if (seconds == S.last_seconds and S.last_colorscheme_index == current_colorscheme.index) {
            // re-use renderered
            if (self.force_redraw == 0) {
                _ = C.SDL_RenderCopy(self.renderer, S.last_text, null, &S.last_rect);
                return;
            }
            self.force_redraw -= 1;
        }

        var local_buffer: [64]u8 = .{0} ** 64;
        var buf = local_buffer[0..];
        var col_offset = (BORDER + SIZE) * COLUMNS + 3 * SIZE;
        var row_offset = (BORDER + SIZE) * (ROWS - 4);
        _ = std.fmt.bufPrint(buf, "{any}", .{seconds}) catch {};
        const c_string = buf;
        const c = current_colorscheme.foreground_light;
        const color = C.SDL_Color{ .r = c.red, .g = c.green, .b = c.blue, .a = c.alpha };
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
        if (S.last_text != undefined) {
            C.SDL_DestroyTexture(S.last_text);
        }
        S.last_colorscheme_index = current_colorscheme.index;
        S.last_seconds = seconds;
        S.last_text = text;
        S.last_rect = r;
    }

    pub fn draw_grid(self: *Self) void {
        // basically the outline
        self.set_color(current_colorscheme.foreground_light);
        self.fill_rectangle(
            SIZE,
            SIZE,
            COLUMNS * (SIZE + BORDER) + BORDER,
            ROWS * (SIZE + BORDER) + BORDER,
        );

        var r: u64 = 0;
        while (r != ROWS) : (r += 1) {
            var c: u64 = 0;
            while (c != COLUMNS) : (c += 1) {
                const t = Grid[r][c];
                const color = current_colorscheme.from_piecetype(t);
                self.set_color(color);
                self.fill_square(c, r);
            }
        }
    }

    pub fn draw_ghost(
        self: *Self,
        col: i8,
        row: i8,
        p: PieceType,
        r: Rotation,
    ) void {
        const timestamp: f64 = @intToFloat(f64, std.time.milliTimestamp()) / 1e3;
        const ratio = 0.4 * @fabs(@sin(3.141592 * timestamp));
        const piece_color = Color.merge(
            current_colorscheme.from_piecetype(p),
            current_colorscheme.background_light,
            ratio,
        );
        self.set_color(piece_color);
        const data = generate_piece(p, r);
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

    pub fn draw_tetromino(
        self: *Self,
        col: i8,
        row: i8,
        p: PieceType,
        r: Rotation,
    ) void {
        const piece_color = current_colorscheme.from_piecetype(p);
        self.set_color(piece_color);
        const data = generate_piece(p, r);
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

    pub fn show(self: *Self) void {
        C.SDL_RenderPresent(self.renderer);
        C.SDL_Delay(0);
    }
};

const Keyboard = struct {
    const Self = @This();
    var initial_delay: u64 = 120 * std.time.ns_per_ms;
    var repeat_delay: u64 = 40 * std.time.ns_per_ms;
    var holding: [C.SDL_NUM_SCANCODES]bool = .{false} ** C.SDL_NUM_SCANCODES;
    var repeating = false;
    keyboard: [*c]const u8,
    timer: std.time.Timer,

    pub fn single(self: *Self, k: C.SDL_Scancode) bool {
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

    pub fn repeats(self: *Self, k: C.SDL_Scancode, delay: u64) bool {
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

    pub fn handle_input(self: *Self, renderer: *Renderer) bool {
        var event: C.SDL_Event = undefined;

        while (C.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                C.SDL_QUIT => {
                    return true;
                },
                C.SDL_WINDOWEVENT => {
                    switch (event.window.event) {
                        C.SDL_WINDOWEVENT_SIZE_CHANGED => {
                            const width = event.window.data1;
                            const height = event.window.data2;
                            // we only resize based on height
                            _ = width;
                            SIZE = @intCast(usize, @divFloor(
                                height - @intCast(i32, BORDER) * 22,
                                22,
                            ));
                            BORDER = @divFloor(SIZE, 32) | 1;
                            const font = sdl2_ttf() catch unreachable;
                            renderer.font = font;
                            renderer.force_redraw = 2;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        if (self.single(C.SDL_SCANCODE_ESCAPE)) {
            return true;
        }

        if (self.single(C.SDL_SCANCODE_TAB)) {
            current_colorscheme = current_colorscheme.next();
        }

        if (self.single(C.SDL_SCANCODE_BACKSPACE)) {
            current_colorscheme = current_colorscheme.previous();
        }

        if (self.single(C.SDL_SCANCODE_R)) {
            _ = reset_game();
        }

        if (self.single(C.SDL_SCANCODE_RCTRL)) {
            _ = hold_piece();
        }

        if (self.single(C.SDL_SCANCODE_A)) {
            _ = rotate_left();
        }

        if (self.single(C.SDL_SCANCODE_D)) {
            _ = rotate_spin();
        }

        if (self.single(C.SDL_SCANCODE_UP)) {
            _ = rotate_right();
        }

        if (self.repeats(C.SDL_SCANCODE_DOWN, repeat_delay / 4)) {
            _ = move_down();
        }

        if (self.repeats(C.SDL_SCANCODE_LEFT, repeat_delay)) {
            _ = move_left();
        }

        if (self.repeats(C.SDL_SCANCODE_RIGHT, repeat_delay)) {
            _ = move_right();
        }

        if (self.single(C.SDL_SCANCODE_SPACE)) {
            if (collision()) {
                // game over!
                reset_game();
            }
            _ = hard_drop();
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
        var last_font: *C.TTF_Font = undefined;
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
        @intCast(i32, SIZE),
    ) orelse {
        C.SDL_Log("Unable to TTF_OpenFontRW: %s", C.TTF_GetError());
        return error.SDLInitializationFailed;
    };

    if (S.last_font != undefined) {
        C.TTF_CloseFont(S.last_font);
    }
    S.last_font = font;

    return font;
}

fn sdl2_game() anyerror!void {
    if (C.SDL_Init(C.SDL_INIT_VIDEO) != 0) {
        C.SDL_Log("Unable to initialize SDL: %s", C.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer C.SDL_Quit();

    const WINDOW_WIDTH: usize = 20 * (SIZE + BORDER);
    const WINDOW_HEIGHT: usize = 22 * (SIZE + BORDER);

    const screen = C.SDL_CreateWindow(
        "Zigtris",
        C.SDL_WINDOWPOS_UNDEFINED,
        C.SDL_WINDOWPOS_UNDEFINED,
        @intCast(i32, WINDOW_WIDTH),
        @intCast(i32, WINDOW_HEIGHT),
        C.SDL_WINDOW_OPENGL,
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

    game_timer = try std.time.Timer.start();
    reset_game();

    var last_frame_drawn = try std.time.Timer.start();

    var quit = false;
    while (!quit) {
        quit = k.handle_input(&r);

        if (last_frame_drawn.read() > TARGET_FPS_DELAY) {
            last_frame_drawn.reset();
            // keep abstracting every bit of rendering
            r.set_color(current_colorscheme.background_dark);
            r.clear();

            r.draw_grid();
            r.draw_lines_cleared(lines_cleared) catch {};

            if (!sprint_finished) {
                if (lines_cleared < 40) {
                    const nanoseconds = game_timer.read();
                    const seconds = nanoseconds / std.time.ns_per_s;
                    sprint_time = seconds;
                } else {
                    const nanoseconds = game_timer.read();
                    const milliseconds = nanoseconds / std.time.ns_per_ms;
                    sprint_time = milliseconds;
                    sprint_finished = true;
                }
            }
            r.draw_time_passed(sprint_time) catch {};

            const ghost_row = ghost_drop();
            r.draw_ghost(
                current_piece.col,
                ghost_row,
                current_piece.type,
                current_piece.rotation,
            );

            r.draw_tetromino(
                current_piece.col,
                current_piece.row,
                current_piece.type,
                current_piece.rotation,
            );

            for (current_queue) |p, dr| {
                const row_offset = @intCast(i8, 1 + 3 * dr);
                r.draw_tetromino(
                    COLUMNS + 2,
                    row_offset,
                    p,
                    Rotation.None,
                );
            }

            r.draw_tetromino(
                COLUMNS + 2,
                @intCast(i8, 1 + 4 * current_queue.len),
                current_holding,
                Rotation.None,
            );

            r.show();
        }
    }

    // free up stuff
    C.TTF_CloseFont(r.font);
}

pub fn main() anyerror!void {
    sdl2_game() catch {};
    // bufio.context.flush() catch {};
}

// rigorous testing :^)
test "clear lines" {
    var c: u8 = 0;
    while (c != COLUMNS) : (c += 1) {
        Grid[19][c] = PieceType.I;
        Grid[18][c] = PieceType.I;
        Grid[17][c] = PieceType.I;
        Grid[16][c] = PieceType.I;
    }
    const cleared = clear_lines();
    try std.testing.expectEqual(cleared, 4);
}