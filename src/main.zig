const C = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});

const std = @import("std");

var xoshiro: std.rand.Xoshiro256 = undefined;
var rngesus: std.rand.Random = undefined;

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
    const Self = @This();
    None,
    Right,
    Spin,
    Left,

    pub fn rotate(self: Rotation, other: Rotation) Rotation {
        return switch (other) {
            Rotation.None => self,
            Rotation.Right => self.rotate_right(),
            Rotation.Spin => self.rotate_spin(),
            Rotation.Left => self.rotate_left(),
        };
    }

    pub fn rotate_right(self: Rotation) Rotation {
        return switch (self) {
            Rotation.None => Rotation.Right,
            Rotation.Right => Rotation.Spin,
            Rotation.Spin => Rotation.Left,
            Rotation.Left => Rotation.None,
        };
    }

    pub fn rotate_left(self: Rotation) Rotation {
        return switch (self) {
            Rotation.None => Rotation.Left,
            Rotation.Right => Rotation.None,
            Rotation.Spin => Rotation.Right,
            Rotation.Left => Rotation.Spin,
        };
    }

    pub fn rotate_spin(self: Rotation) Rotation {
        return switch (self) {
            Rotation.None => Rotation.Spin,
            Rotation.Right => Rotation.Left,
            Rotation.Spin => Rotation.None,
            Rotation.Left => Rotation.Right,
        };
    }

    const iter = [4]Rotation{
        Rotation.None,
        Rotation.Right,
        Rotation.Spin,
        Rotation.Left,
    };

    // TODO is there a beautiful and idiomatic way
    fn iter_index(s: Self) usize {
        for (Rotation.iter) |c, i| {
            if (s == c) {
                return i;
            }
        }
        return 0;
    }
};

const PieceType = enum {
    const Self = @This();
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
        const t = S.types[S.index];
        S.index = (S.index + 1) % S.types.len;
        return t;
    }

    // TODO is there a beautiful and idiomatic way
    pub fn iter_index(s: Self) usize {
        for (PieceType.iter) |c, i| {
            if (s == c) {
                return i;
            }
        }
        return 0;
    }
};

