const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const so = b.addSharedLibrary(.{
        .name = "kinetic_kebab",
        .root_source_file = b.path("src/c_abi.zig"),
        .target = target,
        .optimize = optimize,
    });
    so.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "src/3rdparty/" } });
    so.addLibraryPath(.{ .src_path = .{ .owner = b, .sub_path = "src/3rdparty/" } });
    so.linkSystemLibrary("CoolProp");
    so.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(so);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/sim.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "src/_model_tests/" } });
    lib_unit_tests.addIncludePath(.{ .src_path = .{ .owner = b, .sub_path = "src/3rdparty/" } });
    lib_unit_tests.addLibraryPath(.{ .src_path = .{ .owner = b, .sub_path = "src/3rdparty/" } });
    lib_unit_tests.linkSystemLibrary("CoolProp");
    lib_unit_tests.linkLibC();

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
