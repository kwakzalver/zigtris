const Standard = @import("std");

const Math = Standard.math;
const Time = Standard.time;
const Random = Standard.Random;
const Xoshiro256 = Standard.Random.Xoshiro256;
const Timer = Standard.time.Timer;
const ArrayListUnmanaged = Standard.ArrayListUnmanaged;

const Testing = Standard.testing;

const C = @import("c.zig");
const SDL = C.SDL;
const TTF = C.TTF;

// the game (you just lost)
const ROWS = 20;
const COLUMNS = 10;
const TARGET_FPS: u64 = 60;
const TARGET_FPS_DELAY: u64 = Time.ns_per_s / TARGET_FPS;
const FRAME_DELAY: u64 = TARGET_FPS_DELAY / Time.ns_per_ms / 2;
const FONT_BYTES = @embedFile("assets/font.ttf");
const MAX_LENGTH_U64 = 20;

// aspect ratio for width : height
const RATIO_WIDTH = COLUMNS + 8;
const RATIO_HEIGHT = ROWS + 2;

const GRAVITY_DELAY = Time.ns_per_s;

const Style = enum {
    solid,
    gridless,
    boxes,
    edges,
};

const Rotation = enum {
    none,
    right,
    spin,
    left,

    const iterable: [4]Rotation = .{ .none, .right, .spin, .left };

    fn rotate_right(r: Rotation) Rotation {
        return switch (r) {
            .none => .right,
            .right => .spin,
            .spin => .left,
            .left => .none,
        };
    }

    fn rotate_left(r: Rotation) Rotation {
        return switch (r) {
            .none => .left,
            .left => .spin,
            .spin => .right,
            .right => .none,
        };
    }

    fn rotate_spin(r: Rotation) Rotation {
        return switch (r) {
            .none => .spin,
            .left => .right,
            .spin => .none,
            .right => .left,
        };
    }
};