const Colorname = enum {
    const Self = @This();
    habamax,
    gruvbox_dark,
    gruvbox_light,
    onedark,
    macchiato,

    const iter = [_]Colorname{
        Colorname.habamax,
        Colorname.gruvbox_dark,
        Colorname.gruvbox_light,
        Colorname.onedark,
        Colorname.macchiato,
    };

    // TODO is there a beautiful and idiomatic way
    pub fn iter_index(s: Self) usize {
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
    fg_prim: Color,
    fg_seco: Color,
    bg_seco: Color,
    bg_prim: Color,
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
        return switch (n) {
            .habamax => Colorscheme.habamax(),
            .gruvbox_dark => Colorscheme.gruvbox_dark(),
            .gruvbox_light => Colorscheme.gruvbox_light(),
            .onedark => Colorscheme.onedark(),
            .macchiato => Colorscheme.macchiato(),
        };
    }

    pub fn from_piecetype(s: *Self, p: PieceType) Color {
        return switch (p) {
            PieceType.None => s.bg_prim,
            PieceType.I => s.piece_I,
            PieceType.O => s.piece_O,
            PieceType.J => s.piece_J,
            PieceType.L => s.piece_L,
            PieceType.S => s.piece_S,
            PieceType.Z => s.piece_Z,
            PieceType.T => s.piece_T,
        };
    }

    pub fn habamax() Colorscheme {
        return Colorscheme{
            .index = Colorname.habamax.iter_index(),
            .fg_prim = Color.from_u24(0xBCBCBC), // #BCBCBC
            .fg_seco = Color.from_u24(0x898989), // #898989
            .bg_seco = Color.from_u24(0x454545), // #454545
            .bg_prim = Color.from_u24(0x1C1C1C), // #1C1C1C
            .piece_I = Color.from_u24(0xD75F5F), // #D75F5F
            .piece_J = Color.from_u24(0xBC796C), // #BC796C
            .piece_L = Color.from_u24(0xA19379), // #A19379
            .piece_O = Color.from_u24(0x87AF87), // #87AF87
            .piece_S = Color.from_u24(0x79A194), // #79A194
            .piece_T = Color.from_u24(0x6B93A1), // #6B93A1
            .piece_Z = Color.from_u24(0x5F87AF), // #5F87AF
        };
    }

    pub fn gruvbox_dark() Colorscheme {
        return Colorscheme{
            .index = Colorname.gruvbox_dark.iter_index(),
            .fg_prim = Color.from_u24(0xEBDBB2), // #EBDBB2
            .fg_seco = Color.from_u24(0xB6AC90), // #B6AC90
            .bg_seco = Color.from_u24(0x5B5648), // #5B5648
            .bg_prim = Color.from_u24(0x282828), // #282828
            .piece_I = Color.from_u24(0xCC241D), // #CC241D
            .piece_J = Color.from_u24(0xD65D0E), // #D65D0E
            .piece_L = Color.from_u24(0xD79921), // #D79921
            .piece_O = Color.from_u24(0x98971A), // #98971A
            .piece_S = Color.from_u24(0x689D6A), // #689D6A
            .piece_T = Color.from_u24(0x458588), // #458588
            .piece_Z = Color.from_u24(0xB16286), // #B16286
        };
    }

    pub fn gruvbox_light() Colorscheme {
        return Colorscheme{
            .index = Colorname.gruvbox_light.iter_index(),
            .fg_prim = Color.from_u24(0x282828), // #282828
            .fg_seco = Color.from_u24(0x5B5648), // #5B5648
            .bg_prim = Color.from_u24(0xEBDBB2), // #EBDBB2
            .bg_seco = Color.from_u24(0xB6AC90), // #B6AC90
            .piece_I = Color.from_u24(0xCC241D), // #CC241D
            .piece_J = Color.from_u24(0xD65D0E), // #D65D0E
            .piece_L = Color.from_u24(0xD79921), // #D79921
            .piece_O = Color.from_u24(0x98971A), // #98971A
            .piece_S = Color.from_u24(0x689D6A), // #689D6A
            .piece_T = Color.from_u24(0x458588), // #458588
            .piece_Z = Color.from_u24(0xB16286), // #B16286
        };
    }

    pub fn onedark() Colorscheme {
        return Colorscheme{
            .index = Colorname.onedark.iter_index(),
            .fg_prim = Color.from_u24(0xABB2BF), // #ABB2BF
            .fg_seco = Color.from_u24(0x8C94A2), // #8C94A2
            .bg_seco = Color.from_u24(0x464A51), // #464A51
            .bg_prim = Color.from_u24(0x282C34), // #282C34
            .piece_I = Color.from_u24(0xE06C75), // #E06C75
            .piece_J = Color.from_u24(0xE29678), // #E29678
            .piece_L = Color.from_u24(0xE5C07B), // #E5C07B
            .piece_O = Color.from_u24(0x98C379), // #98C379
            .piece_S = Color.from_u24(0x56B6C2), // #56B6C2
            .piece_T = Color.from_u24(0x61AFEF), // #61AFEF
            .piece_Z = Color.from_u24(0xC678DD), // #C678DD
        };
    }

    pub fn macchiato() Colorscheme {
        return Colorscheme{
            .index = Colorname.macchiato.iter_index(),
            .fg_prim = Color.from_u24(0xCAD3F5), // #CAD3F5
            .fg_seco = Color.from_u24(0xB8C0E0), // #B8C0E0
            .bg_seco = Color.from_u24(0x494D64), // #494D64
            .bg_prim = Color.from_u24(0x24273A), // #24273A
            .piece_I = Color.from_u24(0xED8796), // #ED8796
            .piece_J = Color.from_u24(0xF5A97F), // #F5A97F
            .piece_L = Color.from_u24(0xEED49F), // #EED49F
            .piece_O = Color.from_u24(0xA6DA95), // #A6DA95
            .piece_S = Color.from_u24(0x8BD5CA), // #8BD5CA
            .piece_T = Color.from_u24(0x8AADF4), // #8AADF4
            .piece_Z = Color.from_u24(0xF5BDE6), // #F5BDE6
        };
    }
};

