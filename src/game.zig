const std = @import("std");
const definitions = @import("definitions.zig");

// the game (you just lost)
pub const ROWS: u8 = 20;
pub const COLUMNS: u8 = 10;

const Piece = definitions.Piece;
const PieceType = definitions.PieceType;
const Rotation = definitions.Rotation;

const Color = definitions.Color;
const Colorname = definitions.Colorname;
const Colorscheme = definitions.Colorscheme;
const Style = definitions.Style;

const MinMaxRC = definitions.MinMaxRC;
const Delta = definitions.Delta;
const Metrics = definitions.Metrics;

const ENABLE_BOT_DELAY = false;
const BOT_DELAY = 50 * std.time.ns_per_ms;

// beautiful idiomatic global state variables
pub const G = struct {
    pub var column: i8 = @divFloor(COLUMNS, 2) - 2;
    pub var xoshiro: std.rand.Xoshiro256 = undefined;
    pub var rngesus: std.rand.Random = undefined;

    pub var SIZE: usize = 42;
    pub var BORDER: usize = 1;
    pub var BSIZE: usize = 43;

    pub var Grid: [ROWS][COLUMNS]PieceType = undefined;

    pub var game_timer: std.time.Timer = undefined;
    pub var gravity_timer: std.time.Timer = undefined;

    // dummy placeholders
    pub var current_piece: Piece = undefined;
    pub var current_holding: PieceType = undefined;
    pub var current_queue: [4]PieceType = undefined;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();
    var stack = std.ArrayList(Piece).init(allocator);

    pub var lines_cleared: u64 = undefined;
    pub var pieces_locked: u64 = undefined;
    pub var sprint_time: u64 = undefined;
    pub var sprint_finished: bool = undefined;
    pub var current_colorscheme: Colorscheme = Colorscheme.default();
    pub var current_style: Style = undefined;
    pub var zigtris_bot: bool = false;

    var optimal_move: Piece = undefined;
    var optimal_score: i32 = undefined;
    var moves = std.ArrayList(Piece).init(G.allocator);
};

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
    const data = PieceType.piecetype_rotation_matrix(
        G.current_piece.type,
        G.current_piece.rotation,
    );
    for (data, 0..) |drow, dr| {
        for (drow, 0..) |e, dc| {
            if (e != B) {
                const c = @as(usize, @intCast(col + @as(i8, @intCast(dc))));
                const r = @as(usize, @intCast(row + @as(i8, @intCast(dr))));
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

fn materialize() void {
    const data = PieceType.piecetype_rotation_matrix(
        G.current_piece.type,
        G.current_piece.rotation,
    );
    const col = G.current_piece.col;
    const row = G.current_piece.row;
    for (data, 0..) |drow, dr| {
        for (drow, 0..) |e, dc| {
            if (e != PieceType.None) {
                const c = @as(usize, @intCast(col + @as(i8, @intCast(dc))));
                const r = @as(usize, @intCast(row + @as(i8, @intCast(dr))));
                G.Grid[r][c] = e;
            }
        }
    }
}

fn push() void {
    G.stack.append(G.current_piece) catch unreachable;
    const data = PieceType.piecetype_rotation_matrix(
        G.current_piece.type,
        G.current_piece.rotation,
    );
    const col = G.current_piece.col;
    const row = G.current_piece.row;
    for (data, 0..) |drow, dr| {
        for (drow, 0..) |e, dc| {
            if (e != PieceType.None) {
                const c = @as(usize, @intCast(col + @as(i8, @intCast(dc))));
                const r = @as(usize, @intCast(row + @as(i8, @intCast(dr))));
                G.Grid[r][c] = e;
            }
        }
    }

    // shift queue
    G.current_piece = Piece.from_piecetype(G.current_queue[0], G.column);
    G.current_queue[0] = G.current_queue[1];
    G.current_queue[1] = G.current_queue[2];
    G.current_queue[2] = G.current_queue[3];
}

fn pop() void {
    if (G.stack.items.len == 0) {
        unreachable;
    }
    const piece = G.stack.pop();
    const data = PieceType.piecetype_rotation_matrix(
        piece.type,
        piece.rotation,
    );
    const B = PieceType.None;
    const col = piece.col;
    const row = piece.row;
    for (data, 0..) |drow, dr| {
        for (drow, 0..) |e, dc| {
            if (e != PieceType.None) {
                const c = @as(usize, @intCast(col + @as(i8, @intCast(dc))));
                const r = @as(usize, @intCast(row + @as(i8, @intCast(dr))));
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
    G.current_piece = Piece.from_piecetype(G.current_queue[0], G.column);
    G.current_queue[0] = G.current_queue[1];
    G.current_queue[1] = G.current_queue[2];
    G.current_queue[2] = G.current_queue[3];
    G.current_queue[3] = random_piecetype();
    if (collision()) {
        // game over!
        reset_game();
    }
}

fn clear_grid() void {
    for (G.Grid, 0..) |Row, r| {
        for (Row, 0..) |_, c| {
            G.Grid[r][c] = PieceType.None;
        }
    }
}

fn piece_lock() void {
    materialize();
    G.pieces_locked += 1;
    G.lines_cleared += clear_lines();
    next_piece();
}

pub fn move_left() bool {
    return move_delta(Delta{ .row = 0, .col = -1 });
}

pub fn move_right() bool {
    return move_delta(Delta{ .row = 0, .col = 1 });
}

pub fn move_down() bool {
    return move_delta(Delta{ .row = 1, .col = 0 });
}

pub fn gravity_tick() void {
    if (move_down()) {
        return;
    }
    piece_lock();
}

// :^)
fn move_up() bool {
    return move_delta(Delta{ .row = -1, .col = 0 });
}

pub fn hold_piece() void {
    const t = G.current_piece.type;
    G.current_piece = Piece.from_piecetype(G.current_holding, G.column);
    G.current_holding = t;
}

pub fn reset_game() void {
    clear_grid();

    G.pieces_locked = 0;
    G.lines_cleared = 0;

    G.current_piece = Piece.from_piecetype(random_piecetype(), G.column);
    G.current_holding = random_piecetype();
    G.current_queue[0] = random_piecetype();
    G.current_queue[1] = random_piecetype();
    G.current_queue[2] = random_piecetype();
    G.current_queue[3] = random_piecetype();

    G.stack.shrinkRetainingCapacity(0);

    G.game_timer.reset();

    G.sprint_time = undefined;
    G.sprint_finished = false;
}

pub fn ghost_drop() i8 {
    const backup_row = G.current_piece.row;
    while (move_down()) {}
    const ghost_row = G.current_piece.row;
    G.current_piece.row = backup_row;
    return ghost_row;
}

pub fn hard_drop() void {
    soft_drop();
    piece_lock();
}

pub fn soft_drop() void {
    while (move_down()) {}
}

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

pub fn rotate_right() void {
    const r = G.current_piece.rotation;
    G.current_piece.rotation = r.rotate_right();
    if (!unstuck()) {
        G.current_piece.rotation = r;
    }
}

pub fn rotate_left() void {
    const r = G.current_piece.rotation;
    G.current_piece.rotation = r.rotate_left();
    if (!unstuck()) {
        G.current_piece.rotation = r;
    }
}

pub fn rotate_spin() void {
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
            deepest = @max(deepest, r);
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
    const grid_height = @as(i8, @intCast(ROWS - row_start));
    const piece_placement = @as(i8, @intCast(ROWS)) - placed.row;
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
    soft_drop();
    G.moves.append(G.current_piece) catch unreachable;
    push();
    const b = compute_score(G.current_piece);
    least_bad_moves(@divFloor(badness + b, 2));
    pop();
    _ = G.moves.pop();
}

fn try_rotations(comptime rotations: []const Rotation, badness: i32) void {
    const current_piece_backup = G.current_piece;
    for (rotations) |rot| {
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
    switch (G.current_piece.type) {
        .J, .L, .T => {
            try_rotations(&[_]Rotation{
                .None,
                .Right,
                .Spin,
                .Left,
            }, badness);
        },
        .I, .S, .Z => {
            try_rotations(&[_]Rotation{
                .None,
                .Right,
            }, badness);
        },
        .O => {
            try_rotations(&[_]Rotation{
                .None,
            }, badness);
        },
        else => unreachable,
    }
}

fn set_optimal_move() void {
    const S = struct {
        var last_pieces_locked: u64 = undefined;
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

    // dirty initialization
    G.optimal_move = G.current_piece;
    G.optimal_score = std.math.maxInt(i32);

    S.last_pieces_locked = G.pieces_locked;
    S.last_piecetype = G.current_piece.type;
    S.last_holding = G.current_holding;

    least_bad_moves(0);
    hold_piece();
    least_bad_moves(0);
    hold_piece();
}

fn fully_automatic_delayed() void {
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
}

fn fully_automatic_fast() void {
    if (G.optimal_move.type != G.current_piece.type) {
        hold_piece();
    }

    G.current_piece.rotation = G.optimal_move.rotation;
    while (G.current_piece.col < G.optimal_move.col and move_right()) {}
    while (G.current_piece.col > G.optimal_move.col and move_left()) {}
    hard_drop();
}

pub fn fully_automatic() void {
    set_optimal_move();
    if (comptime ENABLE_BOT_DELAY) {
        fully_automatic_delayed();
    } else {
        fully_automatic_fast();
    }
}

fn random_piecetype() PieceType {
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

// rigorous testing :^)
test "clear lines" {
    var c: u8 = 0;
    clear_grid();
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
    G.xoshiro = std.rand.DefaultPrng.init(@as(
        u64,
        @intCast(std.time.milliTimestamp()),
    ));
    G.rngesus = G.xoshiro.random();
    var seen: [PieceType.iter.len]u8 = .{0} ** PieceType.iter.len;

    // first round
    var take: usize = 0;
    while (take < PieceType.iter.len) : (take += 1) {
        const t = random_piecetype();
        const i = PieceType.iter_index(t);
        seen[i] += 1;
    }

    for (seen) |b| {
        try std.testing.expectEqual(b, 1);
    }

    // second round
    take = 0;
    while (take < PieceType.iter.len) : (take += 1) {
        const t = random_piecetype();
        const i = PieceType.iter_index(t);
        seen[i] += 1;
    }

    for (seen) |b| {
        try std.testing.expectEqual(b, 2);
    }
}
