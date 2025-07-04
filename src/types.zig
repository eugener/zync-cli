//! Core types for the Zync-CLI library
//!
//! This module defines the fundamental types used throughout the library,
//! including error types, diagnostic information, and parse results.

const std = @import("std");

/// Errors that can occur during argument parsing (moved to parser.zig)
pub const ParseError = @import("parser.zig").ParseError;

/// Diagnostic information about parsing issues
pub const Diagnostic = struct {
    /// Severity level of the diagnostic
    level: Level,
    /// Human-readable message describing the issue
    message: []const u8,
    /// Optional suggestion for fixing the issue
    suggestion: ?[]const u8 = null,
    /// Location information if available
    location: ?Location = null,
    
    /// Severity levels for diagnostics
    pub const Level = enum {
        /// Fatal error that prevents parsing
        err,
        /// Warning that doesn't prevent parsing
        warning,
        /// Informational message
        info,
        /// Helpful hint for the user
        hint,
    };
    
    /// Location information for diagnostics
    pub const Location = struct {
        /// Index of the argument in the argv array
        arg_index: usize,
        /// Character index within the argument
        char_index: usize,
    };
};

/// Simple result type - no longer needed with arena allocation
/// Kept for backward compatibility but not used in new API
pub fn ParseResult(comptime T: type) type {
    return struct {
        args: T,
        pub fn deinit(self: *@This()) void {
            _ = self;
        }
    };
}

/// Field metadata extracted from encoded field names
pub const FieldMetadata = struct {
    /// The actual field name (without encoding)
    name: []const u8,
    /// Short flag character (e.g., 'v' for --verbose)
    short: ?u8 = null,
    /// Whether this field is required
    required: bool = false,
    /// Default value as string
    default: ?[]const u8 = null,
    /// Whether this is a positional argument
    positional: bool = false,
    /// Position index for positional arguments
    position: ?usize = null,
    /// Whether this field accepts multiple values
    multiple: bool = false,
    /// Whether this is a counting flag (can be repeated)
    counting: bool = false,
    /// Environment variable name
    env_var: ?[]const u8 = null,
    /// Whether this field is hidden from help
    hidden: bool = false,
    /// Validation constraints
    validator: ?[]const u8 = null,
    /// Available choices for enum-like fields
    choices: ?[]const []const u8 = null,
    /// Aliases for this field
    aliases: ?[]const []const u8 = null,
    /// Help text for this field
    help: ?[]const u8 = null,
};

/// Shell types for completion generation
pub const Shell = enum {
    bash,
    zsh,
    fish,
    powershell,
};

/// Validation result
pub const ValidationResult = union(enum) {
    valid,
    invalid: []const u8, // Error message
};

test "ParseResult basic functionality" {
    const TestArgs = struct {
        verbose: bool = false,
    };
    
    // Test creating a parse result
    var result = ParseResult(TestArgs){
        .args = TestArgs{ .verbose = true },
    };
    
    // Test that it doesn't crash on deinit
    result.deinit();
    
    try std.testing.expect(result.args.verbose == true);
}

test "Diagnostic creation" {
    const diag = Diagnostic{
        .level = .err,
        .message = "Test error",
        .suggestion = "Try --help",
        .location = .{ .arg_index = 1, .char_index = 0 },
    };
    
    try std.testing.expect(diag.level == .err);
    try std.testing.expectEqualStrings(diag.message, "Test error");
}

test "FieldMetadata basic usage" {
    const meta = FieldMetadata{
        .name = "verbose",
        .short = 'v',
        .required = false,
        .help = "Enable verbose output",
    };
    
    try std.testing.expectEqualStrings(meta.name, "verbose");
    try std.testing.expect(meta.short.? == 'v');
    try std.testing.expect(meta.required == false);
}