const Style = enum {
    const Self = @This();
    Solid,
    Gridless,
    Edges,

    const iter = [_]Style{
        Style.Solid,
        Style.Gridless,
        Style.Edges,
    };
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
    return switch (t) {
        I => switch (r) {
            .None => [4][4]PieceType{
                .{ B, B, B, B },
                .{ I, I, I, I },
                .{ B, B, B, B },
                .{ B, B, B, B },
            },
            .Right => [4][4]PieceType{
                .{ B, B, I, B },
                .{ B, B, I, B },
                .{ B, B, I, B },
                .{ B, B, I, B },
            },
            .Spin => [4][4]PieceType{
                .{ B, B, B, B },
                .{ B, B, B, B },
                .{ I, I, I, I },
                .{ B, B, B, B },
            },
            .Left => [4][4]PieceType{
                .{ B, I, B, B },
                .{ B, I, B, B },
                .{ B, I, B, B },
                .{ B, I, B, B },
            },
        },
        O => switch (r) {
            .None => [4][4]PieceType{
                .{ O, O, B, B },
                .{ O, O, B, B },
                .{ B, B, B, B },
                .{ B, B, B, B },
            },
            .Right => [4][4]PieceType{
                .{ B, O, O, B },
                .{ B, O, O, B },
                .{ B, B, B, B },
                .{ B, B, B, B },
            },
            .Spin => [4][4]PieceType{
                .{ B, B, B, B },
                .{ B, O, O, B },
                .{ B, O, O, B },
                .{ B, B, B, B },
            },
            .Left => [4][4]PieceType{
                .{ B, B, B, B },
                .{ O, O, B, B },
                .{ O, O, B, B },
                .{ B, B, B, B },
            },
        },
        J => switch (r) {
            .None => [4][4]PieceType{
                .{ J, B, B, B },
                .{ J, J, J, B },
                .{ B, B, B, B },
                .{ B, B, B, B },
            },
            .Right => [4][4]PieceType{
                .{ B, J, J, B },
                .{ B, J, B, B },
                .{ B, J, B, B },
                .{ B, B, B, B },
            },
            .Spin => [4][4]PieceType{
                .{ B, B, B, B },
                .{ J, J, J, B },
                .{ B, B, J, B },
                .{ B, B, B, B },
            },
            .Left => [4][4]PieceType{
                .{ B, J, B, B },
                .{ B, J, B, B },
                .{ J, J, B, B },
                .{ B, B, B, B },
            },
        },
        L => switch (r) {
            .None => [4][4]PieceType{
                .{ B, B, L, B },
                .{ L, L, L, B },
                .{ B, B, B, B },
                .{ B, B, B, B },
            },
            .Right => [4][4]PieceType{
                .{ B, L, B, B },
                .{ B, L, B, B },
                .{ B, L, L, B },
                .{ B, B, B, B },
            },
            .Spin => [4][4]PieceType{
                .{ B, B, B, B },
                .{ L, L, L, B },
                .{ L, B, B, B },
                .{ B, B, B, B },
            },
            .Left => [4][4]PieceType{
                .{ L, L, B, B },
                .{ B, L, B, B },
                .{ B, L, B, B },
                .{ B, B, B, B },
            },
        },
        S => switch (r) {
            .None => [4][4]PieceType{
                .{ B, S, S, B },
                .{ S, S, B, B },
                .{ B, B, B, B },
                .{ B, B, B, B },
            },
            .Right => [4][4]PieceType{
                .{ B, S, B, B },
                .{ B, S, S, B },
                .{ B, B, S, B },
                .{ B, B, B, B },
            },
            .Spin => [4][4]PieceType{
                .{ B, B, B, B },
                .{ B, S, S, B },
                .{ S, S, B, B },
                .{ B, B, B, B },
            },
            .Left => [4][4]PieceType{
                .{ S, B, B, B },
                .{ S, S, B, B },
                .{ B, S, B, B },
                .{ B, B, B, B },
            },
        },
        Z => switch (r) {
            .None => [4][4]PieceType{
                .{ Z, Z, B, B },
                .{ B, Z, Z, B },
                .{ B, B, B, B },
                .{ B, B, B, B },
            },
            .Right => [4][4]PieceType{
                .{ B, B, Z, B },
                .{ B, Z, Z, B },
                .{ B, Z, B, B },
                .{ B, B, B, B },
            },
            .Spin => [4][4]PieceType{
                .{ B, B, B, B },
                .{ Z, Z, B, B },
                .{ B, Z, Z, B },
                .{ B, B, B, B },
            },
            .Left => [4][4]PieceType{
                .{ B, Z, B, B },
                .{ Z, Z, B, B },
                .{ Z, B, B, B },
                .{ B, B, B, B },
            },
        },
        T => switch (r) {
            .None => [4][4]PieceType{
                .{ B, T, B, B },
                .{ T, T, T, B },
                .{ B, B, B, B },
                .{ B, B, B, B },
            },
            .Right => [4][4]PieceType{
                .{ B, T, B, B },
                .{ B, T, T, B },
                .{ B, T, B, B },
                .{ B, B, B, B },
            },
            .Spin => [4][4]PieceType{
                .{ B, B, B, B },
                .{ T, T, T, B },
                .{ B, T, B, B },
                .{ B, B, B, B },
            },
            .Left => [4][4]PieceType{
                .{ B, T, B, B },
                .{ T, T, B, B },
                .{ B, T, B, B },
                .{ B, B, B, B },
            },
        },
        B => [4][4]PieceType{
            .{ B, B, B, B },
            .{ B, B, B, B },
            .{ B, B, B, B },
            .{ B, B, B, B },
        },
    };
}

