const std = @import("std");
const C = @import("c.zig");

// the game (you just lost)
const ROWS = 20;
const COLUMNS = 10;
const TARGET_FPS: u64 = 60;
const TARGET_FPS_DELAY: u64 = std.time.ns_per_s / TARGET_FPS;
const SDL_FRAME_DELAY: u32 = TARGET_FPS_DELAY / std.time.ns_per_ms / 2;
const FONT_BYTES = @embedFile("assets/font.ttf");

// aspect ratio for width : height
const RATIO_WIDTH = COLUMNS + 8;
const RATIO_HEIGHT = ROWS + 2;

const ENABLE_GRAVITY = true;
const GRAVITY_DELAY = std.time.ns_per_s;

const Style = enum {
    Solid,
    Gridless,
    Boxes,
    Edges,
};

const Rotation = enum {
    None,
    Right,
    Spin,
    Left,

    const iterable: [4]Rotation = .{ .None, .Right, .Spin, .Left };

    fn rotate_right(r: Rotation) Rotation {
        return switch (r) {
            .None => .Right,
            .Right => .Spin,
            .Spin => .Left,
            .Left => .None,
        };
    }
    fn rotate_left(r: Rotation) Rotation {
        return switch (r) {
            .None => .Left,
            .Left => .Spin,
            .Spin => .Right,
            .Right => .None,
        };
    }

    fn rotate_spin(r: Rotation) Rotation {
        return switch (r) {
            .None => .Spin,
            .Left => .Right,
            .Spin => .None,
            .Right => .Left,
        };
    }
};

