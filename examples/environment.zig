//! Environment Variable Example - Demonstrating env var support

const std = @import("std");
const cli = @import("zync-cli");

const Args = cli.Args(.{
    &.{
        cli.flag("debug", .{ .short = 'd', .help = "Enable debug mode", .env_var = "APP_DEBUG" }),
        cli.option("host", []const u8, .{ .short = 'h', .default = "localhost", .help = "Server host", .env_var = "APP_HOST" }),
        cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Server port", .env_var = "APP_PORT" }),
        cli.option("timeout", u32, .{ .short = 't', .default = 30, .help = "Timeout in seconds", .env_var = "APP_TIMEOUT" }),
        cli.required("api_key", []const u8, .{ .short = 'k', .help = "API key for authentication", .env_var = "APP_API_KEY" }),
    },
    .{
        .title = "Environment Variable Demo",
        .description = "Demonstrates environment variable integration with CLI arguments.",
    },
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    const args = try Args.parse(arena.allocator());
    
    std.debug.print("Configuration:\n", .{});
    std.debug.print("  Debug: {}\n", .{args.debug});
    std.debug.print("  Host: {s}\n", .{args.host});
    std.debug.print("  Port: {}\n", .{args.port});
    std.debug.print("  Timeout: {}s\n", .{args.timeout});
    std.debug.print("  API Key: {s}\n", .{args.api_key});
    
    if (args.debug) {
        std.debug.print("\nTry these commands:\n", .{});
        std.debug.print("  APP_DEBUG=true APP_HOST=api.example.com APP_API_KEY=secret ./environment\n", .{});
        std.debug.print("  APP_PORT=3000 ./environment --api-key mykey --debug\n", .{});
    }
}