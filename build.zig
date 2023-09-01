const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigtris",
        .root_source_file = .{
            .path = "src/main.zig",
        },
        .target = target,
        .optimize = optimize,
    });
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_ttf");
    // exe.linkSystemLibrary("SDL2_mixer");
    exe.linkSystemLibrary("c");

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const main_tests = b.addTest(.{
        .name = "Main",
        .root_source_file = .{
            .path = "src/main.zig",
        },
        .target = target,
        .optimize = optimize,
    });

    const window_tests = b.addTest(.{
        .name = "Window",
        .root_source_file = .{
            .path = "src/window.zig",
        },
        .target = target,
        .optimize = optimize,
    });

    const game_tests = b.addTest(.{
        .name = "Game",
        .root_source_file = .{
            .path = "src/game.zig",
        },
        .target = target,
        .optimize = optimize,
    });

    const definitions_tests = b.addTest(.{
        .name = "Definitions",
        .root_source_file = .{
            .path = "src/definitions.zig",
        },
        .target = target,
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&b.addRunArtifact(main_tests).step);
    test_step.dependOn(&b.addRunArtifact(window_tests).step);
    test_step.dependOn(&b.addRunArtifact(game_tests).step);
    test_step.dependOn(&b.addRunArtifact(definitions_tests).step);
}