const PieceType = enum {
    I,
    J,
    L,
    O,
    S,
    T,
    Z,
    None,

    const iterable: [7]PieceType = .{ .I, .J, .L, .O, .S, .T, .Z };
    var index: u8 = 7;
    var bag = iterable;

    fn random(rng: std.rand.Random) PieceType {
        if (index == 7) {
            rng.shuffleWithIndex(PieceType, &bag, u8);
            index = 0;
        }
        const t = bag[index];
        index += 1;
        return t;
    }

    fn as(t: PieceType, r: Rotation) [4][4]PieceType {
        const B: PieceType = .None;
        const I: PieceType = .I;
        const O: PieceType = .O;
        const J: PieceType = .J;
        const L: PieceType = .L;
        const S: PieceType = .S;
        const Z: PieceType = .Z;
        const T: PieceType = .T;
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

const RC = struct {
    row: i8,
    col: i8,
};

const Position = RC;
const Delta = RC;

const Offsets = struct {
    rows: [4]i8,
    cols: [4]i8,

    const PIECES = PieceType.iterable.len;
    const ROTATIONS = Rotation.iterable.len;

    fn create_lut() [PIECES][ROTATIONS]Offsets {
        @setEvalBranchQuota(2000);
        var lut: [PIECES][ROTATIONS]Offsets = undefined;
        for (PieceType.iterable, 0..) |piecetype, ti| {
            if (piecetype == .None) continue;
            for (Rotation.iterable, 0..) |rotation, ri| {
                const data = piecetype.as(rotation);
                var rows: [4]i8 = undefined;
                var cols: [4]i8 = undefined;
                var i: usize = 0;

                for (data, 0..) |row, r| {
                    for (row, 0..) |e, c| {
                        if (e != .None) {
                            rows[i] = @intCast(r);
                            cols[i] = @intCast(c);
                            i += 1;
                        }
                    }
                }

                lut[ti][ri] = Offsets{ .rows = rows, .cols = cols };
            }
        }
        return lut;
    }

    fn get(t: PieceType, r: Rotation) Offsets {
        const S = struct {
            const lookup_table = Offsets.create_lut();
        };

        const pi: u32 = @intFromEnum(t);
        const ri: u32 = @intFromEnum(r);
        return S.lookup_table[pi][ri];
    }
};

const Piece = struct {
    type: PieceType,
    position: Position,
    rotation: Rotation,

    fn new(t: PieceType) Piece {
        return .{
            .type = t,
            .position = .{ .row = 0, .col = COLUMNS / 2 - 2 },
            .rotation = .None,
        };
    }
};

const Metrics = struct {
    holes: u8,
    deepest: u8,
    background: u8,
};

const Color = struct {
    red: u8,
    green: u8,
    blue: u8,

    fn from_u24(rgb: u24) Color {
        const r: u8 = @intCast((rgb >> 16) & 0xff);
        const g: u8 = @intCast((rgb >> 8) & 0xff);
        const b: u8 = @intCast((rgb >> 0) & 0xff);
        return .{ .red = r, .green = g, .blue = b };
    }

    fn combine(lhs: Color, rhs: Color, l: u8) Color {
        const r: u8 = (128 - l);
        const lr: u16 = @intCast(lhs.red);
        const lg: u16 = @intCast(lhs.green);
        const lb: u16 = @intCast(lhs.blue);
        const rr: u16 = @intCast(rhs.red);
        const rg: u16 = @intCast(rhs.green);
        const rb: u16 = @intCast(rhs.blue);

        const cr: u8 = @intCast((lr * l + rr * r) / 128);
        const cg: u8 = @intCast((lg * l + rg * r) / 128);
        const cb: u8 = @intCast((lb * l + rb * r) / 128);
        return .{ .red = cr, .green = cg, .blue = cb };
    }
};

const Palette = struct {
    F: Color,
    G: Color,
    N: Color,
    B: Color,
    I: Color,
    O: Color,
    J: Color,
    L: Color,
    S: Color,
    Z: Color,
    T: Color,

    fn habamax() Palette {
        return .{
            .F = Color.from_u24(0xBCBCBC), // #BCBCBC
            .G = Color.from_u24(0x898989), // #898989
            .N = Color.from_u24(0x454545), // #454545
            .B = Color.from_u24(0x1C1C1C), // #1C1C1C
            .I = Color.from_u24(0xD75F5F), // #D75F5F
            .J = Color.from_u24(0xBC796C), // #BC796C
            .L = Color.from_u24(0xA19379), // #A19379
            .O = Color.from_u24(0x87AF87), // #87AF87
            .S = Color.from_u24(0x79A194), // #79A194
            .T = Color.from_u24(0x6B93A1), // #6B93A1
            .Z = Color.from_u24(0x5F87AF), // #5F87AF
        };
    }

    fn habamin() Palette {
        return .{
            .F = Color.from_u24(0x1C1C1C), // #1C1C1C
            .G = Color.from_u24(0x454545), // #454545
            .N = Color.from_u24(0xABABAB), // #ABABAB
            .B = Color.from_u24(0xCDCDCD), // #CDCDCD
            .I = Color.from_u24(0xD75F5F), // #D75F5F
            .J = Color.from_u24(0xBC796C), // #BC796C
            .L = Color.from_u24(0xA19379), // #A19379
            .O = Color.from_u24(0x87AF87), // #87AF87
            .S = Color.from_u24(0x79A194), // #79A194
            .T = Color.from_u24(0x6B93A1), // #6B93A1
            .Z = Color.from_u24(0x5F87AF), // #5F87AF
        };
    }

    fn gruvbox_dark() Palette {
        return .{
            .F = Color.from_u24(0xEBDBB2), // #EBDBB2
            .G = Color.from_u24(0xB6AC90), // #B6AC90
            .N = Color.from_u24(0x5B5648), // #5B5648
            .B = Color.from_u24(0x282828), // #282828
            .I = Color.from_u24(0xCC241D), // #CC241D
            .J = Color.from_u24(0xD65D0E), // #D65D0E
            .L = Color.from_u24(0xD79921), // #D79921
            .O = Color.from_u24(0x98971A), // #98971A
            .S = Color.from_u24(0x689D6A), // #689D6A
            .T = Color.from_u24(0x458588), // #458588
            .Z = Color.from_u24(0xB16286), // #B16286
        };
    }

    fn gruvbox_light() Palette {
        return .{
            .F = Color.from_u24(0x282828), // #282828
            .G = Color.from_u24(0x5B5648), // #5B5648
            .N = Color.from_u24(0xB6AC90), // #B6AC90
            .B = Color.from_u24(0xEBDBB2), // #EBDBB2
            .I = Color.from_u24(0xCC241D), // #CC241D
            .J = Color.from_u24(0xD65D0E), // #D65D0E
            .L = Color.from_u24(0xD79921), // #D79921
            .O = Color.from_u24(0x98971A), // #98971A
            .S = Color.from_u24(0x689D6A), // #689D6A
            .T = Color.from_u24(0x458588), // #458588
            .Z = Color.from_u24(0xB16286), // #B16286
        };
    }

    fn onedark() Palette {
        return .{
            .F = Color.from_u24(0xABB2BF), // #ABB2BF
            .G = Color.from_u24(0x8C94A2), // #8C94A2
            .N = Color.from_u24(0x464A51), // #464A51
            .B = Color.from_u24(0x282C34), // #282C34
            .I = Color.from_u24(0xE06C75), // #E06C75
            .J = Color.from_u24(0xE29678), // #E29678
            .L = Color.from_u24(0xE5C07B), // #E5C07B
            .O = Color.from_u24(0x98C379), // #98C379
            .S = Color.from_u24(0x56B6C2), // #56B6C2
            .T = Color.from_u24(0x61AFEF), // #61AFEF
            .Z = Color.from_u24(0xC678DD), // #C678DD
        };
    }

    fn onelight() Palette {
        return .{
            .F = Color.from_u24(0x101012), // #101012
            .G = Color.from_u24(0x383a42), // #383A42
            .N = Color.from_u24(0xc9c9c9), // #C9C9C9
            .B = Color.from_u24(0xfafafa), // #FAFAFA
            .I = Color.from_u24(0xE06C75), // #E06C75
            .J = Color.from_u24(0xE29678), // #E29678
            .L = Color.from_u24(0xE5C07B), // #E5C07B
            .O = Color.from_u24(0x98C379), // #98C379
            .S = Color.from_u24(0x56B6C2), // #56B6C2
            .T = Color.from_u24(0x61AFEF), // #61AFEF
            .Z = Color.from_u24(0xC678DD), // #C678DD
        };
    }

    fn pastel_dark() Palette {
        return .{
            .F = Color.from_u24(0xFFFFFC), // #FFFFFC
            .G = Color.from_u24(0xDDDDDA), // #DDDDDA
            .N = Color.from_u24(0x222233), // #222233
            .B = Color.from_u24(0x111122), // #111122
            .I = Color.from_u24(0xFFADAD), // #FFADAD
            .J = Color.from_u24(0xFFD6A5), // #FFD6A5
            .L = Color.from_u24(0xFDFFB6), // #FDFFB6
            .O = Color.from_u24(0xCAFFBF), // #CAFFBF
            .S = Color.from_u24(0x9BF6FF), // #9BF6FF
            .T = Color.from_u24(0xA0C4FF), // #A0C4FF
            .Z = Color.from_u24(0xBDB2FF), // #BDB2FF
        };
    }

    fn pastel_light() Palette {
        return .{
            .F = Color.from_u24(0x111122), // #111122
            .G = Color.from_u24(0x222233), // #222233
            .N = Color.from_u24(0xDDDDDA), // #DDDDDA
            .B = Color.from_u24(0xFFFFFC), // #FFFFFC
            .I = Color.from_u24(0xFF9DAD), // #FF9DAD
            .J = Color.from_u24(0xFFC6A5), // #FFC6A5
            .L = Color.from_u24(0xEDEEA6), // #EDEEA6
            .O = Color.from_u24(0xBAEEAF), // #BAEEAF
            .S = Color.from_u24(0x9BE6FF), // #9BE6FF
            .T = Color.from_u24(0xA0B4FF), // #A0B4FF
            .Z = Color.from_u24(0xBDA2FF), // #BDA2FF
        };
    }
};

const Colorscheme = struct {
    const Name = enum {
        habamax,
        habamin,
        gruvbox_dark,
        gruvbox_light,
        onedark,
        onelight,
        pastel_dark,
        pastel_light,

        fn next(n: Name) Name {
            return @enumFromInt(@intFromEnum(n) +% 1);
        }

        fn previous(n: Name) Name {
            return @enumFromInt(@intFromEnum(n) -% 1);
        }
    };

    name: Name,
    palette: Palette,

    fn default() Colorscheme {
        return .{
            .name = .habamax,
            .palette = Palette.habamax(),
        };
    }

    fn set_colors(s: *Colorscheme) void {
        s.palette = switch (s.name) {
            inline else => |e| @call(.auto, @field(Palette, @tagName(e)), .{}),
        };
    }

    fn next(s: *Colorscheme) void {
        s.name = s.name.next();
        s.set_colors();
    }

    fn previous(s: *Colorscheme) void {
        s.name = s.name.previous();
        s.set_colors();
    }

    fn from_piecetype(s: *Colorscheme, t: PieceType) Color {
        return switch (t) {
            PieceType.None => s.palette.B,
            inline else => |e| @field(s.palette, @tagName(e)),
        };
    }
};

const Game = struct {
    const Bot = struct {
        const State = enum {
            off,
            slow,
            medium,
            fast,
        };

        state: State,

        fn active(s: *Bot) bool {
            return s.state != .off;
        }
    };

    SIZE: usize = 42,
    BORDER: usize = 1,
    BSIZE: usize = 43,

    grid: [ROWS][COLUMNS]PieceType = .{.{.None} ** COLUMNS} ** ROWS,

    // dummy placeholders
    current_piece: Piece = Piece.new(.J),
    current_holding: PieceType = .L,
    current_queue: [4]PieceType = .{ .O, .S, .T, .Z },

    lines_cleared: u64 = 0,
    pieces_locked: u64 = 0,
    sprint_time: u64 = 0,
    sprint_finished: bool = false,
    current_colorscheme: Colorscheme = Colorscheme.default(),
    current_style: Style = .Gridless,
    zigtris_bot: Bot = .{ .state = .off },

    optimal_move: Piece = undefined,
    optimal_score: i32 = undefined,

    game_timer: std.time.Timer,
    gravity_timer: std.time.Timer,

    moves: std.ArrayList(Piece),
    stack: std.ArrayList(Piece),

    xoshiro: std.rand.Xoshiro256,

    fn init(allocator: std.mem.Allocator) !Game {
        const millis: u64 = @intCast(std.time.milliTimestamp());
        return .{
            .game_timer = try std.time.Timer.start(),
            .gravity_timer = try std.time.Timer.start(),
            .moves = std.ArrayList(Piece).init(allocator),
            .stack = std.ArrayList(Piece).init(allocator),
            .xoshiro = std.rand.Xoshiro256.init(millis),
        };
    }

    fn deinit(s: *Game) void {
        s.moves.deinit();
        s.stack.deinit();
    }

    fn collision(s: *Game) bool {
        const p = s.current_piece;
        const o = Offsets.get(p.type, p.rotation);

        const rs = o.rows;
        const rl = p.position.row + @min(rs[0], rs[1], rs[2], rs[3]);
        const ru = p.position.row + @max(rs[0], rs[1], rs[2], rs[3]);
        if (rl < 0 or ru >= ROWS) return true;

        const cs = o.cols;
        const cl = p.position.col + @min(cs[0], cs[1], cs[2], cs[3]);
        const cu = p.position.col + @max(cs[0], cs[1], cs[2], cs[3]);
        if (cl < 0 or cu >= COLUMNS) return true;

        // collision with pieces on the grid?
        for (rs, cs) |dr, dc| {
            const ri: usize = @intCast(p.position.row + dr);
            const ci: usize = @intCast(p.position.col + dc);
            if (s.grid[ri][ci] != .None) return true;
        }

        return false;
    }

    fn move_delta(s: *Game, delta: Delta) bool {
        const p = s.current_piece.position;
        s.current_piece.position.row += delta.row;
        s.current_piece.position.col += delta.col;
        if (s.collision()) {
            s.current_piece.position = p;
            return false;
        }
        return true;
    }

    fn materialize(s: *Game) void {
        const p = s.current_piece;
        const o = Offsets.get(p.type, p.rotation);
        for (o.rows, o.cols) |dr, dc| {
            const ri: usize = @intCast(p.position.row + dr);
            const ci: usize = @intCast(p.position.col + dc);
            s.grid[ri][ci] = p.type;
        }
    }

    fn push(s: *Game) void {
        s.stack.append(s.current_piece) catch unreachable;
        const p = s.current_piece;
        const o = Offsets.get(p.type, p.rotation);
        for (o.rows, o.cols) |dr, dc| {
            const ri: usize = @intCast(p.position.row + dr);
            const ci: usize = @intCast(p.position.col + dc);
            s.grid[ri][ci] = p.type;
        }

        // shift queue
        s.current_piece = Piece.new(s.current_queue[0]);
        s.current_queue[0] = s.current_queue[1];
        s.current_queue[1] = s.current_queue[2];
        s.current_queue[2] = s.current_queue[3];
    }

    fn pop(s: *Game) void {
        if (s.stack.items.len == 0) unreachable;
        const p = s.stack.pop();
        const o = Offsets.get(p.type, p.rotation);
        for (o.rows, o.cols) |dr, dc| {
            const ri: usize = @intCast(p.position.row + dr);
            const ci: usize = @intCast(p.position.col + dc);
            s.grid[ri][ci] = .None;
        }

        // unshift queue
        s.current_queue[3] = s.current_queue[2];
        s.current_queue[2] = s.current_queue[1];
        s.current_queue[1] = s.current_queue[0];
        s.current_queue[0] = s.current_piece.type;
        s.current_piece = p;
    }

    fn next_piece(s: *Game) void {
        s.current_piece = Piece.new(s.current_queue[0]);
        s.current_queue[0] = s.current_queue[1];
        s.current_queue[1] = s.current_queue[2];
        s.current_queue[2] = s.current_queue[3];
        s.current_queue[3] = PieceType.random(s.xoshiro.random());
        if (s.collision()) {
            // game over!
            s.reset();
        }
    }

    fn clear_grid(s: *Game) void {
        for (0..ROWS) |r| {
            for (0..COLUMNS) |c|
                s.grid[r][c] = .None;
        }
    }

    fn piece_lock(s: *Game) void {
        s.materialize();
        s.pieces_locked += 1;
        s.lines_cleared += s.clear_lines();
        s.next_piece();
    }

    fn move_left(s: *Game) bool {
        return s.move_delta(.{ .row = 0, .col = -1 });
    }

    fn move_right(s: *Game) bool {
        return s.move_delta(.{ .row = 0, .col = 1 });
    }

    fn move_down(s: *Game) bool {
        return s.move_delta(.{ .row = 1, .col = 0 });
    }

    fn gravity_tick(s: *Game) void {
        if (s.move_down()) return;
        s.piece_lock();
    }

    fn hold_piece(s: *Game) void {
        const t = s.current_piece.type;
        s.current_piece = Piece.new(s.current_holding);
        s.current_holding = t;
    }

    fn reset(s: *Game) void {
        s.clear_grid();

        const r = s.xoshiro.random();
        s.current_piece = Piece.new(PieceType.random(r));
        s.current_holding = PieceType.random(r);
        s.current_queue[0] = PieceType.random(r);
        s.current_queue[1] = PieceType.random(r);
        s.current_queue[2] = PieceType.random(r);
        s.current_queue[3] = PieceType.random(r);

        s.stack.shrinkRetainingCapacity(0);

        s.game_timer.reset();
        s.gravity_timer.reset();

        s.pieces_locked = 0;
        s.lines_cleared = 0;
        s.sprint_time = 0;
        s.sprint_finished = false;
    }

    fn ghost_drop(s: *Game) Position {
        const backup = s.current_piece.position;
        while (s.move_down()) {
            // :^)
        }
        const ghost = s.current_piece.position;
        s.current_piece.position = backup;
        return ghost;
    }

    fn hard_drop(s: *Game) void {
        s.soft_drop();
        s.piece_lock();
    }

    fn soft_drop(s: *Game) void {
        while (s.move_down()) {
            // :^)
        }
        s.gravity_timer.reset();
    }

    fn unstuck(s: *Game) bool {
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

        const p = s.current_piece.position;
        for (S.deltas) |delta| {
            s.current_piece.position.row += delta.row;
            s.current_piece.position.col += delta.col;
            if (!s.collision()) return true;
            s.current_piece.position = p;
        }
        return false;
    }

    fn rotate_right(s: *Game) void {
        const r = s.current_piece.rotation;
        s.current_piece.rotation = r.rotate_right();
        if (!s.unstuck()) s.current_piece.rotation = r;
    }

    fn rotate_left(s: *Game) void {
        const r = s.current_piece.rotation;
        s.current_piece.rotation = r.rotate_left();
        if (!s.unstuck()) s.current_piece.rotation = r;
    }

    fn spin(s: *Game) void {
        const r = s.current_piece.rotation;
        s.current_piece.rotation = r.rotate_spin();
        if (!s.unstuck()) s.current_piece.rotation = r;
    }

    fn clear_line(s: *Game, r: usize) bool {
        var clear: bool = true;
        for (s.grid[r]) |c| clear = clear and c != .None;
        return clear;
    }

    fn shift_lines(s: *Game, r: usize) void {
        var u: usize = r;
        while (u != 0) {
            u -= 1;
            for (0..COLUMNS) |c| s.grid[u + 1][c] = s.grid[u][c];
        } else for (0..COLUMNS) |c| s.grid[u][c] = .None;
    }

    fn clear_lines(s: *Game) u8 {
        var cleared: u8 = 0;
        var r: usize = ROWS - 1;
        while (r != 0) {
            if (s.clear_line(r)) {
                cleared += 1;
                s.shift_lines(r);
            } else r -= 1;
        }
        return cleared;
    }

    fn find_row_start(s: *Game) u8 {
        for (0..ROWS) |r| {
            for (0..COLUMNS) |c| {
                if (s.grid[r][c] != .None) return @intCast(r);
            }
        }
        return ROWS - 1;
    }

    fn compute_metrics(s: *Game, row_start: u8) Metrics {
        var holes: u8 = 0;
        var deepest: u8 = 0;
        var background: u8 = 0;

        for (0..COLUMNS) |c| {
            var r: u8 = row_start;
            while (r != ROWS and s.grid[r][c] == .None) : (r += 1) {
                background += 1;
                deepest = @max(deepest, r);
            }
            while (r != ROWS) : (r += 1) {
                if (s.grid[r][c] == .None) holes += 1;
            }
        }

        return .{
            .holes = holes,
            .deepest = deepest,
            .background = background,
        };
    }

    fn compute_score(s: *Game, placed: Piece) i32 {
        const row_start = s.find_row_start();
        const metrics = s.compute_metrics(row_start);
        const grid_height = ROWS - row_start;
        const piece_placement = ROWS - placed.position.row;
        const piece_orientation: i8 = switch (placed.rotation) {
            .Right, .Left => 1,
            else => 0,
        };

        var badness: i32 = 0;
        badness = (badness + metrics.holes) * 8;
        badness = (badness + metrics.background) * 2;
        badness = (badness + metrics.deepest) * 2;
        badness = (badness + piece_placement) * 2;
        badness = (badness + std.math.pow(i32, 2, grid_height)) * 2;
        badness = (badness + piece_orientation) * 2;
        return badness;
    }

    fn try_move(s: *Game, badness: i32) void {
        s.soft_drop();
        s.moves.append(s.current_piece) catch unreachable;
        s.push();
        const b = s.compute_score(s.current_piece);
        s.least_bad_moves((b + badness) >> 1);
        s.pop();
        _ = s.moves.pop();
    }

    fn try_rotations(
        s: *Game,
        comptime rotations: []const Rotation,
        badness: i32,
    ) void {
        const backup = s.current_piece;
        for (rotations) |rot| {
            s.current_piece.rotation = rot;
            s.try_move(badness);
            s.current_piece.position.row = backup.position.row;
            while (s.move_left()) {
                s.try_move(badness);
                s.current_piece.position.row = backup.position.row;
            }
            s.current_piece.position.col = backup.position.col;
            while (s.move_right()) {
                s.try_move(badness);
                s.current_piece.position.row = backup.position.row;
            }
        }
    }

    fn least_bad_moves(s: *Game, badness: i32) void {
        // early pruning for faster evaluation
        if (badness > s.optimal_score) return;

        if (s.moves.items.len == 5) {
            if (badness < s.optimal_score) {
                // the first move in this sequence of moves, is the optimal one
                // a complete re-evaluation of the move-tree is not necessary,
                // and results in an approximately 3 times slower bot
                s.optimal_move = s.moves.items[0];
                s.optimal_score = badness;
            }
            return;
        }

        // only consider meaningful rotations
        switch (s.current_piece.type) {
            .J, .L, .T => {
                s.try_rotations(&[_]Rotation{
                    .None,
                    .Right,
                    .Spin,
                    .Left,
                }, badness);
            },
            .I, .S, .Z => {
                s.try_rotations(&[_]Rotation{
                    .None,
                    .Right,
                }, badness);
            },
            .O => {
                s.try_rotations(&[_]Rotation{
                    .None,
                }, badness);
            },
            else => unreachable,
        }
    }

    fn set_optimal_move(s: *Game) void {
        const S = struct {
            var last_pieces_locked: u64 = undefined;
            var last_piecetype: PieceType = .None;
            var last_holding: PieceType = .None;
        };

        if (s.pieces_locked == S.last_pieces_locked) {
            const lt = S.last_piecetype;
            const lh = S.last_holding;
            const ct = s.current_piece.type;
            const ch = s.current_holding;
            if ((lt == ct and lh == ch) or (lt == ch and lh == ct)) return;
        }

        // dirty initialization
        s.optimal_move = s.current_piece;
        s.optimal_score = std.math.maxInt(i32);

        S.last_pieces_locked = s.pieces_locked;
        S.last_piecetype = s.current_piece.type;
        S.last_holding = s.current_holding;

        s.least_bad_moves(0);
        s.hold_piece();
        s.least_bad_moves(0);
        s.hold_piece();
    }

    // fully automatic play but with a fixed delay for each action taken
    fn fully_automatic_delayed(s: *Game, comptime DELAY: u64) void {
        const S = struct {
            var last_time: u64 = 0;
        };

        const time_passed: u64 = s.game_timer.read();
        // reset when game timer has been reset
        if (time_passed <= DELAY) S.last_time = time_passed;

        const ok = (time_passed - S.last_time) >= DELAY;
        if (!ok) return;

        const types = s.optimal_move.type != s.current_piece.type;
        if (types) {
            s.hold_piece();
            S.last_time = time_passed;
            return;
        }

        const rotation = s.current_piece.rotation != s.optimal_move.rotation;
        if (rotation) {
            s.current_piece.rotation = s.optimal_move.rotation;
            S.last_time = time_passed;
            return;
        }

        const col = s.optimal_move.position.col;
        const right = s.current_piece.position.col < col;
        if (right and s.move_right()) {
            S.last_time = time_passed;
            return;
        }

        const left = s.current_piece.position.col > col;
        if (left and s.move_left()) {
            S.last_time = time_passed;
            return;
        }

        s.hard_drop();
        S.last_time = time_passed;
    }

    fn fully_automatic_fast(s: *Game) void {
        if (s.optimal_move.type != s.current_piece.type) s.hold_piece();
        s.current_piece.rotation = s.optimal_move.rotation;
        const col = s.optimal_move.position.col;
        while (s.current_piece.position.col < col and s.move_right()) {}
        while (s.current_piece.position.col > col and s.move_left()) {}
        s.hard_drop();
    }

    fn fully_automatic(s: *Game) void {
        s.set_optimal_move();
        switch (s.zigtris_bot.state) {
            .off => {},
            .slow => s.fully_automatic_delayed(100 * std.time.ns_per_ms),
            .medium => s.fully_automatic_delayed(50 * std.time.ns_per_ms),
            .fast => s.fully_automatic_fast(),
        }
    }
};

// rigorous testing :^)
// waiting for any specific piece will take at most 6 + 6 pieces
// for example, you just got an I, and you get all other pieces twice first
// [I] : [J L O S T Z] : [J L O S T Z] : [I]
test "piecetypes are satisfyingly random" {
    const N = PieceType.iterable.len;
    var seen: [N]u8 = .{0} ** N;
    var r = std.rand.Xoshiro256.init(0);
    for (1..std.math.maxInt(u8)) |i| {
        for (0..N) |_| {
            const t = PieceType.random(r.random());
            const k = @intFromEnum(t);
            seen[k] += 1;
        }
        for (seen) |b| try std.testing.expectEqual(i, b);
    }
}

test "clear lines" {
    var g: Game = try Game.init(std.testing.allocator);
    defer g.deinit();
    g.reset();
    const empty: [ROWS][COLUMNS]PieceType = .{.{.None} ** COLUMNS} ** ROWS;
    for (empty, g.grid) |a, b|
        try std.testing.expect(std.mem.eql(PieceType, &a, &b));

    for (0..ROWS) |r| {
        for (0..COLUMNS) |c| {
            g.grid[r][c] = .O;
        }
    }
    const c = g.clear_lines();
    try std.testing.expectEqual(c, 20);
    for (empty, g.grid) |a, b|
        try std.testing.expect(std.mem.eql(PieceType, &a, &b));
}

// simple SDL renderer wrapper
const Renderer = struct {
    game: *Game,
    renderer: ?*C.SDL_Renderer,
    font: ?*C.TTF_Font,

    color: Color = undefined,
    force_redraw: u8 = 0,

    fn set_color(s: *Renderer, c: Color) void {
        s.color = c;
        _ = C.SDL_SetRenderDrawColor(
            s.renderer,
            c.red,
            c.green,
            c.blue,
            0xff,
        );
    }

    fn clear(s: *Renderer) void {
        _ = C.SDL_RenderClear(s.renderer);
    }

    fn fill_rectangle(
        s: *Renderer,
        x: usize,
        y: usize,
        width: usize,
        height: usize,
    ) void {
        var rectangle = C.SDL_Rect{
            .x = C.int(x),
            .y = C.int(y),
            .w = C.int(width),
            .h = C.int(height),
        };
        _ = C.SDL_RenderFillRect(s.renderer, &rectangle);
    }

    fn fill_square(s: *Renderer, x: usize, y: usize) void {
        switch (s.game.current_style) {
            .Solid => {
                s.fill_rectangle(
                    s.game.BSIZE + x * s.game.BSIZE,
                    s.game.BSIZE + y * s.game.BSIZE,
                    s.game.SIZE,
                    s.game.SIZE,
                );
            },
            .Gridless => {
                s.fill_rectangle(
                    s.game.BSIZE + x * s.game.BSIZE,
                    s.game.BSIZE + y * s.game.BSIZE,
                    s.game.SIZE,
                    s.game.SIZE,
                );
            },
            .Boxes => {
                const c = s.color;
                s.fill_rectangle(
                    s.game.BSIZE + x * s.game.BSIZE,
                    s.game.BSIZE + y * s.game.BSIZE,
                    s.game.SIZE,
                    s.game.SIZE,
                );
                s.set_color(s.game.current_colorscheme.palette.B);
                s.fill_rectangle(
                    s.game.BSIZE + x * s.game.BSIZE + (s.game.SIZE >> 2),
                    s.game.BSIZE + y * s.game.BSIZE + (s.game.SIZE >> 2),
                    s.game.SIZE >> 1,
                    s.game.SIZE >> 1,
                );
                s.set_color(c);
            },
            .Edges => {
                const c = s.color;
                s.fill_rectangle(
                    s.game.BSIZE + x * s.game.BSIZE,
                    s.game.BSIZE + y * s.game.BSIZE,
                    s.game.SIZE,
                    s.game.SIZE,
                );
                s.set_color(s.game.current_colorscheme.palette.B);
                s.fill_rectangle(
                    s.game.BSIZE + x * s.game.BSIZE + 1 * s.game.BORDER,
                    s.game.BSIZE + y * s.game.BSIZE + 1 * s.game.BORDER,
                    s.game.SIZE - 2 * s.game.BORDER,
                    s.game.SIZE - 2 * s.game.BORDER,
                );
                s.set_color(c);
            },
        }
    }

    fn draw_lines_cleared(s: *Renderer, current_lines: u64) !void {
        const S = struct {
            var colorname: Colorscheme.Name = undefined;
            var lines: u64 = 1 << 63;
            var text: ?*C.SDL_Texture = null;
            var rect: C.SDL_Rect = undefined;
        };
        const lines_equal = current_lines == S.lines;
        const colors_equal = S.colorname == s.game.current_colorscheme.name;
        if (lines_equal and colors_equal) {
            // re-use renderered
            if (s.force_redraw == 0) {
                _ = C.SDL_RenderCopy(
                    s.renderer,
                    S.text,
                    null,
                    &S.rect,
                );
                return;
            }
            s.force_redraw -= 1;
        }

        var buffer: [64]u8 = .{0} ** 64;
        const col_offset = s.game.BSIZE * COLUMNS + 3 * s.game.SIZE;
        const row_offset = s.game.BSIZE * (ROWS - 6);
        _ = std.fmt.bufPrint(
            &buffer,
            "{any}",
            .{current_lines},
        ) catch unreachable;
        const c = s.game.current_colorscheme.palette.F;
        const color = C.SDL_Color{
            .r = c.red,
            .g = c.green,
            .b = c.blue,
            .a = 0xff,
        };
        const surface =
            C.TTF_RenderText_Blended(s.font, &buffer, color) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        defer C.SDL_FreeSurface(surface);
        const text =
            C.SDL_CreateTextureFromSurface(s.renderer, surface) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        const tw = surface.*.w;
        const th = surface.*.h;
        var r = C.SDL_Rect{
            .x = C.int(col_offset),
            .y = C.int(row_offset),
            .w = tw,
            .h = th,
        };
        _ = C.SDL_RenderCopy(s.renderer, text, null, &r);

        // keep previous rendered stuff
        C.SDL_DestroyTexture(S.text);
        S.colorname = s.game.current_colorscheme.name;
        S.lines = current_lines;
        S.text = text;
        S.rect = r;
    }

    fn draw_time_passed(
        s: *Renderer,
        current_time: u64,
        highlight: bool,
    ) !void {
        const S = struct {
            var colorname: Colorscheme.Name = undefined;
            var time: u64 = undefined;
            var text: ?*C.SDL_Texture = null;
            var rect: C.SDL_Rect = undefined;
        };
        const time_equal = current_time == S.time;
        const colors_equal = S.colorname == s.game.current_colorscheme.name;
        if (time_equal and colors_equal) {
            // re-use renderered
            if (s.force_redraw == 0) {
                _ = C.SDL_RenderCopy(
                    s.renderer,
                    S.text,
                    null,
                    &S.rect,
                );
                return;
            }
            s.force_redraw -= 1;
        }

        var buffer: [64]u8 = .{0} ** 64;
        const col_offset = s.game.BSIZE * COLUMNS + 3 * s.game.SIZE;
        const row_offset = s.game.BSIZE * (ROWS - 4);
        _ = std.fmt.bufPrint(
            &buffer,
            "{}",
            .{current_time},
        ) catch unreachable;
        const c = switch (highlight) {
            false => s.game.current_colorscheme.palette.F,
            true => s.game.current_colorscheme.palette.T,
        };
        const color = C.SDL_Color{
            .r = c.red,
            .g = c.green,
            .b = c.blue,
            .a = 0xff,
        };
        const surface =
            C.TTF_RenderText_Blended(s.font, &buffer, color) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        defer C.SDL_FreeSurface(surface);
        const text =
            C.SDL_CreateTextureFromSurface(s.renderer, surface) orelse {
            C.SDL_Log("Unable to render texture: %s", C.SDL_GetError());
            return error.SDLRenderFailed;
        };
        const tw = surface.*.w;
        const th = surface.*.h;
        var r = C.SDL_Rect{
            .x = C.int(col_offset),
            .y = C.int(row_offset),
            .w = tw,
            .h = th,
        };
        _ = C.SDL_RenderCopy(s.renderer, text, null, &r);

        // keep previous rendered stuff
        C.SDL_DestroyTexture(S.text);
        S.colorname = s.game.current_colorscheme.name;
        S.time = current_time;
        S.text = text;
        S.rect = r;
    }

    fn draw_grid(s: *Renderer) void {
        // basically the outline
        switch (s.game.current_style) {
            .Solid => {
                s.set_color(s.game.current_colorscheme.palette.F);
                s.fill_rectangle(
                    s.game.SIZE,
                    s.game.SIZE,
                    COLUMNS * s.game.BSIZE + s.game.BORDER,
                    ROWS * s.game.BSIZE + s.game.BORDER,
                );
            },
            else => {
                s.set_color(s.game.current_colorscheme.palette.F);
                s.fill_rectangle(
                    s.game.SIZE,
                    s.game.SIZE,
                    COLUMNS * s.game.BSIZE + s.game.BORDER,
                    ROWS * s.game.BSIZE + s.game.BORDER,
                );
                s.set_color(s.game.current_colorscheme.palette.B);
                s.fill_rectangle(
                    s.game.SIZE + s.game.BORDER,
                    s.game.SIZE + s.game.BORDER,
                    COLUMNS * s.game.BSIZE - s.game.BORDER,
                    ROWS * s.game.BSIZE - s.game.BORDER,
                );
            },
        }

        for (0..ROWS) |r| {
            for (0..COLUMNS) |c| {
                const t = s.game.grid[r][c];
                const color = s.game.current_colorscheme.from_piecetype(t);
                s.set_color(color);
                s.fill_square(c, r);
            }
        }
    }

    fn draw_ghost(
        s: *Renderer,
        p: Position,
        t: PieceType,
        r: Rotation,
    ) void {
        const millis: f64 = @floatFromInt(std.time.milliTimestamp());
        const timestamp: f64 = millis / 1024;
        const pi: f64 = std.math.pi;
        const ratio: u8 = @intFromFloat(96 * @abs(@sin(pi * timestamp)));
        var gcc = s.game.current_colorscheme;
        const piece_color = gcc.from_piecetype(t);
        const background = gcc.palette.B;
        const combined = piece_color.combine(background, ratio);
        s.set_color(combined);
        s.draw_tetromino(p.col, p.row, t, r);
    }

    fn draw_tetromino(
        s: *Renderer,
        col: i8,
        row: i8,
        t: PieceType,
        r: Rotation,
    ) void {
        const o = Offsets.get(t, r);
        for (o.rows, o.cols) |dr, dc| {
            const ci: usize = @intCast(col + dc);
            const ri: usize = @intCast(row + dr);
            s.fill_square(ci, ri);
        }
    }

    fn show(s: *Renderer) void {
        C.SDL_RenderPresent(s.renderer);
        C.SDL_Delay(0);
    }
};

const Keyboard = struct {
    const INITIAL_DELAY: u64 = 112 * std.time.ns_per_ms;
    const REPEAT_DELAY: u64 = 16 * std.time.ns_per_ms;

    var holding: [C.SDL_NUM_SCANCODES]bool = .{false} ** C.SDL_NUM_SCANCODES;
    var repeating = false;

    var keys: [*c]const u8 = undefined;
    var timer: std.time.Timer = undefined;

    fn single(k: C.SDL_Scancode) bool {
        if (keys[k] == 0) {
            holding[k] = false;
            return false;
        }

        if (holding[k]) return false;

        holding[k] = true;
        return true;
    }

    fn repeats(k: C.SDL_Scancode) bool {
        if (keys[k] == 0) {
            holding[k] = false;
            return false;
        }

        if (!holding[k]) {
            holding[k] = true;
            timer.reset();
            return true;
        }

        const duration: u64 = timer.read();
        if (repeating) {
            if (duration < REPEAT_DELAY) return false;
            timer.reset();
            return true;
        }

        if (duration >= INITIAL_DELAY) repeating = true;

        return false;
    }

    fn handle_input(g: *Game, r: *Renderer) !bool {
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
                            const d1: usize = @intCast(event.window.data1);
                            const d2: usize = @intCast(event.window.data2);
                            const width = (d1 * RATIO_HEIGHT) / RATIO_WIDTH;
                            const height = d2;
                            const dimension = @min(width, height);
                            g.SIZE =
                                (dimension - (g.BORDER * RATIO_HEIGHT)) /
                                RATIO_HEIGHT;
                            g.BORDER = @max(g.SIZE / 42, 1);
                            g.BSIZE = g.SIZE + g.BORDER;
                            const font = sdl2_ttf(g) catch unreachable;
                            r.font = font;
                            r.force_redraw = 3;
                        },
                        else => {},
                    }
                },
                else => {},
            }
        }

        if (single(C.SDL_SCANCODE_ESCAPE)) return true;
        if (single(C.SDL_SCANCODE_F1)) g.zigtris_bot.state = .off;
        if (single(C.SDL_SCANCODE_F2)) g.zigtris_bot.state = .slow;
        if (single(C.SDL_SCANCODE_F3)) g.zigtris_bot.state = .medium;
        if (single(C.SDL_SCANCODE_F4)) g.zigtris_bot.state = .fast;
        if (single(C.SDL_SCANCODE_TAB)) g.current_colorscheme.next();
        if (single(C.SDL_SCANCODE_BACKSPACE)) g.current_colorscheme.previous();
        if (single(C.SDL_SCANCODE_1)) g.current_style = .Solid;
        if (single(C.SDL_SCANCODE_2)) g.current_style = .Gridless;
        if (single(C.SDL_SCANCODE_3)) g.current_style = .Boxes;
        if (single(C.SDL_SCANCODE_4)) g.current_style = .Edges;
        if (single(C.SDL_SCANCODE_R)) _ = g.reset();

        if (g.zigtris_bot.active()) {
            g.fully_automatic();
            return false;
        }

        // Player controls start here.
        if (single(C.SDL_SCANCODE_RCTRL)) _ = g.hold_piece();
        if (single(C.SDL_SCANCODE_A)) _ = g.rotate_left();
        if (single(C.SDL_SCANCODE_D)) _ = g.spin();
        if (single(C.SDL_SCANCODE_UP)) _ = g.rotate_right();
        if (single(C.SDL_SCANCODE_DOWN)) _ = g.soft_drop();
        if (single(C.SDL_SCANCODE_SPACE)) _ = g.hard_drop();

        if (repeats(C.SDL_SCANCODE_LEFT)) _ = g.move_left();
        if (repeats(C.SDL_SCANCODE_RIGHT)) _ = g.move_right();

        const left = holding[C.SDL_SCANCODE_LEFT];
        const right = holding[C.SDL_SCANCODE_RIGHT];
        repeating = repeating and (left or right);

        return false;
    }
};

