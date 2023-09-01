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
            .red = @as(u8, @intCast((rgb >> 16) & 0xff)),
            .green = @as(u8, @intCast((rgb >> 8) & 0xff)),
            .blue = @as(u8, @intCast((rgb >> 0) & 0xff)),
        };
    }

    pub fn combine(lhs: Color, rhs: Color, l: u8) Color {
        const r: u8 = (128 - l);
        const lr = @as(u16, @intCast(lhs.red));
        const lg = @as(u16, @intCast(lhs.green));
        const lb = @as(u16, @intCast(lhs.blue));
        const rr = @as(u16, @intCast(rhs.red));
        const rg = @as(u16, @intCast(rhs.green));
        const rb = @as(u16, @intCast(rhs.blue));

        return Color{
            .red = @as(u8, @intCast(@divFloor(lr * l + rr * r, 128))),
            .green = @as(u8, @intCast(@divFloor(lg * l + rg * r, 128))),
            .blue = @as(u8, @intCast(@divFloor(lb * l + rb * r, 128))),
        };
    }
};

pub const Colorname = enum(u3) {
    const Self = @This();
    habamax,
    habamin,
    gruvbox_dark,
    gruvbox_light,
    onedark,
    onelight,
    pastel_dark,
    pastel_light,

    pub const iter = iterable_enum(Self);

    pub fn iter_index(s: Self) usize {
        return @intFromEnum(s);
    }

    pub fn next(s: Self) Colorname {
        return Colorname.iter[(@intFromEnum(s) + 1) % Colorname.iter.len];
    }

    pub fn previous(s: Self) Colorname {
        return Colorname.iter[(@intFromEnum(s) - 1) % Colorname.iter.len];
    }
};

