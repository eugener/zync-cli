//! Core types for the Zync-CLI library
//!
//! This module defines the fundamental types used throughout the library,
//! including error types, diagnostic information, and parse results.

const std = @import("std");

/// Errors that can occur during argument parsing
pub const ParseError = error{
    /// Unknown command-line flag was encountered
    UnknownFlag,
    /// A required argument was not provided
    MissingRequiredArgument,
    /// A flag that requires a value was not given one
    MissingValue,
    /// An invalid value was provided for a flag
    InvalidValue,
    /// Too many positional arguments were provided
    TooManyPositionalArgs,
    /// Not enough positional arguments were provided
    NotEnoughPositionalArgs,
    /// Memory allocation failed
    OutOfMemory,
    /// Help was requested and displayed
    HelpRequested,
};

/// Location information for errors and diagnostics
pub const Location = struct {
    /// Index of the argument in the argv array
    arg_index: usize,
    /// Character index within the argument
    char_index: usize,
};

/// Detailed error information for parsing failures
pub const DetailedParseError = struct {
    /// The basic error type
    error_type: ParseError,
    /// Detailed human-readable message
    message: []const u8,
    /// The problematic argument or flag
    context: ?[]const u8 = null,
    /// Suggestion for fixing the issue
    suggestion: ?[]const u8 = null,
    /// Available alternatives (for unknown flags)
    alternatives: ?[]const []const u8 = null,
    /// Location information if available
    location: ?Location = null,
    
    /// Format the error as a complete message
    pub fn format(self: DetailedParseError, allocator: std.mem.Allocator) ![]const u8 {
        var parts = std.ArrayList([]const u8).init(allocator);
        defer parts.deinit();
        
        // Add main error message
        try parts.append(self.message);
        
        // Add context if available
        if (self.context) |ctx| {
            const context_msg = try std.fmt.allocPrint(allocator, " ('{s}')", .{ctx});
            try parts.append(context_msg);
        }
        
        // Add suggestion if available
        if (self.suggestion) |suggestion| {
            const suggestion_msg = try std.fmt.allocPrint(allocator, "\n\nSuggestion: {s}", .{suggestion});
            try parts.append(suggestion_msg);
        }
        
        // Add alternatives if available
        if (self.alternatives) |alts| {
            if (alts.len > 0) {
                const alt_header = "\n\nDid you mean one of these?";
                try parts.append(alt_header);
                for (alts) |alt| {
                    const alt_msg = try std.fmt.allocPrint(allocator, "\n  --{s}", .{alt});
                    try parts.append(alt_msg);
                }
            }
        }
        
        return try std.mem.join(allocator, "", parts.items);
    }
};

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
};


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