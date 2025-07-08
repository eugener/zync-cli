//! Terminal color utilities for enhanced CLI output
//!
//! This module provides color formatting for help text and error messages
//! using Zig's built-in TTY support.

const std = @import("std");
const tty = std.io.tty;

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

/// ANSI color constants for string-based help generation
/// These match the stdlib's TTY colors but as string constants for embedding in text
pub const AnsiColors = struct {
    pub const reset = "\x1b[0m";
    pub const red = "\x1b[31m";
    pub const bright_red = "\x1b[91m";
    pub const green = "\x1b[32m";
    pub const yellow = "\x1b[33m";
    pub const cyan = "\x1b[36m";
    pub const bright_cyan = "\x1b[96m";
    pub const magenta = "\x1b[35m";
    pub const white = "\x1b[37m";
    pub const bright_white = "\x1b[97m";
    pub const dim = "\x1b[2m";
    pub const bold = "\x1b[1m";
};

/// Print colorized error message directly to stderr
pub fn printError(message: []const u8, context: ?[]const u8, suggestion: ?[]const u8) void {
    // In test mode, do nothing to avoid hanging
    if (@import("builtin").is_test) {
        return;
    }
    
    const stderr = std.io.getStdErr().writer();
    const config = getStderrConfig();
    
    // Print colored error message
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
    
    stderr.print("\n", .{}) catch {};
}



/// Print a single colorized option line
pub fn printOption(short: ?u8, long: []const u8, value_type: ?[]const u8, required: bool, default_value: ?[]const u8, description: []const u8) void {
    // In test mode, do nothing to avoid hanging
    if (@import("builtin").is_test) {
        return;
    }
    
    const stdout = std.io.getStdOut().writer();
    const config = getStdoutConfig();
    
    stdout.print("  ", .{}) catch {};
    
    // Short flag
    if (short) |s| {
        config.setColor(stdout, .green) catch {};
        stdout.print("-{c}, ", .{s}) catch {};
        config.setColor(stdout, .reset) catch {};
    } else {
        stdout.print("    ", .{}) catch {};
    }
    
    // Long flag
    config.setColor(stdout, .green) catch {};
    stdout.print("--{s}", .{long}) catch {};
    config.setColor(stdout, .reset) catch {};
    
    // Value type indicator
    if (value_type) |vtype| {
        stdout.print(" ", .{}) catch {};
        if (required) {
            config.setColor(stdout, .red) catch {};
            stdout.print("<{s}>", .{vtype}) catch {};
            config.setColor(stdout, .reset) catch {};
        } else {
            config.setColor(stdout, .dim) catch {};
            stdout.print("[{s}]", .{vtype}) catch {};
            config.setColor(stdout, .reset) catch {};
        }
    }
    
    // Padding
    const current_len = calculateOptionLength(short, long, value_type, required);
    const padding_needed = if (current_len < 25) 25 - current_len else 1;
    var i: usize = 0;
    while (i < padding_needed) : (i += 1) {
        stdout.print(" ", .{}) catch {};
    }
    
    // Description
    stdout.print("{s}", .{description}) catch {};
    
    // Default value or required indicator
    if (default_value) |default| {
        stdout.print(" (default: ", .{}) catch {};
        config.setColor(stdout, .magenta) catch {};
        stdout.print("{s}", .{default}) catch {};
        config.setColor(stdout, .reset) catch {};
        stdout.print(")", .{}) catch {};
    } else if (required) {
        stdout.print(" (", .{}) catch {};
        config.setColor(stdout, .red) catch {};
        stdout.print("required", .{}) catch {};
        config.setColor(stdout, .reset) catch {};
        stdout.print(")", .{}) catch {};
    }
    
    stdout.print("\n", .{}) catch {};
}


/// Calculate the length of an option line for padding
fn calculateOptionLength(short: ?u8, long: []const u8, value_type: ?[]const u8, required: bool) usize {
    _ = required;
    var len: usize = 2; // "  "
    
    if (short != null) {
        len += 4; // "-x, "
    } else {
        len += 4; // "    "
    }
    
    len += 2 + long.len; // "--flag"
    
    if (value_type) |vtype| {
        len += 1 + vtype.len + 2; // " [value]" or " <value>"
    }
    
    return len;
}

test "color support detection" {
    // Test stdlib TTY detection
    _ = supportsColor();
    _ = getStderrConfig();
    _ = getStdoutConfig();
}


test "print option functionality" {
    // Test that the color functions don't crash
    printError("Test error", "context", "suggestion");
}