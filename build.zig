const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigtris = b.addModule("zigtris", .{
        .root_source_file = b.path("src/game.zig"),
        .target = target,
    });

    const sdl = b.addTranslateC(.{
        .root_source_file = b.path("src/c.h"),
        .target = target,
        .optimize = optimize,
    });
    sdl.linkSystemLibrary("SDL3", .{});
    sdl.linkSystemLibrary("SDL3_ttf", .{});
    // sdl.linkSystemLibrary("c", .{});

    const exe = b.addExecutable(.{
        .name = "zigtris",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{
                    .name = "zigtris",
                    .module = zigtris,
                },
                .{
                    .name = "C",
                    .module = sdl.createModule(),
                },
            },
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
