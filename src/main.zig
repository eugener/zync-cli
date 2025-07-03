//! Demo application for the Zync-CLI library

const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const zync_cli = @import("zync_cli_lib");

// Define our CLI arguments structure
const Args = struct {
    @"verbose|v": bool = false,
    @"name|n=World": []const u8 = "",
    @"count|c=1": u32 = 0,
    @"port|p=8080": u16 = 0,
    @"help|h": bool = false,
    @"config|f!": []const u8 = "", // Required config file
    
    pub const cli = .{
        .name = "zync-cli-demo",
        .version = "0.1.0",
        .description = "A demonstration of the Zync-CLI library",
        .examples = &.{
            .{ .desc = "Basic usage", .cmd = "zync-cli-demo --name Alice" },
            .{ .desc = "With verbose output", .cmd = "zync-cli-demo -v --count 3" },
        },
    };
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Parse command line arguments
    var result = zync_cli.cli.parse(Args, allocator) catch |err| switch (err) {
        error.UnknownFlag, error.MissingValue, error.InvalidValue => {
            std.debug.print("Error parsing arguments. Use --help for usage information.\n", .{});
            return;
        },
        else => return err,
    };
    defer result.deinit();
    
    const args = result.args;
    
    // Handle help flag
    if (args.@"help|h") {
        const help_text = zync_cli.cli.help(Args);
        std.debug.print("{s}\n", .{help_text});
        return;
    }
    
    // Print any diagnostics (warnings, etc.)
    for (result.diagnostics) |diagnostic| {
        switch (diagnostic.level) {
            .warning => std.debug.print("Warning: {s}\n", .{diagnostic.message}),
            .info => std.debug.print("Info: {s}\n", .{diagnostic.message}),
            .hint => std.debug.print("Hint: {s}\n", .{diagnostic.message}),
            .err => std.debug.print("Error: {s}\n", .{diagnostic.message}),
        }
    }
    
    // Use the parsed arguments
    if (args.@"verbose|v") {
        std.debug.print("Verbose mode enabled\n", .{});
        std.debug.print("Arguments parsed successfully:\n", .{});
        std.debug.print("  name: {s}\n", .{args.@"name|n=World"});
        std.debug.print("  count: {d}\n", .{args.@"count|c=1"});
        std.debug.print("  port: {d}\n", .{args.@"port|p=8080"});
        std.debug.print("  config: {s}\n", .{args.@"config|f!"});
    }
    
    // Demonstrate the functionality
    var i: u32 = 0;
    while (i < args.@"count|c=1") : (i += 1) {
        std.debug.print("Hello, {s}!\n", .{args.@"name|n=World"});
    }
}

test "basic library usage" {
    // Test that we can import and use the library
    _ = zync_cli.cli;
    _ = zync_cli.types;
    _ = zync_cli.parser;
    _ = zync_cli.meta;
}

test "demo CLI parsing" {
    const allocator = std.testing.allocator;
    
    // Test basic parsing with required config field
    var result = try zync_cli.cli.parseFrom(Args, allocator, &.{"demo", "--name", "Test", "-v", "--config", "test.conf"});
    defer result.deinit();
    
    try std.testing.expectEqualStrings(result.args.@"name|n=World", "Test");
    try std.testing.expect(result.args.@"verbose|v" == true);
    try std.testing.expect(result.args.@"count|c=1" == 1); // default value applied
    try std.testing.expect(result.args.@"port|p=8080" == 8080); // default value applied
}
