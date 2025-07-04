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
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // Parse command line arguments
    const args = zync_cli.parseProcess(Args, arena.allocator()) catch |err| switch (err) {
        error.UnknownFlag, error.MissingValue, error.InvalidValue => {
            std.debug.print("Error parsing arguments. Use --help for usage information.\n", .{});
            return;
        },
        else => return err,
    };
    
    // Handle help flag
    if (args.@"help|h") {
        const help_text = zync_cli.help(Args);
        std.debug.print("{s}\n", .{help_text});
        return;
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
    _ = zync_cli.Parser;
    _ = zync_cli.parse;
    _ = zync_cli.help;
}

test "demo CLI parsing" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    // Test basic parsing with required config field
    const result = try zync_cli.parse(Args, arena.allocator(), &.{"--name", "Test", "-v", "--config", "test.conf"});
    
    try std.testing.expectEqualStrings(result.@"name|n=World", "Test");
    try std.testing.expect(result.@"verbose|v" == true);
    try std.testing.expect(result.@"count|c=1" == 1); // default value applied
    try std.testing.expect(result.@"port|p=8080" == 8080); // default value applied
}
