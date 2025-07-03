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
//!     const args = try zync_cli.parse(Args, std.heap.page_allocator);
//!     defer args.deinit();
//!     // Use args.verbose and args.input
//! }
//! ```

const std = @import("std");
const testing = std.testing;

// Core types and functionality
pub const types = @import("types.zig");
pub const parser = @import("parser.zig");
pub const meta = @import("meta.zig");
pub const help_gen = @import("help.zig");

// Re-export commonly used types for convenience
pub const ParseResult = types.ParseResult;
pub const Diagnostic = types.Diagnostic;
pub const ParseError = types.ParseError;

// Direct exports for improved ergonomics
/// Parse command-line arguments into the specified type
pub fn parse(comptime T: type, allocator: std.mem.Allocator) !ParseResult(T) {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    return parseFrom(T, allocator, args);
}

/// Parse from custom argument array
pub fn parseFrom(comptime T: type, allocator: std.mem.Allocator, args: []const []const u8) !ParseResult(T) {
    return parser.parseFrom(T, allocator, args);
}

/// Generate help text for the specified type
pub fn help(comptime T: type) []const u8 {
    return help_gen.generate(T);
}

/// Validate arguments structure at compile time
pub fn validate(comptime T: type) void {
    return meta.validate(T);
}

/// Legacy CLI parsing interface (for backward compatibility)
pub const cli = struct {
    /// Parse command-line arguments into the specified type
    pub fn parse(comptime T: type, allocator: std.mem.Allocator) !ParseResult(T) {
        const args = try std.process.argsAlloc(allocator);
        defer std.process.argsFree(allocator, args);
        return parser.parseFrom(T, allocator, args);
    }
    
    /// Parse from custom argument array
    pub fn parseFrom(comptime T: type, allocator: std.mem.Allocator, args: []const []const u8) !ParseResult(T) {
        return parser.parseFrom(T, allocator, args);
    }
    
    /// Generate help text for the specified type
    pub fn help(comptime T: type) []const u8 {
        return help_gen.generate(T);
    }
    
    /// Validate arguments structure at compile time
    pub fn validate(comptime T: type) void {
        return meta.validate(T);
    }
};

// Basic test to ensure library compiles
test "library compiles" {
    // Just test that the library compiles
    _ = cli;
}

test "API ergonomics - both old and new APIs work" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"name|n=Test": []const u8 = "",
    };
    
    const allocator = testing.allocator;
    const test_args = &.{"test", "--verbose", "--name", "Alice"};
    
    // Test new ergonomic API
    var result1 = try parseFrom(TestArgs, allocator, test_args);
    defer result1.deinit();
    
    try testing.expect(result1.args.@"verbose|v" == true);
    try testing.expectEqualStrings(result1.args.@"name|n=Test", "Alice");
    
    // Test old API for backward compatibility
    var result2 = try cli.parseFrom(TestArgs, allocator, test_args);
    defer result2.deinit();
    
    try testing.expect(result2.args.@"verbose|v" == true);
    try testing.expectEqualStrings(result2.args.@"name|n=Test", "Alice");
}