const MinMaxRC = struct {
    min_row: i8,
    min_col: i8,
    max_row: i8,
    max_col: i8,

    // TODO verify that no code is generated from this function, just the
    // lookup table
    fn create_lookup_table() [PieceType.iter.len][Rotation.iter.len]MinMaxRC {
        comptime {
            @setEvalBranchQuota(2000);
            var lookup_table = [_][Rotation.iter.len]MinMaxRC{
                [_]MinMaxRC{
                    .{
                        .min_row = 3,
                        .min_col = 3,
                        .max_row = 0,
                        .max_col = 0,
                    },
                } ** Rotation.iter.len,
            } ** PieceType.iter.len;
            for (PieceType.iter) |ptype, ti| {
                for (Rotation.iter) |prot, ri| {
                    const d = generate_piece(ptype, prot);
                    const B = PieceType.None;

                    var min_row: u8 = 0;
                    var min_col: u8 = 0;
                    var max_row: u8 = 3;
                    var max_col: u8 = 3;

                    // 🐝 🐝 🐝 🐝
                    const bees = [4]PieceType{ B, B, B, B };

                    while (std.mem.eql(
                        PieceType,
                        &bees,
                        &[4]PieceType{
                            d[max_row][0],
                            d[max_row][1],
                            d[max_row][2],
                            d[max_row][3],
                        },
                    )) : (max_row -= 1) {}

                    while (std.mem.eql(
                        PieceType,
                        &bees,
                        &[4]PieceType{
                            d[min_row][0],
                            d[min_row][1],
                            d[min_row][2],
                            d[min_row][3],
                        },
                    )) : (min_row += 1) {}

                    while (std.mem.eql(
                        PieceType,
                        &bees,
                        &[4]PieceType{
                            d[0][max_col],
                            d[1][max_col],
                            d[2][max_col],
                            d[3][max_col],
                        },
                    )) : (max_col -= 1) {}

                    while (std.mem.eql(
                        PieceType,
                        &bees,
                        &[4]PieceType{
                            d[0][min_col],
                            d[1][min_col],
                            d[2][min_col],
                            d[3][min_col],
                        },
                    )) : (min_col += 1) {}

                    lookup_table[ti][ri] = MinMaxRC{
                        .min_row = @intCast(i8, min_row),
                        .min_col = @intCast(i8, min_col),
                        .max_row = @intCast(i8, max_row),
                        .max_col = @intCast(i8, max_col),
                    };
                }
            }
            return lookup_table;
        }
    }

    fn minmax_rowcol(t: PieceType, r: Rotation) MinMaxRC {
        const S = struct {
            const lookup_table = MinMaxRC.create_lookup_table();
        };

        const pi = t.iter_index();
        const ri = r.iter_index();
        return S.lookup_table[pi][ri];
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

// dummy placeholders, just call reset_game at the start
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
var current_style = Style.Solid;

fn collision() bool {
    const row = current_piece.row;
    const col = current_piece.col;
    const mmrc = MinMaxRC.minmax_rowcol(
        current_piece.type,
        current_piece.rotation,
    );

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

fn move_delta(delta: Delta) bool {
    const row = current_piece.row;
    const col = current_piece.col;
    current_piece.row += delta.row;
    current_piece.col += delta.col;
    if (collision()) {
        current_piece.row = row;
        current_piece.col = col;
        return false;
    }
    return true;
}

fn move_left() bool {
    return move_delta(Delta{ .row = 0, .col = -1 });
}

fn move_right() bool {
    return move_delta(Delta{ .row = 0, .col = 1 });
}

fn move_down() bool {
    return move_delta(Delta{ .row = 1, .col = 0 });
}

// :^)
fn move_up() bool {
    return move_delta(Delta{ .row = -1, .col = 0 });
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
        switch (current_style) {
            Style.Solid => {
                self.fill_rectangle(
                    BORDER + SIZE + x * (BORDER + SIZE),
                    BORDER + SIZE + y * (BORDER + SIZE),
                    SIZE,
                    SIZE,
                );
            },
            Style.Gridless => {
                self.fill_rectangle(
                    SIZE + x * (BORDER + SIZE),
                    SIZE + y * (BORDER + SIZE),
                    SIZE + BORDER,
                    SIZE + BORDER,
                );
            },
            Style.Edges => {
                const c = self.color;
                self.fill_rectangle(
                    BORDER + SIZE + x * (BORDER + SIZE),
                    BORDER + SIZE + y * (BORDER + SIZE),
                    SIZE,
                    SIZE,
                );
                self.set_color(current_colorscheme.bg_prim);
                self.fill_rectangle(
                    BORDER + SIZE + x * (BORDER + SIZE) + (SIZE >> 2),
                    BORDER + SIZE + y * (BORDER + SIZE) + (SIZE >> 2),
                    SIZE >> 1,
                    SIZE >> 1,
                );
                self.set_color(c);
            },
        }
    }

    pub fn draw_dot(self: *Self, x: usize, y: usize) void {
        self.fill_rectangle(x, y, BORDER, BORDER);
    }

    pub fn draw_lines_cleared(self: *Self, lines: u64) anyerror!void {
        const S = struct {
            var colorscheme: usize = undefined;
            var lines: u64 = 1 << 63;
            var text: *C.SDL_Texture = undefined;
            var rect: C.SDL_Rect = undefined;
        };
        if (lines == S.lines and S.colorscheme == current_colorscheme.index) {
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
        var col_offset = (BORDER + SIZE) * COLUMNS + 3 * SIZE;
        var row_offset = (BORDER + SIZE) * (ROWS - 6);
        _ = std.fmt.bufPrint(buf, "{any}", .{lines}) catch {};
        const c_string = buf;
        const c = current_colorscheme.fg_prim;
        const color = C.SDL_Color{
            .r = c.red,
            .g = c.green,
            .b = c.blue,
            .a = c.alpha,
        };
        var surface = C.TTF_RenderText_Blended(
            self.font,
            c_string,
            color,
        ) orelse {
            C.SDL_Log(
                "Unable to TTF_RenderText_Blended: %s",
                C.SDL_GetError(),
            );
            return error.SDLRenderFailed;
        };
        defer C.SDL_FreeSurface(surface);
        var text = C.SDL_CreateTextureFromSurface(
            self.renderer,
            surface,
        ) orelse {
            C.SDL_Log(
                "Unable to SDL_CreateTextureFromSurface: %s",
                C.SDL_GetError(),
            );
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
        if (S.text != undefined) {
            C.SDL_DestroyTexture(S.text);
        }
        S.colorscheme = current_colorscheme.index;
        S.lines = lines;
        S.text = text;
        S.rect = r;
    }

    pub fn draw_time_passed(self: *Self, time: u64) anyerror!void {
        const S = struct {
            var colorscheme: usize = undefined;
            var time: u64 = 1 << 63;
            var text: *C.SDL_Texture = undefined;
            var rect: C.SDL_Rect = undefined;
        };
        if (time == S.time and S.colorscheme == current_colorscheme.index) {
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
        var col_offset = (BORDER + SIZE) * COLUMNS + 3 * SIZE;
        var row_offset = (BORDER + SIZE) * (ROWS - 4);
        _ = std.fmt.bufPrint(buf, "{any}", .{time}) catch {};
        const c_string = buf;
        const c = current_colorscheme.fg_prim;
        const color = C.SDL_Color{
            .r = c.red,
            .g = c.green,
            .b = c.blue,
            .a = c.alpha,
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
        if (S.text != undefined) {
            C.SDL_DestroyTexture(S.text);
        }
        S.colorscheme = current_colorscheme.index;
        S.time = time;
        S.text = text;
        S.rect = r;
    }

    pub fn draw_grid(self: *Self) void {
        // basically the outline
        self.set_color(current_colorscheme.fg_prim);
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
        const timestamp: f64 = @intToFloat(
            f64,
            std.time.milliTimestamp(),
        ) / 1e3;
        const ratio = 0.4 * @fabs(@sin(3.141592 * timestamp));
        const piece_color = Color.merge(
            current_colorscheme.from_piecetype(p),
            current_colorscheme.bg_seco,
            ratio,
        );
        self.set_color(piece_color);
        self.draw_tetromino(col, row, p, r);
    }

    pub fn draw_tetromino(
        self: *Self,
        col: i8,
        row: i8,
        p: PieceType,
        r: Rotation,
    ) void {
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

        if (self.single(C.SDL_SCANCODE_1)) {
            current_style = Style.iter[0];
        }

        if (self.single(C.SDL_SCANCODE_2)) {
            current_style = Style.iter[1];
        }

        if (self.single(C.SDL_SCANCODE_3)) {
            current_style = Style.iter[2];
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
        C.SDL_WINDOW_OPENGL | C.SDL_WINDOW_RESIZABLE,
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
    xoshiro = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp()));
    rngesus = xoshiro.random();
    reset_game();

    var last_frame_drawn = try std.time.Timer.start();

    var quit = false;
    while (!quit) {
        quit = k.handle_input(&r);

        if (last_frame_drawn.read() > TARGET_FPS_DELAY) {
            last_frame_drawn.reset();
            // keep abstracting every bit of rendering
            r.set_color(current_colorscheme.bg_prim);
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

            r.set_color(current_colorscheme.from_piecetype(current_piece.type));
            r.draw_tetromino(
                current_piece.col,
                current_piece.row,
                current_piece.type,
                current_piece.rotation,
            );

            for (current_queue) |p, dr| {
                const row_offset = @intCast(i8, 1 + 3 * dr);
                r.set_color(current_colorscheme.from_piecetype(p));
                r.draw_tetromino(
                    COLUMNS + 2,
                    row_offset,
                    p,
                    Rotation.None,
                );
            }

            r.set_color(current_colorscheme.from_piecetype(current_holding));
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

// waiting for any specific piece will take at most 6 + 6 pieces
// for example, you just got an I, and you get all other pieces twice first
// [I] : [J L O S T Z] : [J L O S T Z] : [I]
test "piecetypes are satisfyingly random" {
    xoshiro = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp()));
    rngesus = xoshiro.random();
    var seen: [PieceType.iter.len]u8 = .{0} ** PieceType.iter.len;

    // first round
    var take: usize = 0;
    while (take < PieceType.iter.len) : (take += 1) {
        const t = PieceType.random();
        const i = PieceType.iter_index(t);
        seen[i] += 1;
    }

    for (seen) |b| {
        try std.testing.expect(b == 1);
    }

    // second round
    take = 0;
    while (take < PieceType.iter.len) : (take += 1) {
        const t = PieceType.random();
        const i = PieceType.iter_index(t);
        seen[i] += 1;
    }

    for (seen) |b| {
        try std.testing.expect(b == 2);
    }
}