const Palette = struct {
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

    fn habamax() Palette {
        return Palette{
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

    fn habamin() Palette {
        return Palette{
            .fg_prim = Color.from_u24(0x1C1C1C), // #1C1C1C
            .fg_seco = Color.from_u24(0x454545), // #454545
            .bg_seco = Color.from_u24(0x898989), // #898989
            .bg_prim = Color.from_u24(0xBCBCBC), // #BCBCBC
            .piece_I = Color.from_u24(0xD75F5F), // #D75F5F
            .piece_J = Color.from_u24(0xBC796C), // #BC796C
            .piece_L = Color.from_u24(0xA19379), // #A19379
            .piece_O = Color.from_u24(0x87AF87), // #87AF87
            .piece_S = Color.from_u24(0x79A194), // #79A194
            .piece_T = Color.from_u24(0x6B93A1), // #6B93A1
            .piece_Z = Color.from_u24(0x5F87AF), // #5F87AF
        };
    }

    fn gruvbox_dark() Palette {
        return Palette{
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

    fn gruvbox_light() Palette {
        return Palette{
            .fg_prim = Color.from_u24(0x282828), // #282828
            .fg_seco = Color.from_u24(0x5B5648), // #5B5648
            .bg_seco = Color.from_u24(0xB6AC90), // #B6AC90
            .bg_prim = Color.from_u24(0xEBDBB2), // #EBDBB2
            .piece_I = Color.from_u24(0xCC241D), // #CC241D
            .piece_J = Color.from_u24(0xD65D0E), // #D65D0E
            .piece_L = Color.from_u24(0xD79921), // #D79921
            .piece_O = Color.from_u24(0x98971A), // #98971A
            .piece_S = Color.from_u24(0x689D6A), // #689D6A
            .piece_T = Color.from_u24(0x458588), // #458588
            .piece_Z = Color.from_u24(0xB16286), // #B16286
        };
    }

    fn onedark() Palette {
        return Palette{
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

    fn onelight() Palette {
        return Palette{
            .fg_prim = Color.from_u24(0x101012), // #101012
            .fg_seco = Color.from_u24(0x383a42), // #383A42
            .bg_seco = Color.from_u24(0xc9c9c9), // #C9C9C9
            .bg_prim = Color.from_u24(0xfafafa), // #FAFAFA
            .piece_I = Color.from_u24(0xE06C75), // #E06C75
            .piece_J = Color.from_u24(0xE29678), // #E29678
            .piece_L = Color.from_u24(0xE5C07B), // #E5C07B
            .piece_O = Color.from_u24(0x98C379), // #98C379
            .piece_S = Color.from_u24(0x56B6C2), // #56B6C2
            .piece_T = Color.from_u24(0x61AFEF), // #61AFEF
            .piece_Z = Color.from_u24(0xC678DD), // #C678DD
        };
    }

    fn pastel_dark() Palette {
        return Palette{
            .fg_prim = Color.from_u24(0xFFFFFC), // #FFFFFC
            .fg_seco = Color.from_u24(0xDDDDDA), // #DDDDDA
            .bg_seco = Color.from_u24(0x555566), // #555566
            .bg_prim = Color.from_u24(0x444444), // #444444
            .piece_I = Color.from_u24(0xFFADAD), // #FFADAD
            .piece_J = Color.from_u24(0xFFD6A5), // #FFD6A5
            .piece_L = Color.from_u24(0xFDFFB6), // #FDFFB6
            .piece_O = Color.from_u24(0xCAFFBF), // #CAFFBF
            .piece_S = Color.from_u24(0x9BF6FF), // #9BF6FF
            .piece_T = Color.from_u24(0xA0C4FF), // #A0C4FF
            .piece_Z = Color.from_u24(0xBDB2FF), // #BDB2FF
        };
    }

    fn pastel_light() Palette {
        return Palette{
            .fg_prim = Color.from_u24(0x333344), // #333344
            .fg_seco = Color.from_u24(0x444455), // #444455
            .bg_seco = Color.from_u24(0xDDDDDA), // #DDDDDA
            .bg_prim = Color.from_u24(0xFFFFFC), // #FFFFFC
            .piece_I = Color.from_u24(0xFF9DAD), // #FF9DAD
            .piece_J = Color.from_u24(0xFFC6A5), // #FFC6A5
            .piece_L = Color.from_u24(0xEDEEA6), // #EDEEA6
            .piece_O = Color.from_u24(0xBAEEAF), // #BAEEAF
            .piece_S = Color.from_u24(0x9BE6FF), // #9BE6FF
            .piece_T = Color.from_u24(0xA0B4FF), // #A0B4FF
            .piece_Z = Color.from_u24(0xBDA2FF), // #BDA2FF
        };
    }
};

pub const Colorscheme = struct {
    const Self = @This();
    name: Colorname,
    palette: Palette,

    pub fn default() Colorscheme {
        return Colorscheme{
            .name = Colorname.habamax,
            .palette = Palette.habamax(),
        };
    }

    pub fn set_colors(s: *Self) void {
        s.palette = switch (s.name) {
            .habamax => Palette.habamax(),
            .habamin => Palette.habamin(),
            .gruvbox_dark => Palette.gruvbox_dark(),
            .gruvbox_light => Palette.gruvbox_light(),
            .onedark => Palette.onedark(),
            .onelight => Palette.onelight(),
            .pastel_dark => Palette.pastel_dark(),
            .pastel_light => Palette.pastel_light(),
        };
    }

    pub fn next(s: *Self) void {
        s.name = s.name.next();
        s.set_colors();
    }

    pub fn previous(s: *Self) void {
        s.name = s.name.previous();
        s.set_colors();
    }

    pub fn from_piecetype(s: *Self, p: PieceType) Color {
        return switch (p) {
            PieceType.None => s.palette.bg_prim,
            PieceType.I => s.palette.piece_I,
            PieceType.O => s.palette.piece_O,
            PieceType.J => s.palette.piece_J,
            PieceType.L => s.palette.piece_L,
            PieceType.S => s.palette.piece_S,
            PieceType.Z => s.palette.piece_Z,
            PieceType.T => s.palette.piece_T,
        };
    }
};

pub const Style = enum {
    const Self = @This();
    Solid,
    Gridless,
    Boxes,
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
        return @intFromEnum(s);
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
        return @intFromEnum(s);
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
        for (PieceType.iter, 0..) |ptype, ti| {
            for (Rotation.iter, 0..) |prot, ri| {
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
                    .min_row = @as(i8, @intCast(min_row)),
                    .min_col = @as(i8, @intCast(min_col)),
                    .max_row = @as(i8, @intCast(max_row)),
                    .max_col = @as(i8, @intCast(max_col)),
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
    inline for (@typeInfo(T).Enum.fields, 0..) |e, i| {
        result[i] = @as(T, @enumFromInt(e.value));
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
