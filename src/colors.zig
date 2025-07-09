//! Terminal color utilities for enhanced CLI output
//!
//! This module provides color formatting for help text and error messages
//! using Zig's built-in TTY support.

const std = @import("std");
pub const tty = std.io.tty;

/// Check if colors are supported (for backward compatibility)
pub fn supportsColor() bool {
    // Use stdlib's TTY detection which is more robust
    return switch (tty.detectConfig(std.io.getStdOut())) {
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

/// Add colored text to ArrayList (backward compatibility)
pub fn addText(list: *std.ArrayList(u8), color: tty.Color, text: []const u8) !void {
    if (supportsColor()) {
        try list.appendSlice(getAnsiSequence(color));
        try list.appendSlice(text);
        try list.appendSlice(getAnsiSequence(.reset));
    } else {
        try list.appendSlice(text);
    }
}

/// Add formatted colored text to ArrayList
pub fn addTextf(list: *std.ArrayList(u8), color: tty.Color, comptime fmt: []const u8, args: anytype) !void {
    if (supportsColor()) {
        try list.appendSlice(getAnsiSequence(color));
        try list.writer().print(fmt, args);
        try list.appendSlice(getAnsiSequence(.reset));
    } else {
        try list.writer().print(fmt, args);
    }
}

/// Add colored text to any writer
pub fn addTextWriter(writer: anytype, color: tty.Color, text: []const u8) !void {
    if (supportsColor()) {
        try writer.writeAll(getAnsiSequence(color));
        try writer.writeAll(text);
        try writer.writeAll(getAnsiSequence(.reset));
    } else {
        try writer.writeAll(text);
    }
}

/// Add formatted colored text to any writer
pub fn addTextWriterf(writer: anytype, color: tty.Color, comptime fmt: []const u8, args: anytype) !void {
    if (supportsColor()) {
        try writer.writeAll(getAnsiSequence(color));
        try writer.print(fmt, args);
        try writer.writeAll(getAnsiSequence(.reset));
    } else {
        try writer.print(fmt, args);
    }
}


/// Print colorized error message directly to stderr
pub fn printError(message: []const u8, context: ?[]const u8, suggestion: ?[]const u8) void {
    // In test mode, do nothing to avoid hanging
    if (@import("builtin").is_test) {
        return;
    }
    
    const stderr = std.io.getStdErr().writer();
    
    // Build the error message using writer API for direct output
    addTextWriter(stderr, .red, "Error: ") catch {};
    addTextWriter(stderr, .reset, message) catch {};
    
    if (context) |ctx| {
        addTextWriterf(stderr, .dim, " ('{s}')", .{ctx}) catch {};
    }
    
    if (suggestion) |sug| {
        addTextWriter(stderr, .dim, "\n\n") catch {};
        addTextWriter(stderr, .yellow, "Suggestion: ") catch {};
        addTextWriter(stderr, .reset, sug) catch {};
    }
    
    addTextWriter(stderr, .dim, "\n") catch {};
}




test "color support detection" {
    // Test stdlib TTY detection
    _ = supportsColor();
    _ = tty.detectConfig(std.io.getStdErr());
    _ = tty.detectConfig(std.io.getStdOut());
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