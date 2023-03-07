const std = @import("std");

pub const Delta = struct {
    row: i8 = 0,
    col: i8 = 0,
};

pub const Metrics = struct {
    holes: u8,
    deepest: u8,
    background: u8,
};

pub const Color = struct {
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
        const r: u8 = (128 - l);
        const lr = @intCast(u16, lhs.red);
        const lg = @intCast(u16, lhs.green);
        const lb = @intCast(u16, lhs.blue);
        const rr = @intCast(u16, rhs.red);
        const rg = @intCast(u16, rhs.green);
        const rb = @intCast(u16, rhs.blue);

        return Color{
            .red = @intCast(u8, @divFloor(lr * l + rr * r, 128)),
            .green = @intCast(u8, @divFloor(lg * l + rg * r, 128)),
            .blue = @intCast(u8, @divFloor(lb * l + rb * r, 128)),
        };
    }
};

pub const Colorname = enum(u3) {
    const Self = @This();
    habamax,
    gruvbox_dark,
    gruvbox_light,
    onedark,
    macchiato,

    pub const iter = iterable_enum(Self);

    pub fn iter_index(s: Self) usize {
        return @enumToInt(s);
    }
};

pub const Colorscheme = struct {
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

pub const Style = enum {
    const Self = @This();
    Solid,
    Gridless,
    Edges,

    pub const iter = iterable_enum(Self);
};

pub const Rotation = enum(u2) {
    const Self = @This();
    None,
    Right,
    Spin,
    Left,

    pub fn rotate_right(self: Rotation) Rotation {
        return switch (self) {
            Rotation.None => Rotation.Right,
            Rotation.Right => Rotation.Spin,
            Rotation.Spin => Rotation.Left,
            Rotation.Left => Rotation.None,
        };
        // TODO would this be preferable?
        // return @intToEnum(Rotation, @enumToInt(self) +% 1);
    }

    pub fn rotate_left(self: Rotation) Rotation {
        return switch (self) {
            Rotation.None => Rotation.Left,
            Rotation.Right => Rotation.None,
            Rotation.Spin => Rotation.Right,
            Rotation.Left => Rotation.Spin,
        };
        // TODO would this be preferable?
        // return @intToEnum(Rotation, @enumToInt(self) -% 1);
    }

    pub fn rotate_spin(self: Rotation) Rotation {
        return switch (self) {
            Rotation.None => Rotation.Spin,
            Rotation.Right => Rotation.Left,
            Rotation.Spin => Rotation.None,
            Rotation.Left => Rotation.Right,
        };
        // TODO would this be preferable?
        // return @intToEnum(Rotation, @enumToInt(self) +% 1);
    }

    pub const iter = iterable_enum(Self);

    pub fn iter_index(s: Self) usize {
        return @enumToInt(s);
    }
};

pub const PieceType = enum(u3) {
    const Self = @This();
    I,
    O,
    J,
    L,
    S,
    Z,
    T,
    None,

    // exception to the rule
    pub const iter = [7]PieceType{
        PieceType.I,
        PieceType.O,
        PieceType.J,
        PieceType.L,
        PieceType.S,
        PieceType.Z,
        PieceType.T,
    };

    // IMPORTANT make sure to not use this `iter_index` when PieceType.None
    pub fn iter_index(s: Self) usize {
        return if (comptime s != PieceType.None)
            @enumToInt(s)
        else
            unreachable;
    }

    pub fn piecetype_rotation_matrix(
        t: PieceType,
        r: Rotation,
    ) [4][4]PieceType {
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
};

pub const MinMaxRC = struct {
    min_row: i8,
    min_col: i8,
    max_row: i8,
    max_col: i8,

    fn create_lookup_table() [PieceType.iter.len][Rotation.iter.len]MinMaxRC {
        @setEvalBranchQuota(2000);
        var lookup_table: [PieceType.iter.len][Rotation.iter.len]MinMaxRC =
            undefined;
        for (PieceType.iter) |ptype, ti| {
            for (Rotation.iter) |prot, ri| {
                const d = PieceType.piecetype_rotation_matrix(ptype, prot);
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

    pub fn minmax_rowcol(t: PieceType, r: Rotation) MinMaxRC {
        const S = struct {
            const lookup_table = MinMaxRC.create_lookup_table();
        };

        const pi = t.iter_index();
        const ri = r.iter_index();
        return S.lookup_table[pi][ri];
    }
};

pub const Piece = struct {
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

// cute little trick to generate `.iter` for enums
fn iterable_enum(comptime T: type) [@typeInfo(T).Enum.fields.len]T {
    var result: [@typeInfo(T).Enum.fields.len]T = undefined;
    inline for (@typeInfo(T).Enum.fields) |e, i| {
        result[i] = @intToEnum(T, e.value);
    }
    return result;
}

test "iterable_enum works as expected" {
    const Fruits = enum {
        const Self = @This();
        apple,
        banana,
        cherry,
        const iter = iterable_enum(Self);
    };

    try std.testing.expect(
        std.mem.eql(Fruits, &Fruits.iter, &[_]Fruits{
            Fruits.apple,
            Fruits.banana,
            Fruits.cherry,
        }),
    );
}