const Piecetype = enum {
    I,
    J,
    L,
    O,
    S,
    T,
    Z,
    none,

    const iterable: [7]Piecetype = .{ .I, .J, .L, .O, .S, .T, .Z };
    var index: u8 = 7;
    var bag = iterable;

    fn random(rng: Random) Piecetype {
        if (index == 7) {
            rng.shuffleWithIndex(Piecetype, &bag, u8);
            index = 0;
        }
        const t = bag[index];
        index += 1;
        return t;
    }

    fn as(t: Piecetype, r: Rotation) [4][4]Piecetype {
        const B: Piecetype = .none;
        const I: Piecetype = .I;
        const O: Piecetype = .O;
        const J: Piecetype = .J;
        const L: Piecetype = .L;
        const S: Piecetype = .S;
        const Z: Piecetype = .Z;
        const T: Piecetype = .T;
        return switch (t) {
            I => switch (r) {
                .none => .{
                    .{ B, B, B, B },
                    .{ I, I, I, I },
                    .{ B, B, B, B },
                    .{ B, B, B, B },
                },
                .right => .{
                    .{ B, B, I, B },
                    .{ B, B, I, B },
                    .{ B, B, I, B },
                    .{ B, B, I, B },
                },
                .spin => .{
                    .{ B, B, B, B },
                    .{ B, B, B, B },
                    .{ I, I, I, I },
                    .{ B, B, B, B },
                },
                .left => .{
                    .{ B, I, B, B },
                    .{ B, I, B, B },
                    .{ B, I, B, B },
                    .{ B, I, B, B },
                },
            },
            O => switch (r) {
                .none => .{
                    .{ O, O, B, B },
                    .{ O, O, B, B },
                    .{ B, B, B, B },
                    .{ B, B, B, B },
                },
                .right => .{
                    .{ B, O, O, B },
                    .{ B, O, O, B },
                    .{ B, B, B, B },
                    .{ B, B, B, B },
                },
                .spin => .{
                    .{ B, B, B, B },
                    .{ B, O, O, B },
                    .{ B, O, O, B },
                    .{ B, B, B, B },
                },
                .left => .{
                    .{ B, B, B, B },
                    .{ O, O, B, B },
                    .{ O, O, B, B },
                    .{ B, B, B, B },
                },
            },
            J => switch (r) {
                .none => .{
                    .{ J, B, B, B },
                    .{ J, J, J, B },
                    .{ B, B, B, B },
                    .{ B, B, B, B },
                },
                .right => .{
                    .{ B, J, J, B },
                    .{ B, J, B, B },
                    .{ B, J, B, B },
                    .{ B, B, B, B },
                },
                .spin => .{
                    .{ B, B, B, B },
                    .{ J, J, J, B },
                    .{ B, B, J, B },
                    .{ B, B, B, B },
                },
                .left => .{
                    .{ B, J, B, B },
                    .{ B, J, B, B },
                    .{ J, J, B, B },
                    .{ B, B, B, B },
                },
            },
            L => switch (r) {
                .none => .{
                    .{ B, B, L, B },
                    .{ L, L, L, B },
                    .{ B, B, B, B },
                    .{ B, B, B, B },
                },
                .right => .{
                    .{ B, L, B, B },
                    .{ B, L, B, B },
                    .{ B, L, L, B },
                    .{ B, B, B, B },
                },
                .spin => .{
                    .{ B, B, B, B },
                    .{ L, L, L, B },
                    .{ L, B, B, B },
                    .{ B, B, B, B },
                },
                .left => .{
                    .{ L, L, B, B },
                    .{ B, L, B, B },
                    .{ B, L, B, B },
                    .{ B, B, B, B },
                },
            },
            S => switch (r) {
                .none => .{
                    .{ B, S, S, B },
                    .{ S, S, B, B },
                    .{ B, B, B, B },
                    .{ B, B, B, B },
                },
                .right => .{
                    .{ B, S, B, B },
                    .{ B, S, S, B },
                    .{ B, B, S, B },
                    .{ B, B, B, B },
                },
                .spin => .{
                    .{ B, B, B, B },
                    .{ B, S, S, B },
                    .{ S, S, B, B },
                    .{ B, B, B, B },
                },
                .left => .{
                    .{ S, B, B, B },
                    .{ S, S, B, B },
                    .{ B, S, B, B },
                    .{ B, B, B, B },
                },
            },
            Z => switch (r) {
                .none => .{
                    .{ Z, Z, B, B },
                    .{ B, Z, Z, B },
                    .{ B, B, B, B },
                    .{ B, B, B, B },
                },
                .right => .{
                    .{ B, B, Z, B },
                    .{ B, Z, Z, B },
                    .{ B, Z, B, B },
                    .{ B, B, B, B },
                },
                .spin => .{
                    .{ B, B, B, B },
                    .{ Z, Z, B, B },
                    .{ B, Z, Z, B },
                    .{ B, B, B, B },
                },
                .left => .{
                    .{ B, Z, B, B },
                    .{ Z, Z, B, B },
                    .{ Z, B, B, B },
                    .{ B, B, B, B },
                },
            },
            T => switch (r) {
                .none => .{
                    .{ B, T, B, B },
                    .{ T, T, T, B },
                    .{ B, B, B, B },
                    .{ B, B, B, B },
                },
                .right => .{
                    .{ B, T, B, B },
                    .{ B, T, T, B },
                    .{ B, T, B, B },
                    .{ B, B, B, B },
                },
                .spin => .{
                    .{ B, B, B, B },
                    .{ T, T, T, B },
                    .{ B, T, B, B },
                    .{ B, B, B, B },
                },
                .left => .{
                    .{ B, T, B, B },
                    .{ T, T, B, B },
                    .{ B, T, B, B },
                    .{ B, B, B, B },
                },
            },
            B => .{
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

    const PIECES = Piecetype.iterable.len;
    const ROTATIONS = Rotation.iterable.len;

    fn create_lut() [PIECES][ROTATIONS]Offsets {
        @setEvalBranchQuota(2000);
        var lut: [PIECES][ROTATIONS]Offsets = undefined;
        for (Piecetype.iterable, 0..) |piecetype, ti| {
            if (piecetype == .none) continue;
            for (Rotation.iterable, 0..) |rotation, ri| {
                const data = piecetype.as(rotation);
                var rows: [4]i8 = undefined;
                var cols: [4]i8 = undefined;
                var i: u64 = 0;

                for (data, 0..) |row, r| {
                    for (row, 0..) |e, c| {
                        if (e != .none) {
                            rows[i] = @intCast(r);
                            cols[i] = @intCast(c);
                            i += 1;
                        }
                    }
                }

                lut[ti][ri] = .{ .rows = rows, .cols = cols };
            }
        }
        return lut;
    }

    fn get(t: Piecetype, r: Rotation) Offsets {
        const Static = struct {
            const lookup_table = Offsets.create_lut();
        };

        const pi: u64 = @intFromEnum(t);
        const ri: u64 = @intFromEnum(r);
        return Static.lookup_table[pi][ri];
    }
};

const Piece = struct {
    type: Piecetype,
    rotation: Rotation,
    position: Position,

    fn new(t: Piecetype) Piece {
        return .{
            .type = t,
            .position = .{ .row = 0, .col = COLUMNS / 2 - 2 },
            .rotation = .none,
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
            .F = Color.from_u24(0xBCBCBC),
            .G = Color.from_u24(0x898989),
            .N = Color.from_u24(0x454545),
            .B = Color.from_u24(0x1C1C1C),
            .I = Color.from_u24(0xD75F5F),
            .J = Color.from_u24(0xBC796C),
            .L = Color.from_u24(0xA19379),
            .O = Color.from_u24(0x87AF87),
            .S = Color.from_u24(0x79A194),
            .T = Color.from_u24(0x6B93A1),
            .Z = Color.from_u24(0x5F87AF),
        };
    }

    fn habamin() Palette {
        return .{
            .F = Color.from_u24(0x1C1C1C),
            .G = Color.from_u24(0x454545),
            .N = Color.from_u24(0xABABAB),
            .B = Color.from_u24(0xCDCDCD),
            .I = Color.from_u24(0xD75F5F),
            .J = Color.from_u24(0xBC796C),
            .L = Color.from_u24(0xA19379),
            .O = Color.from_u24(0x87AF87),
            .S = Color.from_u24(0x79A194),
            .T = Color.from_u24(0x6B93A1),
            .Z = Color.from_u24(0x5F87AF),
        };
    }

    fn gruvbox_dark() Palette {
        return .{
            .F = Color.from_u24(0xEBDBB2),
            .G = Color.from_u24(0xB6AC90),
            .N = Color.from_u24(0x5B5648),
            .B = Color.from_u24(0x282828),
            .I = Color.from_u24(0xCC241D),
            .J = Color.from_u24(0xD65D0E),
            .L = Color.from_u24(0xD79921),
            .O = Color.from_u24(0x98971A),
            .S = Color.from_u24(0x689D6A),
            .T = Color.from_u24(0x458588),
            .Z = Color.from_u24(0xB16286),
        };
    }

    fn gruvbox_light() Palette {
        return .{
            .F = Color.from_u24(0x282828),
            .G = Color.from_u24(0x5B5648),
            .N = Color.from_u24(0xB6AC90),
            .B = Color.from_u24(0xEBDBB2),
            .I = Color.from_u24(0xCC241D),
            .J = Color.from_u24(0xD65D0E),
            .L = Color.from_u24(0xD79921),
            .O = Color.from_u24(0x98971A),
            .S = Color.from_u24(0x689D6A),
            .T = Color.from_u24(0x458588),
            .Z = Color.from_u24(0xB16286),
        };
    }

    fn onedark() Palette {
        return .{
            .F = Color.from_u24(0xABB2BF),
            .G = Color.from_u24(0x8C94A2),
            .N = Color.from_u24(0x464A51),
            .B = Color.from_u24(0x282C34),
            .I = Color.from_u24(0xE06C75),
            .J = Color.from_u24(0xE29678),
            .L = Color.from_u24(0xE5C07B),
            .O = Color.from_u24(0x98C379),
            .S = Color.from_u24(0x56B6C2),
            .T = Color.from_u24(0x61AFEF),
            .Z = Color.from_u24(0xC678DD),
        };
    }

    fn onelight() Palette {
        return .{
            .F = Color.from_u24(0x101012),
            .G = Color.from_u24(0x383a42),
            .N = Color.from_u24(0xc9c9c9),
            .B = Color.from_u24(0xfafafa),
            .I = Color.from_u24(0xE06C75),
            .J = Color.from_u24(0xE29678),
            .L = Color.from_u24(0xE5C07B),
            .O = Color.from_u24(0x98C379),
            .S = Color.from_u24(0x56B6C2),
            .T = Color.from_u24(0x61AFEF),
            .Z = Color.from_u24(0xC678DD),
        };
    }

    fn pastel_dark() Palette {
        return .{
            .F = Color.from_u24(0xFFFFFC),
            .G = Color.from_u24(0xDDDDDA),
            .N = Color.from_u24(0x222233),
            .B = Color.from_u24(0x111122),
            .I = Color.from_u24(0xFFADAD),
            .J = Color.from_u24(0xFFD6A5),
            .L = Color.from_u24(0xFDFFB6),
            .O = Color.from_u24(0xCAFFBF),
            .S = Color.from_u24(0x9BF6FF),
            .T = Color.from_u24(0xA0C4FF),
            .Z = Color.from_u24(0xBDB2FF),
        };
    }

    fn pastel_light() Palette {
        return .{
            .F = Color.from_u24(0x111122),
            .G = Color.from_u24(0x222233),
            .N = Color.from_u24(0xDDDDDA),
            .B = Color.from_u24(0xFFFFFC),
            .I = Color.from_u24(0xFF9DAD),
            .J = Color.from_u24(0xFFC6A5),
            .L = Color.from_u24(0xEDEEA6),
            .O = Color.from_u24(0xBAEEAF),
            .S = Color.from_u24(0x9BE6FF),
            .T = Color.from_u24(0xA0B4FF),
            .Z = Color.from_u24(0xBDA2FF),
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
            .palette = .habamax(),
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

    fn from_piecetype(s: Colorscheme, t: Piecetype) Color {
        return switch (t) {
            Piecetype.none => s.palette.B,
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

    SIZE: u64 = 42,
    BORDER: u64 = 1,
    BSIZE: u64 = 43,

    grid: [ROWS][COLUMNS]Piecetype = @splat(@splat(.none)),

    // dummy placeholders
    current_piece: Piece = .new(.J),
    current_holding: Piecetype = .L,
    current_queue: [4]Piecetype = .{ .O, .S, .T, .Z },

    lines_cleared: u64 = 0,
    pieces_locked: u64 = 0,
    sprint_time: u64 = 0,
    sprint_finished: bool = false,
    current_colorscheme: Colorscheme = .default(),
    current_style: Style = .gridless,
    zigtris_bot: Bot = .{ .state = .off },

    optimal_move: Piece = undefined,
    optimal_score: i32 = undefined,

    game_timer: Timer,
    gravity_timer: Timer,

    moves: ArrayListUnmanaged(Piece),
    stack: ArrayListUnmanaged(Piece),

    xoshiro: Xoshiro256,

    fn new() !Game {
        var moves_buffer: [23]Piece = undefined;
        var stack_buffer: [23]Piece = undefined;
        var g: Game = .{
            .game_timer = try .start(),
            .gravity_timer = try .start(),
            .moves = .initBuffer(&moves_buffer),
            .stack = .initBuffer(&stack_buffer),
            .xoshiro = .init(@intCast(Time.milliTimestamp())),
        };
        g.reset();
        return g;
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
            const ri: u64 = @intCast(p.position.row + dr);
            const ci: u64 = @intCast(p.position.col + dc);
            if (s.grid[ri][ci] != .none) return true;
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
            const ri: u64 = @intCast(p.position.row + dr);
            const ci: u64 = @intCast(p.position.col + dc);
            s.grid[ri][ci] = p.type;
        }
    }

    fn push(s: *Game) void {
        const p = s.current_piece;
        s.stack.appendAssumeCapacity(p);
        const o = Offsets.get(p.type, p.rotation);
        for (o.rows, o.cols) |dr, dc| {
            const ri: u64 = @intCast(p.position.row + dr);
            const ci: u64 = @intCast(p.position.col + dc);
            s.grid[ri][ci] = p.type;
        }

        // shift queue
        s.current_piece = .new(s.current_queue[0]);
        Standard.mem.rotate(Piecetype, &s.current_queue, 1);
    }

    fn pop(s: *Game) void {
        const p = s.stack.pop().?;
        const o = Offsets.get(p.type, p.rotation);
        for (o.rows, o.cols) |dr, dc| {
            const ri: u64 = @intCast(p.position.row + dr);
            const ci: u64 = @intCast(p.position.col + dc);
            s.grid[ri][ci] = .none;
        }

        // unshift queue
        Standard.mem.rotate(Piecetype, &s.current_queue, 3);
        s.current_queue[0] = s.current_piece.type;
        s.current_piece = p;
    }

    fn next_piece(s: *Game) void {
        s.current_piece = .new(s.current_queue[0]);
        Standard.mem.rotate(Piecetype, &s.current_queue, 1);
        s.current_queue[3] = Piecetype.random(s.xoshiro.random());
        if (s.collision()) {
            // game over!
            s.reset();
        }
    }

    fn clear_grid(s: *Game) void {
        for (0..ROWS) |r| {
            for (0..COLUMNS) |c|
                s.grid[r][c] = .none;
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

    fn update_time(s: *Game) void {
        if (!s.sprint_finished) {
            const nanoseconds = s.game_timer.read();
            if (s.lines_cleared < 40) {
                s.sprint_time = nanoseconds / Time.ns_per_s;
            } else {
                s.sprint_finished = true;
                s.sprint_time = nanoseconds / Time.ns_per_ms;
            }
        }
    }

    fn gravity_tick(s: *Game) void {
        s.gravity_timer.reset();
        if (s.move_down()) return;
        s.piece_lock();
    }

    fn hold_piece(s: *Game) void {
        const t = s.current_piece.type;
        s.current_piece = .new(s.current_holding);
        s.current_holding = t;
    }

    fn reset(s: *Game) void {
        s.clear_grid();

        const r = s.xoshiro.random();
        s.current_piece = .new(Piecetype.random(r));
        s.current_holding = Piecetype.random(r);
        s.current_queue = .{
            Piecetype.random(r),
            Piecetype.random(r),
            Piecetype.random(r),
            Piecetype.random(r),
        };

        s.stack.shrinkRetainingCapacity(0);
        s.moves.shrinkRetainingCapacity(0);

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
        const Static = struct {
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
        for (Static.deltas) |delta| {
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

    fn clear_line(s: *Game, r: u64) bool {
        var clear: bool = true;
        for (s.grid[r]) |c| clear = clear and c != .none;
        return clear;
    }

    fn shift_lines(s: *Game, r: u64) void {
        var u: u64 = r;
        while (u != 0) {
            u -= 1;
            for (0..COLUMNS) |c| s.grid[u + 1][c] = s.grid[u][c];
        } else for (0..COLUMNS) |c| s.grid[u][c] = .none;
    }

    fn clear_lines(s: *Game) u8 {
        var cleared: u8 = 0;
        var r: u64 = ROWS - 1;
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
                if (s.grid[r][c] != .none) return @intCast(r);
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
            while (r != ROWS and s.grid[r][c] == .none) : (r += 1) {
                background += 1;
                deepest = @max(deepest, r);
            }
            while (r != ROWS) : (r += 1) {
                if (s.grid[r][c] == .none) holes += 1;
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
            .right, .left => 1,
            else => 0,
        };

        var badness: i32 = 0;
        badness = (badness + metrics.holes) * 8;
        badness = (badness + metrics.background) * 2;
        badness = (badness + metrics.deepest) * 2;
        badness = (badness + piece_placement) * 2;
        badness = (badness + Math.pow(i32, 2, grid_height)) * 2;
        badness = (badness + piece_orientation) * 2;
        return badness;
    }

    fn try_move(s: *Game, badness: i32) void {
        s.soft_drop();
        s.moves.appendAssumeCapacity(s.current_piece);
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
                // the first move in this sequence of
                // moves, is the optimal one a complete
                // re-evaluation of the move-tree is not
                // necessary, and results in an
                // approximately 3 times slower bot
                s.optimal_move = s.moves.items[0];
                s.optimal_score = badness;
            }
            return;
        }

        // only consider meaningful rotations
        switch (s.current_piece.type) {
            .J, .L, .T => {
                s.try_rotations(&[_]Rotation{
                    .none,
                    .right,
                    .spin,
                    .left,
                }, badness);
            },
            .I, .S, .Z => {
                s.try_rotations(&[_]Rotation{
                    .none,
                    .right,
                }, badness);
            },
            .O => {
                s.try_rotations(&[_]Rotation{
                    .none,
                }, badness);
            },
            else => unreachable,
        }
    }

    fn set_optimal_move(s: *Game) void {
        const Static = struct {
            var last_pieces_locked: u64 = undefined;
            var last_piecetype: Piecetype = .none;
            var last_holding: Piecetype = .none;
        };

        if (s.pieces_locked == Static.last_pieces_locked) {
            const lt = Static.last_piecetype;
            const lh = Static.last_holding;
            const ct = s.current_piece.type;
            const ch = s.current_holding;
            if ((lt == ct and lh == ch) or (lt == ch and lh == ct)) return;
        }

        // dirty initialization
        s.optimal_move = s.current_piece;
        s.optimal_score = Math.maxInt(i32);

        Static.last_pieces_locked = s.pieces_locked;
        Static.last_piecetype = s.current_piece.type;
        Static.last_holding = s.current_holding;

        s.least_bad_moves(0);
        s.hold_piece();
        s.least_bad_moves(0);
        s.hold_piece();
    }

    // fully automatic play but with a fixed
    // delay for each action taken
    fn fully_automatic_delayed(s: *Game, comptime DELAY: u64) void {
        const Static = struct {
            var last_time: u64 = 0;
        };

        const time_passed: u64 = s.game_timer.read();
        // reset when game timer has been reset
        if (time_passed <= DELAY) Static.last_time = time_passed;

        const ok = (time_passed - Static.last_time) >= DELAY;
        if (!ok) return;

        const types = s.optimal_move.type != s.current_piece.type;
        if (types) {
            s.hold_piece();
            Static.last_time = time_passed;
            return;
        }

        const rotation = s.current_piece.rotation != s.optimal_move.rotation;
        if (rotation) {
            s.current_piece.rotation = s.optimal_move.rotation;
            Static.last_time = time_passed;
            return;
        }

        const col = s.optimal_move.position.col;
        const right = s.current_piece.position.col < col;
        if (right and s.move_right()) {
            Static.last_time = time_passed;
            return;
        }

        const left = s.current_piece.position.col > col;
        if (left and s.move_left()) {
            Static.last_time = time_passed;
            return;
        }

        s.hard_drop();
        Static.last_time = time_passed;
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
            .slow => s.fully_automatic_delayed(100 * Time.ns_per_ms),
            .medium => s.fully_automatic_delayed(50 * Time.ns_per_ms),
            .fast => s.fully_automatic_fast(),
        }
    }
};

// rigorous testing :^)
// waiting for any specific piece will
// take at most 6 + 6 pieces for
// example, you just got an I, and you
// get all other pieces twice first
// [I] : [J L O S T Z] : [J L O S T Z] : [I]
test "piecetypes are satisfyingly random" {
    const N = Piecetype.iterable.len;
    var seen: [N]u8 = @splat(0);
    var r: Xoshiro256 = .init(0);
    for (1..Math.maxInt(u8)) |i| {
        for (0..N) |_| {
            const t = Piecetype.random(r.random());
            const k = @intFromEnum(t);
            seen[k] += 1;
        }
        for (seen) |b| try Testing.expectEqual(i, b);
    }
}

test "clear lines" {
    var g: Game = try .new();
    const empty: [ROWS][COLUMNS]Piecetype = @splat(@splat(.none));
    for (empty, g.grid) |a, b| try Testing.expectEqual(a, b);
    for (0..ROWS) |r| {
        for (0..COLUMNS) |c| {
            g.grid[r][c] = .O;
        }
    }
    const c = g.clear_lines();
    try Testing.expectEqual(c, 20);
    for (empty, g.grid) |a, b| try Testing.expectEqual(a, b);
}

test "bot speed" {
    var g: Game = try .new();
    g.zigtris_bot.state = .fast;
    // a perfect clear 40-line sprint is 100 pieces
    var usage_moves: u64 = 0;
    var usage_stack: u64 = 0;
    for (0..120) |_| {
        g.fully_automatic();
        g.update_time();
        usage_moves = @max(usage_moves, g.moves.items.len);
        usage_stack = @max(usage_stack, g.stack.items.len);
    }
    // testing seems to happen at debug build speeds
    try Testing.expect(g.sprint_finished);
    try Testing.expect(g.sprint_time < 30 * Time.ns_per_s);
    try Testing.expect(usage_moves < 10);
    try Testing.expect(usage_stack < 10);
}

// simple SDL renderer wrapper
const View = struct {
    var game: *Game = undefined;
    var renderer: ?*SDL.Renderer = null;
    var frame_timer: Timer = undefined;
    var font: ?*TTF.Font = null;

    var last_color: Color = undefined;
    var force_redraw: u8 = 0;

    fn init(g: *Game, r: *SDL.Renderer) !void {
        View.game = g;
        View.renderer = r;
        View.frame_timer = try .start();
        View.update_font() catch unreachable;
    }

    fn next_frame() void {
        View.impl.clear();
        View.impl.draw_grid();
        View.impl.draw_ghost();
        View.impl.draw_current_piece();
        View.impl.draw_queue();
        View.impl.draw_holding();
        View.impl.draw_lines_cleared() catch unreachable;
        View.impl.draw_time_passed() catch unreachable;
        View.impl.show();
        View.frame_timer.reset();
    }

    fn update_font() !void {
        const font_memory = SDL.IOFromConstMem(
            FONT_BYTES,
            FONT_BYTES.len,
        ) orelse {
            SDL.Log("SDL.IOFromConstMem: %s", SDL.GetError());
            return error.SDLInitializationFailed;
        };

        if (!TTF.Init()) {
            SDL.Log("TTF.Init: %s", SDL.GetError());
            return error.SDLInitializationFailed;
        }

        const new_font: *TTF.Font = TTF.OpenFontIO(
            font_memory,
            true,
            @floatFromInt(View.game.SIZE),
        ) orelse {
            SDL.Log("TTF.OpenFontIO: %s", SDL.GetError());
            return error.SDLInitializationFailed;
        };

        TTF.CloseFont(View.font);
        View.font = new_font;
        View.force_redraw = 3;
    }

    const impl = struct {
        fn set_color(c: Color) void {
            View.last_color = c;
            _ = SDL.SetRenderDrawColor(
                View.renderer,
                c.red,
                c.green,
                c.blue,
                0xff,
            );
        }

        fn clear() void {
            set_color(View.game.current_colorscheme.palette.B);
            _ = SDL.RenderClear(View.renderer);
        }

        fn fill_rectangle(
            x: u64,
            y: u64,
            width: u64,
            height: u64,
        ) void {
            var rectangle = SDL.FRect{
                .x = @floatFromInt(x),
                .y = @floatFromInt(y),
                .w = @floatFromInt(width),
                .h = @floatFromInt(height),
            };
            _ = SDL.RenderFillRect(View.renderer, &rectangle);
        }

        fn draw_rectangle(
            x: u64,
            y: u64,
            width: u64,
            height: u64,
        ) void {
            var rectangle = SDL.FRect{
                .x = @floatFromInt(x),
                .y = @floatFromInt(y),
                .w = @floatFromInt(width),
                .h = @floatFromInt(height),
            };
            _ = SDL.RenderRect(View.renderer, &rectangle);
        }

        fn fill_square(x: u64, y: u64) void {
            const B = View.game.BSIZE;
            const S = View.game.SIZE;
            const Q = View.game.SIZE / 4;
            const H = View.game.SIZE / 2;
            switch (View.game.current_style) {
                .solid => fill_rectangle(B + x * B, B + y * B, S, S),
                .gridless => fill_rectangle(B + x * B, B + y * B, S, S),
                .boxes => {
                    const c = View.last_color;
                    fill_rectangle(B + x * B, B + y * B, S, S);
                    set_color(View.game.current_colorscheme.palette.B);
                    fill_rectangle(B + x * B + Q, B + y * B + Q, H, H);
                    set_color(c);
                },
                .edges => draw_rectangle(B + x * B, B + y * B, S, S),
            }
        }

        fn draw_lines_cleared() !void {
            const Static = struct {
                var colorname: Colorscheme.Name = undefined;
                var lines: u64 = 1 << 63;
                var text: ?*SDL.Texture = null;
                var rect: SDL.FRect = undefined;
            };
            const current_lines = View.game.lines_cleared;
            const lines_equal = current_lines == Static.lines;
            const colors_equal =
                Static.colorname == View.game.current_colorscheme.name;
            if (lines_equal and colors_equal) {
                // re-use renderered
                if (View.force_redraw == 0) {
                    _ = SDL.RenderTexture(
                        View.renderer,
                        Static.text,
                        null,
                        &Static.rect,
                    );
                    return;
                }
                View.force_redraw -= 1;
            }

            var buffer: [MAX_LENGTH_U64]u8 = @splat(' ');
            const col_offset = View.game.BSIZE * COLUMNS + 3 * View.game.SIZE;
            const row_offset = View.game.BSIZE * (ROWS - 6);
            _ = Standard.fmt.bufPrint(
                &buffer,
                "{}",
                .{current_lines},
            ) catch unreachable;
            const c = View.game.current_colorscheme.palette.F;
            const color = SDL.Color{
                .r = c.red,
                .g = c.green,
                .b = c.blue,
                .a = 0xff,
            };
            const surface =
                TTF.RenderText_Blended(
                    View.font,
                    &buffer,
                    MAX_LENGTH_U64,
                    color,
                ) orelse {
                    SDL.Log("TTF.RenderText_Blended: %s", SDL.GetError());
                    return error.SDLRenderFailed;
                };
            defer SDL.DestroySurface(surface);
            const text =
                SDL.CreateTextureFromSurface(View.renderer, surface) orelse {
                    SDL.Log("SDL.CreateTextureFromSurface: %s", SDL.GetError());
                    return error.SDLRenderFailed;
                };
            const tw = surface.*.w;
            const th = surface.*.h;
            var r = SDL.FRect{
                .x = @floatFromInt(col_offset),
                .y = @floatFromInt(row_offset),
                .w = @floatFromInt(tw),
                .h = @floatFromInt(th),
            };
            _ = SDL.RenderTexture(View.renderer, text, null, &r);

            // keep previous rendered stuff
            SDL.DestroyTexture(Static.text);
            Static.colorname = View.game.current_colorscheme.name;
            Static.lines = current_lines;
            Static.text = text;
            Static.rect = r;
        }

        // the game is a 40-line sprint + normal game by default, once you
        // clear 40 lines, the time in milliseconds will remain on the screen
        // for the rest of that session, R will reset the game. during the
        // sprint, only seconds will be shown, because seeing milliseconds
        // printed on the screen at all times is very annoying
        fn draw_time_passed() !void {
            const Static = struct {
                var colorname: Colorscheme.Name = undefined;
                var time: u64 = Math.maxInt(u64);
                var text: ?*SDL.Texture = null;
                var rect: SDL.FRect = undefined;
            };

            const current_time = View.game.sprint_time;
            const highlight = View.game.sprint_finished;
            const time_equal = current_time == Static.time;
            const colors_equal =
                Static.colorname == View.game.current_colorscheme.name;
            if (time_equal and colors_equal) {
                // re-use renderered
                if (View.force_redraw == 0) {
                    _ = SDL.RenderTexture(
                        View.renderer,
                        Static.text,
                        null,
                        &Static.rect,
                    );
                    return;
                }
                View.force_redraw -= 1;
            }

            var buffer: [MAX_LENGTH_U64]u8 = @splat(' ');
            const col_offset = View.game.BSIZE * COLUMNS + 3 * View.game.SIZE;
            const row_offset = View.game.BSIZE * (ROWS - 4);
            _ = Standard.fmt.bufPrint(
                &buffer,
                "{}",
                .{current_time},
            ) catch unreachable;
            const c = switch (highlight) {
                false => View.game.current_colorscheme.palette.F,
                true => View.game.current_colorscheme.palette.T,
            };
            const color = SDL.Color{
                .r = c.red,
                .g = c.green,
                .b = c.blue,
                .a = 0xff,
            };
            const surface =
                TTF.RenderText_Blended(
                    View.font,
                    &buffer,
                    MAX_LENGTH_U64,
                    color,
                ) orelse {
                    SDL.Log("TTF.RenderText_Blended: %s", SDL.GetError());
                    return error.SDLRenderFailed;
                };
            defer SDL.DestroySurface(surface);
            const text =
                SDL.CreateTextureFromSurface(View.renderer, surface) orelse {
                    SDL.Log("SDL.CreateTextureFromSurface: %s", SDL.GetError());
                    return error.SDLRenderFailed;
                };
            const tw = surface.*.w;
            const th = surface.*.h;
            var r = SDL.FRect{
                .x = @floatFromInt(col_offset),
                .y = @floatFromInt(row_offset),
                .w = @floatFromInt(tw),
                .h = @floatFromInt(th),
            };
            _ = SDL.RenderTexture(View.renderer, text, null, &r);

            // keep previous rendered stuff
            SDL.DestroyTexture(Static.text);
            Static.colorname = View.game.current_colorscheme.name;
            Static.time = current_time;
            Static.text = text;
            Static.rect = r;
        }

        fn draw_grid() void {
            // basically the outline
            switch (View.game.current_style) {
                .solid => {
                    set_color(View.game.current_colorscheme.palette.F);
                    fill_rectangle(
                        View.game.SIZE,
                        View.game.SIZE,
                        COLUMNS * View.game.BSIZE + View.game.BORDER,
                        ROWS * View.game.BSIZE + View.game.BORDER,
                    );
                },
                else => {
                    set_color(View.game.current_colorscheme.palette.F);
                    fill_rectangle(
                        View.game.SIZE,
                        View.game.SIZE,
                        COLUMNS * View.game.BSIZE + View.game.BORDER,
                        ROWS * View.game.BSIZE + View.game.BORDER,
                    );
                    set_color(View.game.current_colorscheme.palette.B);
                    fill_rectangle(
                        View.game.SIZE + View.game.BORDER,
                        View.game.SIZE + View.game.BORDER,
                        COLUMNS * View.game.BSIZE - View.game.BORDER,
                        ROWS * View.game.BSIZE - View.game.BORDER,
                    );
                },
            }

            const gcc = View.game.current_colorscheme;
            for (0..ROWS) |r| {
                for (0..COLUMNS) |c| {
                    const t = View.game.grid[r][c];
                    const color = gcc.from_piecetype(t);
                    set_color(color);
                    fill_square(c, r);
                }
            }
        }

        fn draw_ghost() void {
            const p = View.game.ghost_drop();
            const piece = View.game.current_piece;
            const t = piece.type;
            const r = piece.rotation;
            const timestamp: f64 = @floatFromInt(Time.milliTimestamp());
            const ratio: u8 =
                @intFromFloat(96 * @abs(@sin(Math.pi * timestamp / 1024)));
            const gcc = View.game.current_colorscheme;
            const piece_color = gcc.from_piecetype(t);
            const background = gcc.palette.B;
            const combined = piece_color.combine(background, ratio);
            set_color(combined);
            draw_tetromino(p.col, p.row, t, r);
        }

        fn draw_current_piece() void {
            const timestamp: f64 = @floatFromInt(Time.milliTimestamp());
            const ratio: u8 =
                @intFromFloat(96 * @abs(@sin(Math.pi * timestamp / 1024)));
            const gcc = View.game.current_colorscheme;
            const piece = View.game.current_piece;
            const piece_color = gcc.from_piecetype(piece.type);
            const foreground = gcc.palette.F;
            const combined = piece_color.combine(foreground, ratio);
            set_color(combined);
            draw_tetromino(
                piece.position.col,
                piece.position.row,
                piece.type,
                piece.rotation,
            );
        }

        fn draw_queue() void {
            const col_offset = COLUMNS + 2;
            const gcc = View.game.current_colorscheme;
            for (View.game.current_queue, 0..) |t, dr| {
                const row_offset: i8 = @intCast(1 + 3 * dr);
                set_color(gcc.from_piecetype(t));
                draw_tetromino(
                    col_offset,
                    row_offset,
                    t,
                    .none,
                );
            }
        }

        fn draw_holding() void {
            const gcc = View.game.current_colorscheme;
            set_color(gcc.from_piecetype(View.game.current_holding));
            const col_offset = COLUMNS + 2;
            const row_offset = 1 + 4 * View.game.current_queue.len;
            draw_tetromino(
                col_offset,
                row_offset,
                View.game.current_holding,
                .none,
            );
        }

        fn draw_tetromino(
            col: i8,
            row: i8,
            t: Piecetype,
            r: Rotation,
        ) void {
            const o = Offsets.get(t, r);
            for (o.rows, o.cols) |dr, dc| {
                const ci: u64 = @intCast(col + dc);
                const ri: u64 = @intCast(row + dr);
                fill_square(ci, ri);
            }
        }

        fn show() void {
            _ = SDL.RenderPresent(View.renderer);
            SDL.Delay(0);
        }
    };
};

const Keyboard = struct {
    const INITIAL_DELAY: u64 = 112 * Time.ns_per_ms;
    const REPEAT_DELAY: u64 = 16 * Time.ns_per_ms;

    var holding: [SDL.SCANCODE_COUNT]bool = @splat(false);
    var repeating = false;

    var keys: [*c]const bool = undefined;
    var timer: Timer = undefined;

    fn init() !void {
        Keyboard.keys = SDL.GetKeyboardState(null);
        Keyboard.timer = try .start();
    }

    fn single(k: SDL.Scancode) bool {
        if (!keys[k]) {
            holding[k] = false;
            return false;
        }

        if (holding[k]) return false;

        holding[k] = true;
        return true;
    }

    fn repeats(k: SDL.Scancode) bool {
        if (!keys[k]) {
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

    fn handle_input(g: *Game, w: *SDL.Window) !bool {
        var event: SDL.Event = undefined;

        while (SDL.PollEvent(&event)) {
            switch (event.type) {
                SDL.EVENT_QUIT => {
                    return true;
                },
                SDL.EVENT_WINDOW_RESIZED => {
                    // we resize based on the smaller dimension, but
                    // keep the width : height ratio into account
                    const d1 = event.window.data1;
                    const d2 = event.window.data2;
                    var width = @divFloor(d1 * RATIO_HEIGHT, RATIO_WIDTH);
                    const height = d2;
                    const dimension: u64 = @intCast(@min(width, height));
                    g.SIZE = (dimension - (g.BORDER * RATIO_HEIGHT)) /
                        RATIO_HEIGHT;
                    width = @divFloor(height, 22) * 18;
                    _ = SDL.SetWindowSize(w, width, height);
                    g.BORDER = @max(g.SIZE / 42, 1);
                    g.BSIZE = g.SIZE + g.BORDER;
                    View.update_font() catch unreachable;
                },
                else => {},
            }
        }

        if (single(SDL.SCANCODE_ESCAPE)) return true;
        if (single(SDL.SCANCODE_F1)) g.zigtris_bot.state = .off;
        if (single(SDL.SCANCODE_F2)) g.zigtris_bot.state = .slow;
        if (single(SDL.SCANCODE_F3)) g.zigtris_bot.state = .medium;
        if (single(SDL.SCANCODE_F4)) g.zigtris_bot.state = .fast;
        if (single(SDL.SCANCODE_TAB)) g.current_colorscheme.next();
        if (single(SDL.SCANCODE_BACKSPACE)) g.current_colorscheme.previous();
        if (single(SDL.SCANCODE_1)) g.current_style = .solid;
        if (single(SDL.SCANCODE_2)) g.current_style = .gridless;
        if (single(SDL.SCANCODE_3)) g.current_style = .boxes;
        if (single(SDL.SCANCODE_4)) g.current_style = .edges;
        if (single(SDL.SCANCODE_R)) _ = g.reset();

        if (g.zigtris_bot.active()) {
            g.fully_automatic();
            return false;
        }

        // Player controls start here.
        if (single(SDL.SCANCODE_RCTRL)) _ = g.hold_piece();
        if (single(SDL.SCANCODE_A)) _ = g.rotate_left();
        if (single(SDL.SCANCODE_D)) _ = g.spin();
        if (single(SDL.SCANCODE_UP)) _ = g.rotate_right();
        if (single(SDL.SCANCODE_DOWN)) _ = g.soft_drop();
        if (single(SDL.SCANCODE_SPACE)) _ = g.hard_drop();

        if (repeats(SDL.SCANCODE_LEFT)) _ = g.move_left();
        if (repeats(SDL.SCANCODE_RIGHT)) _ = g.move_right();

        const left = holding[SDL.SCANCODE_LEFT];
        const right = holding[SDL.SCANCODE_RIGHT];
        repeating = repeating and (left or right);

        return false;
    }
};

pub fn sdl3_game() !void {
    if (!SDL.Init(SDL.INIT_VIDEO)) {
        SDL.Log("SDL.Init: %s", SDL.GetError());
        return error.SDLInitializationFailed;
    }
    defer SDL.Quit();

    const w = block: inline for (.{
        SDL.WINDOW_VULKAN | SDL.WINDOW_RESIZABLE,
        SDL.WINDOW_OPENGL | SDL.WINDOW_RESIZABLE,
        SDL.WINDOW_RESIZABLE,
    }) |flags| {
        const s = SDL.CreateWindow("Zigtris", 774, 946, flags);
        if (s != null) break :block s;
    } else {
        SDL.Log("SDL.CreateWindow: %s", SDL.GetError());
        return error.SDLInitializationFailed;
    };
    defer SDL.DestroyWindow(w);

    const renderer = SDL.CreateRenderer(w, 0) orelse {
        SDL.Log("SDL.CreateRenderer: %s", SDL.GetError());
        return error.SDLInitializationFailed;
    };
    defer SDL.DestroyRenderer(renderer);

    var g: Game = try .new();
    try View.init(&g, renderer);
    try Keyboard.init();

    while (true) {
        const gravity_tick = g.gravity_timer.read() >= GRAVITY_DELAY;
        if (gravity_tick) g.gravity_tick();

        const quit = try Keyboard.handle_input(&g, w.?);
        if (quit) break;
        g.update_time();

        const frame_tick = View.frame_timer.read() >= TARGET_FPS_DELAY;
        if (frame_tick) View.next_frame();

        if (!g.zigtris_bot.active()) SDL.Delay(FRAME_DELAY);
    }

    TTF.CloseFont(View.font);
}
