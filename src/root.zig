//! Zync-CLI: A comprehensive command-line interface library for Zig
//! 
//! This library provides a powerful and ergonomic way to parse command-line arguments
//! using Zig's compile-time features for zero-runtime overhead.
//!
//! ## Basic Usage
//! ```zig
//! const zync_cli = @import("zync-cli");
//! 
//! const Args = zync_cli.Args(&.{
//!     zync_cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
//!     zync_cli.positional("input", []const u8, .{ .help = "Input file" }),
//! });
//!
//! pub fn main() !void {
//!     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//!     defer arena.deinit();
//!     
//!     // Clean and simple - no boilerplate needed!
//!     const args = try Args.parse(arena.allocator());
//!     // Use args.verbose and args.input
//! }
//! ```

const std = @import("std");
const builtin = @import("builtin");

// Only import testing when running tests
const testing = if (builtin.is_test) std.testing else struct {};

// Core modules
const parser = @import("parser.zig");
const meta = @import("meta.zig");
const help_gen = @import("help.zig");
const cli = @import("cli.zig");

// Re-export commonly used types for convenience
pub const ParseError = parser.ParseError;
pub const FieldMetadata = meta.FieldMetadata;

// Primary DSL API - Zero duplication, automatic metadata extraction
pub const Args = cli.Args;
pub const ArgsConfig = cli.ArgsConfig;
pub const flag = cli.flag;
pub const option = cli.option;
pub const required = cli.required;
pub const positional = cli.positional;

// Subcommand system API
pub const Commands = cli.Commands;
pub const command = cli.command;
pub const CommandConfig = cli.CommandConfig;
pub const CommandDef = cli.CommandDef;
pub const HandlerFn = cli.HandlerFn;

// Export configuration types
pub const FlagConfig = cli.FlagConfig;
pub const OptionConfig = cli.OptionConfig;
pub const RequiredConfig = cli.RequiredConfig;
pub const PositionalConfig = cli.PositionalConfig;




test "automatic DSL integration" {
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        option("name", []const u8, .{ .short = 'n', .default = "Test", .help = "Set name" }),
        option("count", u32, .{ .short = 'c', .default = 5, .help = "Set count" }),
    });
    
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    // Test parsing with mixed args using method-style API
    const test_args = &.{"-v", "--name", "Alice", "--count", "10"};
    const result = try TestArgs.parseFrom(arena.allocator(), test_args);
    
    try testing.expect(result.verbose == true);
    try testing.expectEqualStrings(result.name, "Alice");
    try testing.expect(result.count == 10);
    
    // Test help generation using method-style API
    const help_text = try TestArgs.help(arena.allocator());
    try testing.expect(help_text.len > 0);
    
    // Verify program name is used in help text (not hardcoded "CLI Application")
    try testing.expect(std.mem.indexOf(u8, help_text, "CLI Application") == null);
}
