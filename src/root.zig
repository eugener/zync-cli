//! Zync-CLI: A comprehensive command-line interface library for Zig
//! 
//! This library provides a powerful and ergonomic way to parse command-line arguments
//! using Zig's compile-time features for zero-runtime overhead.
//!
//! ## Basic Usage
//! ```zig
//! const zync_cli = @import("zync-cli");
//! 
//! const Args = struct {
//!     @"verbose|v": bool = false,
//!     @"#input": []const u8,
//! };
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

// Re-export commonly used types for convenience
pub const ParseError = parser.ParseError;
pub const FieldMetadata = meta.FieldMetadata;

/// Parse command-line arguments into the specified type
/// Uses arena allocation for simple memory management
pub fn parse(comptime T: type, allocator: std.mem.Allocator, args: []const []const u8) !T {
    return Parser(T).parse(allocator, args);
}

/// Parse from process arguments
pub fn parseProcess(comptime T: type, allocator: std.mem.Allocator) !T {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    // Skip the program name (first argument)
    const cli_args = if (args.len > 0) args[1..] else args;
    return parse(T, allocator, cli_args);
}

/// Generate formatted help text for the specified type
pub fn help(comptime T: type, allocator: std.mem.Allocator) ![]const u8 {
    return help_gen.formatHelp(T, allocator, false); // Plain text version
}

/// Generate help text for the specified type (backwards compatibility)
pub fn helpBasic(comptime T: type) []const u8 {
    return help_gen.generate(T);
}

/// Validate arguments structure at compile time
pub fn validate(comptime T: type) void {
    return meta.validate(T);
}

/// Type-specific parser with compile-time optimization
pub fn Parser(comptime T: type) type {
    return struct {
        const Self = @This();
        const fields = meta.extractFields(T);
        
        /// Parse arguments into the specified type
        pub fn parse(allocator: std.mem.Allocator, args: []const []const u8) !T {
            return parser.parseFrom(T, allocator, args);
        }
        
        /// Generate formatted help text for this type
        pub fn help(allocator: std.mem.Allocator) ![]const u8 {
            return help_gen.formatHelp(T, allocator, false);
        }
        
        /// Generate basic help text for this type (backwards compatibility)
        pub fn helpBasic() []const u8 {
            return help_gen.generate(T);
        }
        
        /// Get field metadata for this type
        pub fn getFields() []const FieldMetadata {
            return fields;
        }
    };
}

// Basic test to ensure library compiles
test "library compiles" {
    // Just test that the library compiles
    _ = Parser;
}

test "simplified API works" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"name|n=Test": []const u8 = "",
    };
    
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--verbose", "--name", "Alice"};
    
    // Test new simplified API
    const result = try parse(TestArgs, arena.allocator(), test_args);
    
    try testing.expect(result.@"verbose|v" == true);
    try testing.expectEqualStrings(result.@"name|n=Test", "Alice");
}

test "Parser type works" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"count|c=5": u32 = 0,
    };
    
    var arena = std.heap.ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--verbose", "--count", "10"};
    
    // Test Parser type
    const result = try Parser(TestArgs).parse(arena.allocator(), test_args);
    
    try testing.expect(result.@"verbose|v" == true);
    try testing.expect(result.@"count|c=5" == 10);
    
    // Test help generation (backwards compatibility)
    const help_text = Parser(TestArgs).helpBasic();
    try testing.expect(help_text.len > 0);
}
