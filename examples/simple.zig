//! Simple Zync-CLI Example - Minimal usage demonstration

const std = @import("std");
const cli = @import("zync-cli");

const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
    cli.option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
    cli.option("count", u32, .{ .short = 'c', .default = 1, .help = "Number of times to greet" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    const args = try Args.parse(arena.allocator());
    
    if (args.verbose) {
        std.debug.print("Verbose mode enabled!\n", .{});
    }
    
    var i: u32 = 0;
    while (i < args.count) : (i += 1) {
        std.debug.print("Hello, {s}!\n", .{args.name});
    }
}