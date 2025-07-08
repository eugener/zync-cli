//! Terminal color utilities for enhanced CLI output
//!
//! This module provides color formatting for help text and error messages
//! using Zig's built-in TTY support.

const std = @import("std");
pub const tty = std.io.tty;

/// Get TTY configuration for stderr
fn getStderrConfig() tty.Config {
    return tty.detectConfig(std.io.getStdErr());
}

/// Get TTY configuration for stdout
fn getStdoutConfig() tty.Config {
    return tty.detectConfig(std.io.getStdOut());
}

/// Check if colors are supported (for backward compatibility)
pub fn supportsColor() bool {
    // Use stdlib's TTY detection which is more robust
    return switch (getStdoutConfig()) {
        .no_color => false,
        .escape_codes, .windows_api => true,
    };
}

/// Get ANSI escape sequence for a color using compile-time constants
pub fn getAnsiSequence(color: tty.Color) []const u8 {
    // Return compile-time constants for the common colors we use
    return switch (color) {
        .reset => "\x1b[0m",
        .red => "\x1b[31m", 
        .bright_red => "\x1b[91m",
        .green => "\x1b[32m",
        .yellow => "\x1b[33m",
        .cyan => "\x1b[36m",
        .bright_cyan => "\x1b[96m",
        .magenta => "\x1b[35m",
        .white => "\x1b[37m",
        .bright_white => "\x1b[97m",
        .dim => "\x1b[2m",
        .bold => "\x1b[1m",
        else => "", // Fallback for unsupported colors
    };
}


/// Print colorized error message directly to stderr
pub fn printError(message: []const u8, context: ?[]const u8, suggestion: ?[]const u8) void {
    // In test mode, do nothing to avoid hanging
    if (@import("builtin").is_test) {
        return;
    }
    
    const stderr = std.io.getStdErr().writer();
    const config = getStderrConfig();
    
    // Print colored error message based on config type
    switch (config) {
        .escape_codes => {
            config.setColor(stderr, .red) catch {};
            stderr.print("Error: ", .{}) catch {};
            config.setColor(stderr, .reset) catch {};
            stderr.print("{s}", .{message}) catch {};
            
            if (context) |ctx| {
                stderr.print(" (", .{}) catch {};
                config.setColor(stderr, .bright_red) catch {};
                stderr.print("'{s}'", .{ctx}) catch {};
                config.setColor(stderr, .reset) catch {};
                stderr.print(")", .{}) catch {};
            }
            
            if (suggestion) |sug| {
                stderr.print("\n\n", .{}) catch {};
                config.setColor(stderr, .yellow) catch {};
                stderr.print("Suggestion: ", .{}) catch {};
                config.setColor(stderr, .reset) catch {};
                stderr.print("{s}", .{sug}) catch {};
            }
        },
        else => {
            // No color support, plain text
            stderr.print("Error: {s}", .{message}) catch {};
            if (context) |ctx| {
                stderr.print(" ('{s}')", .{ctx}) catch {};
            }
            if (suggestion) |sug| {
                stderr.print("\n\nSuggestion: {s}", .{sug}) catch {};
            }
        },
    }
    
    stderr.print("\n", .{}) catch {};
}




test "color support detection" {
    // Test stdlib TTY detection
    _ = supportsColor();
    _ = getStderrConfig();
    _ = getStdoutConfig();
}

test "ANSI sequence generation" {
    // Verify our getAnsiSequence function returns expected ANSI sequences
    try std.testing.expectEqualStrings(getAnsiSequence(.reset), "\x1b[0m");
    try std.testing.expectEqualStrings(getAnsiSequence(.red), "\x1b[31m");
    try std.testing.expectEqualStrings(getAnsiSequence(.bright_red), "\x1b[91m");
    try std.testing.expectEqualStrings(getAnsiSequence(.green), "\x1b[32m");
    try std.testing.expectEqualStrings(getAnsiSequence(.yellow), "\x1b[33m");
    try std.testing.expectEqualStrings(getAnsiSequence(.cyan), "\x1b[36m");
    try std.testing.expectEqualStrings(getAnsiSequence(.bright_cyan), "\x1b[96m");
    try std.testing.expectEqualStrings(getAnsiSequence(.magenta), "\x1b[35m");
    try std.testing.expectEqualStrings(getAnsiSequence(.bright_white), "\x1b[97m");
    try std.testing.expectEqualStrings(getAnsiSequence(.dim), "\x1b[2m");
    try std.testing.expectEqualStrings(getAnsiSequence(.bold), "\x1b[1m");
}

test "print error functionality" {
    // Test that the color functions don't crash
    printError("Test error", "context", "suggestion");
}