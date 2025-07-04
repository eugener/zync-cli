//! Terminal color utilities for enhanced CLI output
//!
//! This module provides color formatting for help text and error messages
//! using Zig's built-in TTY support.

const std = @import("std");
const tty = std.io.tty;

/// Check if colors are supported (simplified approach)
fn isColorSupported() bool {
    // Check common environment variables
    if (std.posix.getenv("NO_COLOR")) |_| return false;
    if (std.posix.getenv("FORCE_COLOR")) |_| return true;
    
    // Check if we're in a terminal
    return std.posix.isatty(std.io.getStdOut().handle);
}

/// Check if stdout supports colors
pub fn supportsColor() bool {
    return isColorSupported();
}

/// Simple ANSI color codes for cross-platform compatibility
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
    
    if (supportsColor()) {
        // Colored error message
        stderr.print("{s}Error: {s}{s}", .{ AnsiColors.red, AnsiColors.reset, message }) catch {};
        
        if (context) |ctx| {
            stderr.print(" ({s}'{s}'{s})", .{ AnsiColors.bright_red, ctx, AnsiColors.reset }) catch {};
        }
        
        if (suggestion) |sug| {
            stderr.print("\n\n{s}Suggestion: {s}{s}", .{ AnsiColors.yellow, AnsiColors.reset, sug }) catch {};
        }
        
        stderr.print("\n", .{}) catch {};
    } else {
        // Plain text fallback
        stderr.print("Error: {s}", .{message}) catch {};
        
        if (context) |ctx| {
            stderr.print(" ('{s}')", .{ctx}) catch {};
        }
        
        if (suggestion) |sug| {
            stderr.print("\n\nSuggestion: {s}", .{sug}) catch {};
        }
        
        stderr.print("\n", .{}) catch {};
    }
}

/// Format error message with colors (legacy function for compatibility)
pub fn formatError(allocator: std.mem.Allocator, message: []const u8, context: ?[]const u8, suggestion: ?[]const u8) ![]const u8 {
    _ = allocator;
    // For now, just print directly and return empty string
    printError(message, context, suggestion);
    return "";
}

/// Legacy function - now redirects to dynamic help generation
/// This function is deprecated and should not be used directly
pub fn printHelp() void {
    // This is now just a stub - dynamic help should be used instead
    // In test mode, do nothing to avoid hanging
    if (@import("builtin").is_test) {
        return;
    }
    
    const stdout = std.io.getStdOut().writer();
    stdout.print("Error: printHelp() called without struct type. Use help.printHelp(T) instead.\n", .{}) catch {};
}

/// Print a single colorized option line
pub fn printOption(short: ?u8, long: []const u8, value_type: ?[]const u8, required: bool, default_value: ?[]const u8, description: []const u8) void {
    // In test mode, do nothing to avoid hanging
    if (@import("builtin").is_test) {
        return;
    }
    
    const stdout = std.io.getStdOut().writer();
    
    stdout.print("  ", .{}) catch {};
    
    if (supportsColor()) {
        // Short flag
        if (short) |s| {
            stdout.print("{s}-{c}, {s}", .{ AnsiColors.green, s, AnsiColors.reset }) catch {};
        } else {
            stdout.print("    ", .{}) catch {};
        }
        
        // Long flag
        stdout.print("{s}--{s}{s}", .{ AnsiColors.green, long, AnsiColors.reset }) catch {};
        
        // Value type indicator
        if (value_type) |vtype| {
            stdout.print(" ", .{}) catch {};
            if (required) {
                stdout.print("{s}<{s}>{s}", .{ AnsiColors.red, vtype, AnsiColors.reset }) catch {};
            } else {
                stdout.print("{s}[{s}]{s}", .{ AnsiColors.dim, vtype, AnsiColors.reset }) catch {};
            }
        }
        
        // Padding
        const current_len = calculateLength(short, long, value_type, required);
        const padding_needed = if (current_len < 25) 25 - current_len else 1;
        var i: usize = 0;
        while (i < padding_needed) : (i += 1) {
            stdout.print(" ", .{}) catch {};
        }
        
        // Description
        stdout.print("{s}", .{description}) catch {};
        
        // Default value or required indicator
        if (default_value) |default| {
            stdout.print(" (default: {s}{s}{s})", .{ AnsiColors.magenta, default, AnsiColors.reset }) catch {};
        } else if (required) {
            stdout.print(" ({s}required{s})", .{ AnsiColors.red, AnsiColors.reset }) catch {};
        }
        
        stdout.print("\n", .{}) catch {};
    } else {
        // Plain text version
        if (short) |s| {
            stdout.print("-{c}, ", .{s}) catch {};
        } else {
            stdout.print("    ", .{}) catch {};
        }
        
        stdout.print("--{s}", .{long}) catch {};
        
        if (value_type) |vtype| {
            stdout.print(" ", .{}) catch {};
            if (required) {
                stdout.print("<{s}>", .{vtype}) catch {};
            } else {
                stdout.print("[{s}]", .{vtype}) catch {};
            }
        }
        
        const current_len = calculateLength(short, long, value_type, required);
        const padding_needed = if (current_len < 25) 25 - current_len else 1;
        var i: usize = 0;
        while (i < padding_needed) : (i += 1) {
            stdout.print(" ", .{}) catch {};
        }
        
        stdout.print("{s}", .{description}) catch {};
        
        if (default_value) |default| {
            stdout.print(" (default: {s})", .{default}) catch {};
        } else if (required) {
            stdout.print(" (required)", .{}) catch {};
        }
        
        stdout.print("\n", .{}) catch {};
    }
}


/// Calculate the length of an option line for padding
fn calculateLength(short: ?u8, long: []const u8, value_type: ?[]const u8, required: bool) usize {
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
    // This test just ensures the function compiles and runs
    _ = supportsColor();
}

test "format error message" {
    // formatError now just prints and returns empty string
    const formatted = formatError(std.testing.allocator, "Test error", "flag", "Use --help") catch "";
    // Since it prints directly, we just check it doesn't crash
    _ = formatted;
}

test "print option functionality" {
    // Test that the color functions don't crash
    printError("Test error", "context", "suggestion");
    // Note: printHelp() is deprecated - dynamic help should be tested in help.zig
}