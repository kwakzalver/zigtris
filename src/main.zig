const C = @cImport({
    @cInclude("SDL2/SDL.h");
    @cInclude("SDL2/SDL_ttf.h");
});

const std = @import("std");

// feature flags, enable or disable at will
const ENABLE_RENDER_TIME = false;
const ENABLE_GRAVITY = false;
const GRAVITY_DELAY = 700 * std.time.ns_per_ms;
const ENABLE_BOT_DELAY = false;
const BOT_DELAY = 50 * std.time.ns_per_ms;

// beautiful idiomatic global state
const G = struct {
    var xoshiro: std.rand.Xoshiro256 = undefined;
    var rngesus: std.rand.Random = undefined;

    var SIZE: usize = 42;
    var BORDER: usize = 1;
    var BSIZE: usize = 43;

    var Grid = [1][COLUMNS]PieceType{
        .{PieceType.None} ** COLUMNS,
    } ** ROWS;

    var game_timer: std.time.Timer = undefined;

    // dummy placeholders
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

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var stack = std.ArrayList(Piece).init(allocator);

    var lines_cleared: u64 = 0;
    var pieces_locked: u64 = 0;
    var sprint_time: u64 = undefined;
    var sprint_finished: bool = false;
    var current_colorscheme = Colorscheme.habamax();
    var current_style = Style.Solid;
    var zigtris_bot = false;

    var optimal_move: Piece = undefined;
    var optimal_score: i32 = undefined;

    var moves = std.ArrayList(Piece).init(G.allocator);
};

const FONT_BYTES = @embedFile("../assets/font.ttf");

// aspect ratio for width : height
const RATIO_WIDTH: usize = 18;
const RATIO_HEIGHT: usize = 22;

const TARGET_FPS = 60;
const TARGET_FPS_DELAY = @divFloor(1000, TARGET_FPS) * std.time.ns_per_ms;

const Color = struct {
    red: u8,
    green: u8,
    blue: u8,

    pub fn from_u24(rgb: u24) Color {
        return Color{
            .red = @intCast(u8, (rgb >> 16) & 0xff),
            .green = @intCast(u8, (rgb >> 8) & 0xff),
            .blue = @intCast(u8, (rgb >> 0) & 0xff),
        };
    }

    pub fn combine(lhs: Color, rhs: Color, l: u8) Color {
        const r: u8 = (100 - l);
        const lr = @intCast(u16, lhs.red);
        const lg = @intCast(u16, lhs.green);
        const lb = @intCast(u16, lhs.blue);
        const rr = @intCast(u16, rhs.red);
        const rg = @intCast(u16, rhs.green);
        const rb = @intCast(u16, rhs.blue);

        return Color{
            .red = @intCast(u8, @divFloor(lr * l + rr * r, 100)),
            .green = @intCast(u8, @divFloor(lg * l + rg * r, 100)),
            .blue = @intCast(u8, @divFloor(lb * l + rb * r, 100)),
        };
    }
};

const Rotation = enum(u2) {
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

    fn iter_index(s: Self) usize {
        return @enumToInt(s);
    }
};

const PieceType = enum(u3) {
    const Self = @This();
    I,
    O,
    J,
    L,
    S,
    Z,
    T,
    None,

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
            G.rngesus.shuffle(PieceType, S.types[0..]);
        }
        const t = S.types[S.index];
        S.index = (S.index + 1) % S.types.len;
        return t;
    }

    // IMPORTANT make sure to not use this `iter_index` when PieceType.None
    pub fn iter_index(s: Self) usize {
        return @enumToInt(s);
    }
};

