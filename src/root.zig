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
//!     const args = try zync_cli.parse(Args, arena.allocator(), std.os.argv);
//!     // Use args.verbose and args.input
//! }
//! ```

const std = @import("std");
const testing = std.testing;

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
pub const flag = cli.flag;
pub const option = cli.option;
pub const required = cli.required;
pub const positional = cli.positional;

// Export configuration types
pub const FlagConfig = cli.FlagConfig;
pub const OptionConfig = cli.OptionConfig;
pub const RequiredConfig = cli.RequiredConfig;
pub const PositionalConfig = cli.PositionalConfig;

/// Parse command-line arguments into the specified type
/// Only supports automatic DSL types with ArgsType
pub fn parse(comptime T: type, allocator: std.mem.Allocator, args: []const []const u8) !ParsedType(T) {
    // Only handle automatic DSL types that have ArgsType
    if (@hasDecl(T, "ArgsType")) {
        return parser.parseFromWithMeta(T.ArgsType, T, allocator, args);
    } else {
        @compileError("Only automatic DSL types are supported. Use zync_cli.Args() to create your argument struct.");
    }
}

/// Helper to determine the return type for parsing
fn ParsedType(comptime T: type) type {
    if (@hasDecl(T, "ArgsType")) {
        return T.ArgsType;
    } else {
        @compileError("Only automatic DSL types are supported. Use zync_cli.Args() to create your argument struct.");
    }
}

/// Parse from process arguments
pub fn parseProcess(comptime T: type, allocator: std.mem.Allocator) !ParsedType(T) {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    // Skip the program name (first argument)
    const cli_args = if (args.len > 0) args[1..] else args;
    return parse(T, allocator, cli_args);
}

/// Generate formatted help text for the specified type
pub fn help(comptime T: type, allocator: std.mem.Allocator) ![]const u8 {
    return help_gen.formatHelp(T, allocator, false, null); // Plain text version
}


/// Validate arguments structure at compile time
pub fn validate(comptime T: type) void {
    return meta.validate(T);
}



test "automatic DSL integration" {
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        option("name", []const u8, .{ .short = 'n', .default = "Test", .help = "Set name" }),
        option("count", u32, .{ .short = 'c', .default = 5, .help = "Set count" }),
    });
    
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    // Test parsing with mixed args
    const test_args = &.{"-v", "--name", "Alice", "--count", "10"};
    const result = try parse(TestArgs, arena.allocator(), test_args);
    
    try testing.expect(result.verbose == true);
    try testing.expectEqualStrings(result.name, "Alice");
    try testing.expect(result.count == 10);
    
    // Test help generation
    const help_text = try help(TestArgs, arena.allocator());
    try testing.expect(help_text.len > 0);
}
