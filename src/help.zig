//! Help text generation system
//!
//! This module handles generating help text, usage information, and
//! documentation for CLI applications.

const std = @import("std");
const types = @import("types.zig");
const meta = @import("meta.zig");

/// Generate help text for a type
pub fn generate(comptime T: type) []const u8 {
    // For now, return a simple placeholder
    // This will be implemented with proper help generation
    return comptime generateHelp(T);
}

/// Generate help text at compile time
fn generateHelp(comptime T: type) []const u8 {
    _ = T; // TODO: Use T to generate proper help
    // For now, return a simple static help message
    // TODO: Implement proper compile-time help generation
    return 
        \\Usage: [OPTIONS]
        \\
        \\Options:
        \\  -v, --verbose     Enable verbose output
        \\  -n, --name        Set name value
        \\  -c, --count       Set count value
        \\  -h, --help        Show this help message
        \\
    ;
}

/// Generate help text for a single field
fn generateFieldHelp(comptime field: types.FieldMetadata) []const u8 {
    if (field.hidden) {
        return "";
    }
    
    // For now, return a simple help line
    // TODO: Implement proper string building for help generation
    if (field.short) |short| {
        return "  -" ++ [_]u8{short} ++ ", --" ++ field.name ++ "\n";
    } else {
        return "      --" ++ field.name ++ "\n";
    }
}

/// Check if a field is boolean type (placeholder)
fn isBooleanField(comptime field: types.FieldMetadata) bool {
    // This is a placeholder - will be implemented with proper type checking
    _ = field;
    return false;
}

/// Generate usage string for a type
pub fn generateUsage(comptime T: type) []const u8 {
    const fields = meta.extractFields(T);
    var usage = "Usage: program";
    
    // Add flags
    var has_flags = false;
    for (fields) |field| {
        if (!field.positional and !field.hidden) {
            has_flags = true;
            break;
        }
    }
    
    if (has_flags) {
        usage = usage ++ " [OPTIONS]";
    }
    
    // Add positional arguments
    for (fields) |field| {
        if (field.positional) {
            usage = usage ++ " ";
            if (field.required) {
                usage = usage ++ "<" ++ field.name ++ ">";
            } else {
                usage = usage ++ "[" ++ field.name ++ "]";
            }
        }
    }
    
    return usage;
}

test "generate basic help" {
    const TestArgs = struct {
        verbose: bool = false,
    };
    
    const help_text = generate(TestArgs);
    
    // Should contain basic usage information
    try std.testing.expect(std.mem.indexOf(u8, help_text, "Usage:") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "Options:") != null);
}

test "generateUsage basic" {
    const TestArgs = struct {
        verbose: bool = false,
        @"#input": []const u8,
    };
    
    const usage = generateUsage(TestArgs);
    
    try std.testing.expect(std.mem.indexOf(u8, usage, "Usage:") != null);
    try std.testing.expect(std.mem.indexOf(u8, usage, "[OPTIONS]") != null);
}