const Colorname = enum(u3) {
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

    pub fn iter_index(s: Self) usize {
        return @enumToInt(s);
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

    fn create_lookup_table() [PieceType.iter.len][Rotation.iter.len]MinMaxRC {
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
};

// the game (you just lost)
const ROWS: u8 = 20;
const COLUMNS: u8 = 10;

fn collision() bool {
    const row = G.current_piece.row;
    const col = G.current_piece.col;
    const mmrc = MinMaxRC.minmax_rowcol(
        G.current_piece.type,
        G.current_piece.rotation,
    );

    if (col + mmrc.min_col < 0 or col + mmrc.max_col >= COLUMNS) {
        return true;
    }

    if (row + mmrc.min_row < 0 or row + mmrc.max_row >= ROWS) {
        return true;
    }

    // collision with pieces on the grid?
    const B = PieceType.None;
    const data = generate_piece(
        G.current_piece.type,
        G.current_piece.rotation,
    );
    for (data) |drow, dr| {
        for (drow) |e, dc| {
            if (e != B) {
                const c = @intCast(usize, col + @intCast(i8, dc));
                const r = @intCast(usize, row + @intCast(i8, dr));
                if (G.Grid[r][c] != B) {
                    return true;
                }
            }
        }
    }

    return false;
}

fn move_delta(delta: Delta) bool {
    const row = G.current_piece.row;
    const col = G.current_piece.col;
    G.current_piece.row += delta.row;
    G.current_piece.col += delta.col;
    if (collision()) {
        G.current_piece.row = row;
        G.current_piece.col = col;
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
    const data = generate_piece(
        G.current_piece.type,
        G.current_piece.rotation,
    );
    const col = G.current_piece.col;
    const row = G.current_piece.row;
    for (data) |drow, dr| {
        for (drow) |e, dc| {
            if (e != PieceType.None) {
                const c = @intCast(usize, col + @intCast(i8, dc));
                const r = @intCast(usize, row + @intCast(i8, dr));
                G.Grid[r][c] = e;
            }
        }
    }
}

fn push() void {
    G.stack.append(G.current_piece) catch unreachable;
    const data = generate_piece(
        G.current_piece.type,
        G.current_piece.rotation,
    );
    const col = G.current_piece.col;
    const row = G.current_piece.row;
    for (data) |drow, dr| {
        for (drow) |e, dc| {
            if (e != PieceType.None) {
                const c = @intCast(usize, col + @intCast(i8, dc));
                const r = @intCast(usize, row + @intCast(i8, dr));
                G.Grid[r][c] = e;
            }
        }
    }

    // shift queue
    G.current_piece = Piece.from_piecetype(G.current_queue[0]);
    G.current_queue[0] = G.current_queue[1];
    G.current_queue[1] = G.current_queue[2];
    G.current_queue[2] = G.current_queue[3];
}

fn pop() void {
    if (G.stack.items.len == 0) {
        unreachable;
    }
    const piece = G.stack.pop();
    const data = generate_piece(piece.type, piece.rotation);
    const B = PieceType.None;
    const col = piece.col;
    const row = piece.row;
    for (data) |drow, dr| {
        for (drow) |e, dc| {
            if (e != PieceType.None) {
                const c = @intCast(usize, col + @intCast(i8, dc));
                const r = @intCast(usize, row + @intCast(i8, dr));
                G.Grid[r][c] = B;
            }
        }
    }

    // unshift queue
    G.current_queue[3] = G.current_queue[2];
    G.current_queue[2] = G.current_queue[1];
    G.current_queue[1] = G.current_queue[0];
    G.current_queue[0] = G.current_piece.type;
    G.current_piece = piece;
}

fn next_piece() void {
    G.current_piece = Piece.from_piecetype(G.current_queue[0]);
    G.current_queue[0] = G.current_queue[1];
    G.current_queue[1] = G.current_queue[2];
    G.current_queue[2] = G.current_queue[3];
    G.current_queue[3] = PieceType.random();
    if (collision()) {
        // game over!
        reset_game();
    }
}

fn hold_piece() void {
    const t = G.current_piece.type;
    G.current_piece = Piece.from_piecetype(G.current_holding);
    G.current_holding = t;
}

fn clear_grid() void {
    for (G.Grid) |Row, r| {
        for (Row) |_, c| {
            G.Grid[r][c] = PieceType.None;
        }
    }
}

fn reset_game() void {
    clear_grid();

    G.pieces_locked = 0;
    G.lines_cleared = 0;

    G.current_piece = Piece.from_piecetype(PieceType.random());
    G.current_holding = PieceType.random();
    G.current_queue[0] = PieceType.random();
    G.current_queue[1] = PieceType.random();
    G.current_queue[2] = PieceType.random();
    G.current_queue[3] = PieceType.random();

    G.stack.shrinkRetainingCapacity(0);

    G.game_timer.reset();

    G.sprint_time = undefined;
    G.sprint_finished = false;
}

fn piece_lock() void {
    materialize();
    G.pieces_locked += 1;
    G.lines_cleared += clear_lines();
    next_piece();
}

fn ghost_drop() i8 {
    const backup_row = G.current_piece.row;
    while (move_down()) {}
    const ghost_row = G.current_piece.row;
    G.current_piece.row = backup_row;
    return ghost_row;
}

fn hard_drop() void {
    while (move_down()) {}
    piece_lock();
}

fn hard_drop_no_lock() void {
    while (move_down()) {}
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

    const col = G.current_piece.col;
    const row = G.current_piece.row;
    for (S.deltas) |delta| {
        G.current_piece.col += delta.col;
        G.current_piece.row += delta.row;
        if (!collision()) {
            return true;
        }
        G.current_piece.col = col;
        G.current_piece.row = row;
    }
    return false;
}

fn rotate_right() void {
    const r = G.current_piece.rotation;
    G.current_piece.rotation = r.rotate_right();
    if (!unstuck()) {
        G.current_piece.rotation = r;
    }
}

fn rotate_left() void {
    const r = G.current_piece.rotation;
    G.current_piece.rotation = r.rotate_left();
    if (!unstuck()) {
        G.current_piece.rotation = r;
    }
}

fn rotate_spin() void {
    const r = G.current_piece.rotation;
    G.current_piece.rotation = r.rotate_spin();
    if (!unstuck()) {
        G.current_piece.rotation = r;
    }
}

fn clear_lines() u8 {
    var cleared: u8 = 0;
    var r: u8 = ROWS - 1;
    while (r != 0) {
        var clear: bool = true;
        var c: u8 = 0;
        while (clear and c != COLUMNS) : (c += 1) {
            clear = clear and G.Grid[r][c] != PieceType.None;
        }
        if (clear) {
            var up: u8 = r - 1;
            while (up != 0) {
                c = 0;
                while (c != COLUMNS) : (c += 1) {
                    G.Grid[up + 1][c] = G.Grid[up][c];
                }
                up -= 1;
            }
            // when up == 0
            c = 0;
            while (c != COLUMNS) : (c += 1) {
                G.Grid[up + 1][c] = G.Grid[up][c];
                G.Grid[up][c] = PieceType.None;
            }
            cleared += 1;
        } else {
            r -= 1;
        }
    }
    return cleared;
}

fn find_row_start() u8 {
    var r: u8 = 0;
    while (r != ROWS) : (r += 1) {
        var c: u8 = 0;
        while (c != COLUMNS) : (c += 1) {
            if (G.Grid[r][c] != PieceType.None) {
                return r;
            }
        }
    }
    return ROWS - 1;
}

const Metrics = struct {
    holes: u8,
    deepest: u8,
    background: u8,
};

fn compute_metrics(row_start: u8) Metrics {
    const B = PieceType.None;
    var holes: u8 = 0;
    var deepest: u8 = 0;
    var background: u8 = 0;

    var c: u8 = 0;
    while (c != COLUMNS) : (c += 1) {
        var r: u8 = row_start;
        while (r != ROWS and G.Grid[r][c] == B) : (r += 1) {
            background += 1;
            deepest = std.math.max(deepest, r);
        }
        while (r != ROWS) : (r += 1) {
            if (G.Grid[r][c] == B) {
                holes += 1;
            }
        }
    }

    return Metrics{
        .holes = holes,
        .deepest = deepest,
        .background = background,
    };
}

fn compute_score(placed: Piece) i32 {
    const row_start = find_row_start();
    const metrics = compute_metrics(row_start);
    const grid_height = @intCast(i8, ROWS - row_start);
    const piece_placement = @intCast(i8, ROWS) - placed.row;
    const piece_orientation: i8 = switch (placed.rotation) {
        .Right, .Left => 1,
        else => 0,
    };

    var badness: i32 = 0;
    // holes are the absolute worst, avoid
    badness = (badness + metrics.holes) * 8;
    // try to keep the structure as flat as possible
    badness = (badness + metrics.background) * 2;
    // some other trivia
    badness = (badness + piece_placement) * 2;
    badness = (badness + metrics.deepest) * 2;
    badness = (badness + std.math.pow(i32, 2, grid_height)) * 2;
    badness = (badness + piece_orientation) * 2;

    return badness;
}

fn try_move(badness: i32) void {
    hard_drop_no_lock();
    G.moves.append(G.current_piece) catch unreachable;
    push();
    const b = compute_score(G.current_piece);
    least_bad_moves(@divFloor(badness + b, 2));
    pop();
    _ = G.moves.pop();
}

// TODO can we just use slices instead? ArrayList seems wasteful
var rotations = std.ArrayList(Rotation).init(G.allocator);

fn least_bad_moves(badness: i32) void {
    // early pruning for faster evaluation
    if (badness > G.optimal_score) {
        return;
    }

    if (G.moves.items.len == 5) {
        if (badness < G.optimal_score) {
            // the first move in this sequence of moves, is the optimal one
            G.optimal_move = G.moves.items[0];
            G.optimal_score = badness;
        }
        return;
    }

    // only consider meaningful rotations
    rotations.shrinkRetainingCapacity(0);
    switch (G.current_piece.type) {
        .J, .L, .T => {
            rotations.appendSlice(&[_]Rotation{
                .None,
                .Right,
                .Spin,
                .Left,
            }) catch unreachable;
        },
        .I, .S, .Z => {
            rotations.appendSlice(&[_]Rotation{
                .None,
                .Right,
            }) catch unreachable;
        },
        .O => {
            rotations.appendSlice(&[_]Rotation{
                .None,
            }) catch unreachable;
        },
        else => unreachable,
    }

    const current_piece_backup = G.current_piece;

    for (rotations.items) |rot| {
        G.current_piece.rotation = rot;
        try_move(badness);
        G.current_piece.row = current_piece_backup.row;
        while (move_left()) {
            try_move(badness);
            G.current_piece.row = current_piece_backup.row;
        }
        G.current_piece.col = current_piece_backup.col;
        while (move_right()) {
            try_move(badness);
            G.current_piece.row = current_piece_backup.row;
        }
    }
}

fn set_optimal_move() void {
    const S = struct {
        var last_pieces_locked: u64 = 1337;
        var last_piecetype: PieceType = .None;
        var last_holding: PieceType = .None;
    };

    if (G.pieces_locked == S.last_pieces_locked) {
        const lt = S.last_piecetype;
        const lh = S.last_holding;
        const ct = G.current_piece.type;
        const ch = G.current_holding;
        if ((lt == ct and lh == ch) or (lt == ch and lh == ct)) {
            return;
        }
    }

    G.optimal_move = G.current_piece;
    G.optimal_score = 2147483647;
    S.last_pieces_locked = G.pieces_locked;
    S.last_piecetype = G.current_piece.type;
    S.last_holding = G.current_holding;

    least_bad_moves(0);
    hold_piece();
    least_bad_moves(0);
    hold_piece();
}

fn fully_automatic() void {
    set_optimal_move();
    if (comptime ENABLE_BOT_DELAY) {
        const S = struct {
            var last_time: u64 = 0;
        };
        const time_passed = G.game_timer.read();
        if (time_passed <= BOT_DELAY) {
            // reset when game timer has been reset
            S.last_time = time_passed;
        }
        const ok = (time_passed - S.last_time) >= BOT_DELAY;

        if (G.optimal_move.type != G.current_piece.type and ok) {
            hold_piece();
            S.last_time = time_passed;
            return;
        }
        if (G.current_piece.rotation != G.optimal_move.rotation and ok) {
            G.current_piece.rotation = G.optimal_move.rotation;
            S.last_time = time_passed;
            return;
        }
        if (G.current_piece.col < G.optimal_move.col and ok and move_right()) {
            S.last_time = time_passed;
            return;
        }
        if (G.current_piece.col > G.optimal_move.col and ok and move_left()) {
            S.last_time = time_passed;
            return;
        }
        if (ok) {
            hard_drop();
            S.last_time = time_passed;
            return;
        }
    } else {
        if (G.optimal_move.type != G.current_piece.type) {
            hold_piece();
        }
        G.current_piece.rotation = G.optimal_move.rotation;
        while (G.current_piece.col < G.optimal_move.col and move_right()) {}
        while (G.current_piece.col > G.optimal_move.col and move_left()) {}
        hard_drop();
    }
}

// simple SDL renderer wrapper
const Renderer = struct {
    const Self = @This();
    renderer: ?*C.SDL_Renderer = null,
    color: Color = undefined,
    font: ?*C.TTF_Font = null,
    force_redraw: u8 = 0,

    pub fn set_color(self: *Self, c: Color) void {
        self.color = c;
        _ = C.SDL_SetRenderDrawColor(
            self.renderer,
            c.red,
            c.green,
            c.blue,
            0xff,
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
        _ = C.SDL_RenderFillRect(self.renderer, &rectangle);
    }

    pub fn fill_square(self: *Self, x: usize, y: usize) void {
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
                    G.SIZE + x * G.BSIZE,
                    G.SIZE + y * G.BSIZE,
                    G.BSIZE,
                    G.BSIZE,
                );
            },
            Style.Edges => {
                const c = self.color;
                self.fill_rectangle(
                    G.BSIZE + x * G.BSIZE,
                    G.BSIZE + y * G.BSIZE,
                    G.SIZE,
                    G.SIZE,
                );
                self.set_color(G.current_colorscheme.bg_prim);
                self.fill_rectangle(
                    G.BSIZE + x * G.BSIZE + (G.SIZE >> 2),
                    G.BSIZE + y * G.BSIZE + (G.SIZE >> 2),
                    G.SIZE >> 1,
                    G.SIZE >> 1,
                );
                self.set_color(c);
            },
        }
    }

    pub fn draw_dot(self: *Self, x: usize, y: usize) void {
        self.fill_rectangle(x, y, G.BORDER, G.BORDER);
    }

    pub fn draw_lines_cleared(self: *Self, lines: u64) anyerror!void {
        const S = struct {
            var colorscheme: usize = undefined;
            var lines: u64 = 1 << 63;
            var text: ?*C.SDL_Texture = null;
            var rect: C.SDL_Rect = undefined;
        };
        if (lines == S.lines and S.colorscheme == G.current_colorscheme.index) {
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
        var col_offset = G.BSIZE * COLUMNS + 3 * G.SIZE;
        var row_offset = G.BSIZE * (ROWS - 6);
        _ = std.fmt.bufPrint(buf, "{any}", .{lines}) catch unreachable;
        const c_string = buf;
        const c = G.current_colorscheme.fg_prim;
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
        S.colorscheme = G.current_colorscheme.index;
        S.lines = lines;
        S.text = text;
        S.rect = r;
    }

    pub fn draw_time_passed(
        self: *Self,
        time: u64,
        highlight: bool,
    ) anyerror!void {
        const S = struct {
            var colorscheme: usize = undefined;
            var time: u64 = 1 << 63;
            var text: ?*C.SDL_Texture = null;
            var rect: C.SDL_Rect = undefined;
        };
        if (time == S.time and S.colorscheme == G.current_colorscheme.index) {
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
        var col_offset = G.BSIZE * COLUMNS + 3 * G.SIZE;
        var row_offset = G.BSIZE * (ROWS - 4);
        _ = std.fmt.bufPrint(buf, "{any}", .{time}) catch unreachable;
        const c_string = buf;
        const c = switch (highlight) {
            false => G.current_colorscheme.fg_prim,
            true => G.current_colorscheme.piece_T,
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
        S.colorscheme = G.current_colorscheme.index;
        S.time = time;
        S.text = text;
        S.rect = r;
    }

    pub fn draw_frame_render_time(self: *Self, time: u64) anyerror!void {
        const S = struct {
            var colorscheme: usize = undefined;
            var time: u64 = 1 << 63;
            var text: ?*C.SDL_Texture = null;
            var rect: C.SDL_Rect = undefined;
        };
        if (time == S.time and S.colorscheme == G.current_colorscheme.index) {
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
        _ = std.fmt.bufPrint(buf, "{any} ms", .{time}) catch unreachable;
        const c_string = buf;
        const c = G.current_colorscheme.piece_O;
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
        S.colorscheme = G.current_colorscheme.index;
        S.time = time;
        S.text = text;
        S.rect = r;
    }

    pub fn draw_grid(self: *Self) void {
        // basically the outline
        self.set_color(G.current_colorscheme.fg_prim);
        self.fill_rectangle(
            G.SIZE,
            G.SIZE,
            COLUMNS * G.BSIZE + G.BORDER,
            ROWS * G.BSIZE + G.BORDER,
        );

        var r: u64 = 0;
        while (r != ROWS) : (r += 1) {
            var c: u64 = 0;
            while (c != COLUMNS) : (c += 1) {
                const t = G.Grid[r][c];
                const color = G.current_colorscheme.from_piecetype(t);
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
        const ratio: u8 = @floatToInt(
            u8,
            40 * @fabs(@sin(3.141592 * timestamp)),
        );
        const piece_color = Color.combine(
            G.current_colorscheme.from_piecetype(p),
            G.current_colorscheme.bg_seco,
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
    // assuming 60 fps: 7 frames before repeat kicks in -> feels great to me.
    var initial_delay: u64 = 112 * std.time.ns_per_ms;
    // this basically means instant transmission
    var repeat_delay: u64 = 0 * std.time.ns_per_ms;
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
                            // we resize based on the smaller dimension, but
                            // keep the width : height ratio into account
                            const width = @divFloor(
                                event.window.data1 * RATIO_HEIGHT,
                                RATIO_WIDTH,
                            );
                            const height = event.window.data2;
                            const dimension = std.math.min(width, height);
                            G.SIZE = @intCast(usize, @divFloor(
                                dimension - @intCast(
                                    i32,
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
            G.current_colorscheme = G.current_colorscheme.next();
        }

        if (self.single(C.SDL_SCANCODE_BACKSPACE)) {
            G.current_colorscheme = G.current_colorscheme.previous();
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

        if (self.single(C.SDL_SCANCODE_R)) {
            _ = reset_game();
        }

        if (G.zigtris_bot) {
            fully_automatic();
            return false;
        }

        // Player controls start here.

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

        if (self.repeats(C.SDL_SCANCODE_DOWN, 0)) {
            _ = move_down();
        }

        if (self.repeats(C.SDL_SCANCODE_LEFT, repeat_delay)) {
            _ = move_left();
        }

        if (self.repeats(C.SDL_SCANCODE_RIGHT, repeat_delay)) {
            _ = move_right();
        }

        if (self.single(C.SDL_SCANCODE_SPACE)) {
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

fn sdl2_game() anyerror!void {
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
    reset_game();

    var last_frame_drawn = try std.time.Timer.start();
    // NOTE unused variable if comptime ENABLE_RENDER_TIME not true
    var render_time = last_frame_drawn.read() / std.time.ns_per_ms;

    var quit = false;
    while (!quit) {
        quit = k.handle_input(&r);

        if (comptime ENABLE_GRAVITY) {
            const gravity_tick = gravity_timer.read() >= GRAVITY_DELAY;
            if (gravity_tick) {
                if (!move_down()) {
                    piece_lock();
                }
                gravity_timer.reset();
            }
        }

        if (last_frame_drawn.read() >= TARGET_FPS_DELAY) {
            last_frame_drawn.reset();
            // keep abstracting every bit of rendering
            r.set_color(G.current_colorscheme.bg_prim);
            r.clear();

            r.draw_grid();

            const ghost_row = ghost_drop();
            r.draw_ghost(
                G.current_piece.col,
                ghost_row,
                G.current_piece.type,
                G.current_piece.rotation,
            );

            const ratio: u8 = 50;
            const piece_color = Color.combine(
                G.current_colorscheme.from_piecetype(G.current_piece.type),
                G.current_colorscheme.fg_prim,
                ratio,
            );
            r.set_color(piece_color);
            r.draw_tetromino(
                G.current_piece.col,
                G.current_piece.row,
                G.current_piece.type,
                G.current_piece.rotation,
            );

            const col_offset = COLUMNS + 2;
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
                r.draw_frame_render_time(render_time) catch unreachable;
            }

            r.show();

            if (comptime ENABLE_RENDER_TIME) {
                render_time = last_frame_drawn.read() / std.time.ns_per_ms;
            }
        }
    }

    // free up stuff
    C.TTF_CloseFont(r.font);
}

pub fn main() anyerror!void {
    sdl2_game() catch unreachable;
}

// rigorous testing :^)
test "clear lines" {
    var c: u8 = 0;
    while (c != COLUMNS) : (c += 1) {
        G.Grid[19][c] = PieceType.I;
        G.Grid[18][c] = PieceType.I;
        G.Grid[17][c] = PieceType.I;
        G.Grid[16][c] = PieceType.I;
    }
    const cleared = clear_lines();
    try std.testing.expectEqual(cleared, 4);
}

// waiting for any specific piece will take at most 6 + 6 pieces
// for example, you just got an I, and you get all other pieces twice first
// [I] : [J L O S T Z] : [J L O S T Z] : [I]
test "piecetypes are satisfyingly random" {
    G.xoshiro = std.rand.DefaultPrng.init(@intCast(
        u64,
        std.time.milliTimestamp(),
    ));
    G.rngesus = G.xoshiro.random();
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