fn sdl2_ttf(game: *Game) !*C.TTF_Font {
    const S = struct {
        var last_font: ?*C.TTF_Font = null;
    };

    const font_memory =
        C.SDL_RWFromConstMem(FONT_BYTES, FONT_BYTES.len) orelse {
        C.SDL_Log("Unable to SDL_RWFromConstMem: %s", C.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    if (C.TTF_Init() != 0) {
        C.SDL_Log("Unable to initialize TTF: %s", C.TTF_GetError());
        return error.SDLInitializationFailed;
    }

    const font: *C.TTF_Font =
        C.TTF_OpenFontRW(font_memory, 0, C.int(game.SIZE)) orelse {
        C.SDL_Log("Unable to TTF_OpenFontRW: %s", C.TTF_GetError());
        return error.SDLInitializationFailed;
    };

    C.TTF_CloseFont(S.last_font);
    S.last_font = font;

    return font;
}

pub fn sdl2_game(allocator: std.mem.Allocator) !void {
    var game: Game = try Game.init(allocator);
    defer game.deinit();
    game.reset();

    if (C.SDL_Init(C.SDL_INIT_VIDEO) != 0) {
        C.SDL_Log("Unable to initialize SDL: %s", C.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer C.SDL_Quit();

    const WINDOW_WIDTH: usize = RATIO_WIDTH * game.BSIZE;
    const WINDOW_HEIGHT: usize = RATIO_HEIGHT * game.BSIZE;

    const screen = C.SDL_CreateWindow(
        "Zigtris",
        C.SDL_WINDOWPOS_UNDEFINED,
        C.SDL_WINDOWPOS_UNDEFINED,
        C.int(WINDOW_WIDTH),
        C.int(WINDOW_HEIGHT),
        C.SDL_WINDOW_VULKAN | C.SDL_WINDOW_RESIZABLE,
    ) orelse C.SDL_CreateWindow(
        "Zigtris",
        C.SDL_WINDOWPOS_UNDEFINED,
        C.SDL_WINDOWPOS_UNDEFINED,
        C.int(WINDOW_WIDTH),
        C.int(WINDOW_HEIGHT),
        C.SDL_WINDOW_OPENGL | C.SDL_WINDOW_RESIZABLE,
    ) orelse {
        C.SDL_Log("Unable to create window: %s", C.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer C.SDL_DestroyWindow(screen);

    const renderer =
        C.SDL_CreateRenderer(screen, -1, 0) orelse {
        C.SDL_Log("Unable to create renderer: %s", C.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer C.SDL_DestroyRenderer(renderer);

    const font = sdl2_ttf(&game) catch unreachable;
    defer C.TTF_Quit();
    defer C.TTF_CloseFont(font);

    var r: Renderer = .{
        .game = &game,
        .renderer = renderer,
        .font = font,
    };

    Keyboard.keys = C.SDL_GetKeyboardState(null);
    Keyboard.timer = try std.time.Timer.start();

    var last_frame_drawn = try std.time.Timer.start();

    var quit: bool = false;
    while (!quit) {
        if (comptime ENABLE_GRAVITY) {
            const gravity_tick = game.gravity_timer.read() >= GRAVITY_DELAY;
            if (gravity_tick) {
                game.gravity_tick();
                game.gravity_timer.reset();
            }
        }

        quit = try Keyboard.handle_input(&game, &r);
        if (last_frame_drawn.read() >= TARGET_FPS_DELAY) {
            last_frame_drawn.reset();
            var gcc = game.current_colorscheme;
            r.set_color(gcc.palette.B);
            r.clear();

            r.draw_grid();

            const ghost = game.ghost_drop();
            const piece = game.current_piece;
            r.draw_ghost(
                ghost,
                piece.type,
                piece.rotation,
            );

            const ratio: u8 = 8;
            const piece_color = gcc.from_piecetype(piece.type);
            const foreground = gcc.palette.F;
            const combined = piece_color.combine(foreground, ratio);
            r.set_color(combined);
            r.draw_tetromino(
                piece.position.col,
                piece.position.row,
                piece.type,
                piece.rotation,
            );

            const col_offset = COLUMNS + 2;
            for (game.current_queue, 0..) |t, dr| {
                const row_offset: i8 = @intCast(1 + 3 * dr);
                r.set_color(gcc.from_piecetype(t));
                r.draw_tetromino(
                    col_offset,
                    row_offset,
                    t,
                    .None,
                );
            }

            r.set_color(gcc.from_piecetype(game.current_holding));
            const row_offset: i8 = @intCast(1 + 4 * game.current_queue.len);
            r.draw_tetromino(
                col_offset,
                row_offset,
                game.current_holding,
                .None,
            );

            r.draw_lines_cleared(game.lines_cleared) catch unreachable;

            // the game is a 40-line sprint + normal game by default, once you
            // clear 40 lines, the time in milliseconds will remain on the
            // screen for the rest of that session, R will reset the game.
            // during the sprint, only seconds will be shown, because seeing
            // milliseconds printed on the screen at all times is very annoying
            if (!game.sprint_finished) {
                if (game.lines_cleared < 40) {
                    const nanoseconds = game.game_timer.read();
                    const seconds = nanoseconds / std.time.ns_per_s;
                    game.sprint_time = seconds;
                } else {
                    const nanoseconds = game.game_timer.read();
                    const milliseconds = nanoseconds / std.time.ns_per_ms;
                    game.sprint_time = milliseconds;
                    game.sprint_finished = true;
                }
            }
            r.draw_time_passed(
                game.sprint_time,
                game.sprint_finished,
            ) catch unreachable;

            r.show();
        }

        if (!game.zigtris_bot.active()) C.SDL_Delay(SDL_FRAME_DELAY);
    }
}
