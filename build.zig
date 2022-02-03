const std = @import("std");
var builder: *std.build.Builder = undefined;

fn myTask(self: *std.build.Step) !void {
    const compile_cmd = builder.addSystemCommand(&[_][]const u8{ "/bin/bash", "-c", "luac inspect.lua main.lua" });
    try compile_cmd.step.make();

    _ = self;
}

pub fn build(b: *std.build.Builder) void {
    builder = b;
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("luac", "wrapper.zig");

    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.linkLibC();
    exe.addIncludeDir("lua-5.3.4/src");

    const lua_c_files = [_][]const u8{
        "lapi.c",
        "lauxlib.c",
        "lbaselib.c",
        "lbitlib.c",
        "lcode.c",
        "lcorolib.c",
        "lctype.c",
        "ldblib.c",
        "ldebug.c",
        "ldo.c",
        "ldump.c",
        "lfunc.c",
        "lgc.c",
        "linit.c",
        "liolib.c",
        "llex.c",
        "lmathlib.c",
        "lmem.c",
        "loadlib.c",
        "lobject.c",
        "lopcodes.c",
        "loslib.c",
        "lparser.c",
        "lstate.c",
        "lstring.c",
        "lstrlib.c",
        "ltable.c",
        "ltablib.c",
        "ltm.c",
        "lundump.c",
        "lutf8lib.c",
        "lvm.c",
        "lzio.c",
    };

    const c_flags = [_][]const u8{
        "-std=c99",
        "-O2",
        "-DLUA_USE_POSIX",
        // "-DLUA_USE_WINDOWS"
    };

    inline for (lua_c_files) |c_file| {
        exe.addCSourceFile("lua-5.3.4/src/" ++ c_file, &c_flags);
    }

    exe.install();

    const step = b.step("task", "do something");
    step.makeFn = myTask;
    b.default_step = step;
    exe.step.dependOn(step);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_tests = b.addTest("src/main.zig");
    exe_tests.setTarget(target);
    exe_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}
