//! Zync-CLI Demo Application - Automatic DSL with Zero Duplication

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const cli = @import("zync_cli_lib");

// Clean, automatic DSL - NO explicit metadata declarations needed!
// All metadata automatically extracted from field definitions
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
    cli.option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
    cli.option("count", u32, .{ .short = 'c', .default = 1, .help = "Number of times to greet" }),
    cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port number to listen on" }),
    cli.required("config", []const u8, .{ .short = 'f', .help = "Configuration file path" }),
    cli.positional("input", []const u8, .{ .default = "stdin", .required = false, .help = "Input file to process" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const args = cli.parseProcess(Args, arena.allocator()) catch |err| switch (err) {
        error.HelpRequested => {
            // Help was automatically displayed by the parser
            return;
        },
        else => {
            // Error was already printed by the parser, just exit with error code
            std.process.exit(1);
        },
    };

    if (args.verbose) {
        std.debug.print("Verbose mode enabled\n", .{});
        std.debug.print("Arguments parsed successfully:\n", .{});
        std.debug.print("  name: {s}\n", .{args.name});
        std.debug.print("  count: {}\n", .{args.count});
        std.debug.print("  port: {}\n", .{args.port});
        std.debug.print("  config: {s}\n", .{args.config});
        std.debug.print("  input: {s}\n", .{args.input});
    }

    var i: u32 = 0;
    while (i < args.count) : (i += 1) {
        std.debug.print("Hello, {s}!\n", .{args.name});
    }

    if (args.verbose) {
        std.debug.print("\n🚀 Automatic DSL with zero duplication!\n", .{});
        std.debug.print("✨ Metadata extracted automatically from field definitions!\n", .{});
        std.debug.print("🎯 Single source of truth - clean and simple!\n", .{});
    }
}
