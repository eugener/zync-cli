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

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Create the library (no demo/example dependencies)
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zync_cli",
        .root_module = lib_mod,
    });

    // Install the library
    b.installArtifact(lib);

    // Create example executables
    const examples = [_]struct { name: []const u8, file: []const u8 }{
        .{ .name = "basic", .file = "examples/basic.zig" },
        .{ .name = "simple", .file = "examples/simple.zig" },
        .{ .name = "environment", .file = "examples/environment.zig" },
        .{ .name = "commands", .file = "examples/commands.zig" },
    };

    inline for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_source_file = b.path(example.file),
            .target = target,
            .optimize = optimize,
        });
        exe.root_module.addImport("zync-cli", lib_mod);
        
        const install_step = b.addInstallArtifact(exe, .{
            .dest_dir = .{ .override = .{ .custom = "examples" } },
        });
        
        const run_step = b.addRunArtifact(exe);
        run_step.has_side_effects = true;
        if (b.args) |args| {
            run_step.addArgs(args);
        }
        
        const step_name = b.fmt("run-{s}", .{example.name});
        const step_desc = b.fmt("Run the {s} example", .{example.name});
        const run_example_step = b.step(step_name, step_desc);
        run_example_step.dependOn(&run_step.step);
        
        const install_name = b.fmt("install-{s}", .{example.name});
        const install_desc = b.fmt("Install the {s} example", .{example.name});
        const install_example_step = b.step(install_name, install_desc);
        install_example_step.dependOn(&install_step.step);
    }

    // Default run step runs the basic example
    const basic_exe = b.addExecutable(.{
        .name = "basic",
        .root_source_file = b.path("examples/basic.zig"),
        .target = target,
        .optimize = optimize,
    });
    basic_exe.root_module.addImport("zync-cli", lib_mod);
    
    const run_basic = b.addRunArtifact(basic_exe);
    run_basic.has_side_effects = true;
    if (b.args) |args| {
        run_basic.addArgs(args);
    }
    
    const run_step = b.step("run", "Run the basic example");
    run_step.dependOn(&run_basic.step);


    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Individual module tests
    const parser_tests = b.addTest(.{
        .root_source_file = b.path("src/parser.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const types_tests = b.addTest(.{
        .root_source_file = b.path("src/types.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const meta_tests = b.addTest(.{
        .root_source_file = b.path("src/meta.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const help_tests = b.addTest(.{
        .root_source_file = b.path("src/help.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    const testing_tests = b.addTest(.{
        .root_source_file = b.path("src/testing.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Test runners for individual modules
    const run_parser_tests = b.addRunArtifact(parser_tests);
    const run_types_tests = b.addRunArtifact(types_tests);
    const run_meta_tests = b.addRunArtifact(meta_tests);
    const run_help_tests = b.addRunArtifact(help_tests);
    const run_testing_tests = b.addRunArtifact(testing_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_parser_tests.step);
    test_step.dependOn(&run_types_tests.step);
    test_step.dependOn(&run_meta_tests.step);
    test_step.dependOn(&run_help_tests.step);
    test_step.dependOn(&run_testing_tests.step);

    // Individual test steps for selective testing
    const test_parser_step = b.step("test-parser", "Run parser module tests");
    test_parser_step.dependOn(&run_parser_tests.step);
    
    const test_types_step = b.step("test-types", "Run types module tests");
    test_types_step.dependOn(&run_types_tests.step);
    
    const test_meta_step = b.step("test-meta", "Run meta module tests");
    test_meta_step.dependOn(&run_meta_tests.step);
    
    const test_help_step = b.step("test-help", "Run help module tests");
    test_help_step.dependOn(&run_help_tests.step);
    
    const test_testing_step = b.step("test-testing", "Run testing module tests");
    test_testing_step.dependOn(&run_testing_tests.step);
}
