//! Zync-CLI: A comprehensive command-line interface library for Zig
//! 
//! This library provides a powerful and ergonomic way to parse command-line arguments
//! using Zig's compile-time features for zero-runtime overhead.
//!
//! ## Basic Usage
//! ```zig
//! const Args = struct {
//!     @"verbose|v": bool = false,
//!     @"#input": []const u8,
//! };
//!
//! pub fn main() !void {
//!     const args = try cli.parse(Args, std.heap.page_allocator);
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

/// Main CLI parsing interface
pub const cli = struct {
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
};

// Basic test to ensure library compiles
test "library compiles" {
    // Just test that the library compiles
    _ = cli;
}
