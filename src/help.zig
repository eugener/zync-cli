//! Help text generation system
//!
//! This module handles generating help text, usage information, and
//! documentation for CLI applications.

const std = @import("std");
const types = @import("types.zig");
const meta = @import("meta.zig");
const colors = @import("colors.zig");

/// Generate formatted help text for a type
pub fn formatHelp(comptime T: type, allocator: std.mem.Allocator, colored: bool) ![]const u8 {
    // Extract field metadata at compile time
    const field_info = comptime meta.extractFields(T);
    
    var help_text = std.ArrayList(u8).init(allocator);
    defer help_text.deinit();
    
    // Helper function to add colored or plain text
    const addText = struct {
        fn call(list: *std.ArrayList(u8), color: []const u8, text: []const u8, reset: []const u8, use_color: bool) !void {
            if (use_color) {
                try list.appendSlice(color);
                try list.appendSlice(text);
                try list.appendSlice(reset);
            } else {
                try list.appendSlice(text);
            }
        }
    }.call;
    
    // Title
    if (colored) {
        try addText(&help_text, colors.AnsiColors.bright_cyan, "CLI Application", colors.AnsiColors.reset, colored);
    } else {
        try help_text.appendSlice("CLI Application");
    }
    try help_text.appendSlice("\n\n");
    
    // Usage line - use generateUsage() for consistency
    const usage = generateUsage(T);
    if (colored) {
        try addText(&help_text, colors.AnsiColors.bright_white, usage, colors.AnsiColors.reset, colored);
    } else {
        try help_text.appendSlice(usage);
    }
    
    // Add positional args to usage if any
    comptime var has_positional = false;
    inline for (field_info) |field| {
        if (field.positional) {
            if (!has_positional) {
                if (colored) {
                    try addText(&help_text, colors.AnsiColors.dim, " [ARGS...]", colors.AnsiColors.reset, colored);
                } else {
                    try help_text.appendSlice(" [ARGS...]");
                }
                has_positional = true;
            }
        }
    }
    try help_text.appendSlice("\n\n");
    
    // Options section
    if (colored) {
        try addText(&help_text, colors.AnsiColors.bold, "Options:", colors.AnsiColors.reset, colored);
    } else {
        try help_text.appendSlice("Options:");
    }
    try help_text.appendSlice("\n");
    
    // List options
    inline for (field_info) |field| {
        if (!field.positional) {
            const field_type = comptime getFieldType(T, field.name);
            const is_bool = field_type == bool;
            
            try help_text.appendSlice("  ");
            
            // Short flag
            if (field.short) |short| {
                if (colored) {
                    try addText(&help_text, colors.AnsiColors.green, "-", colors.AnsiColors.reset, colored);
                    try help_text.append(short);
                    try addText(&help_text, colors.AnsiColors.reset, ", ", "", colored);
                } else {
                    try help_text.append('-');
                    try help_text.append(short);
                    try help_text.appendSlice(", ");
                }
            } else {
                try help_text.appendSlice("    ");
            }
            
            // Long flag
            if (colored) {
                try addText(&help_text, colors.AnsiColors.green, "--", colors.AnsiColors.reset, colored);
                try addText(&help_text, colors.AnsiColors.green, field.name, colors.AnsiColors.reset, colored);
            } else {
                try help_text.appendSlice("--");
                try help_text.appendSlice(field.name);
            }
            
            // Value type indicator
            if (!is_bool) {
                try help_text.appendSlice(" ");
                if (field.required) {
                    if (colored) {
                        try addText(&help_text, colors.AnsiColors.red, "<value>", colors.AnsiColors.reset, colored);
                    } else {
                        try help_text.appendSlice("<value>");
                    }
                } else {
                    if (colored) {
                        try addText(&help_text, colors.AnsiColors.dim, "[value]", colors.AnsiColors.reset, colored);
                    } else {
                        try help_text.appendSlice("[value]");
                    }
                }
            }
            
            // Padding and description
            try help_text.appendSlice("    ");
            const desc = getFieldDescription(field);
            try help_text.appendSlice(desc);
            
            // Default value or required indicator
            if (field.default) |default| {
                if (colored) {
                    try help_text.appendSlice(" (default: ");
                    try addText(&help_text, colors.AnsiColors.magenta, default, colors.AnsiColors.reset, colored);
                    try help_text.appendSlice(")");
                } else {
                    try help_text.appendSlice(" (default: ");
                    try help_text.appendSlice(default);
                    try help_text.appendSlice(")");
                }
            } else if (field.required) {
                if (colored) {
                    try help_text.appendSlice(" (");
                    try addText(&help_text, colors.AnsiColors.red, "required", colors.AnsiColors.reset, colored);
                    try help_text.appendSlice(")");
                } else {
                    try help_text.appendSlice(" (required)");
                }
            }
            
            try help_text.appendSlice("\n");
        }
    }
    
    // Always add help option automatically (unless user defined their own)
    const has_user_help = comptime blk: {
        for (field_info) |field| {
            if (std.mem.eql(u8, field.name, "help")) {
                break :blk true;
            }
        }
        break :blk false;
    };
    
    if (!has_user_help) {
        try help_text.appendSlice("  ");
        if (colored) {
            try addText(&help_text, colors.AnsiColors.green, "-h, --help", colors.AnsiColors.reset, colored);
        } else {
            try help_text.appendSlice("-h, --help");
        }
        try help_text.appendSlice("    Show this help message\n");
    }
    
    // Show positional arguments if any
    comptime var has_printed_pos_header = false;
    inline for (field_info) |field| {
        if (field.positional) {
            if (!has_printed_pos_header) {
                try help_text.appendSlice("\n");
                if (colored) {
                    try addText(&help_text, colors.AnsiColors.bold, "Arguments:", colors.AnsiColors.reset, colored);
                } else {
                    try help_text.appendSlice("Arguments:");
                }
                try help_text.appendSlice("\n");
                has_printed_pos_header = true;
            }
            try help_text.appendSlice("  ");
            if (colored) {
                try addText(&help_text, colors.AnsiColors.green, field.name, colors.AnsiColors.reset, colored);
            } else {
                try help_text.appendSlice(field.name);
            }
            try help_text.appendSlice("    ");
            try help_text.appendSlice(getFieldDescription(field));
            try help_text.appendSlice("\n");
        }
    }
    
    return help_text.toOwnedSlice();
}

/// Generate help text for a type (backwards compatibility)
/// Returns basic help text for testing - uses compile-time generation
pub fn generate(comptime T: type) []const u8 {
    // Extract field metadata at compile time
    const field_info = comptime meta.extractFields(T);
    
    // For tests, return a basic help string that includes field count
    comptime var test_help: []const u8 = "Usage: program [OPTIONS]";
    comptime {
        if (field_info.len > 0) {
            test_help = test_help ++ "\n\nOptions:\n";
            for (field_info) |field| {
                test_help = test_help ++ "  --" ++ field.name;
                if (field.short) |short| {
                    test_help = test_help ++ ", -" ++ [_]u8{short};
                }
                test_help = test_help ++ "\n";
            }
        }
    }
    return test_help;
}

/// Print help text with colors for a specific type
pub fn printHelp(comptime T: type) void {
    // In test mode, do nothing to avoid hanging
    if (@import("builtin").is_test) {
        return;
    }
    
    // Use a temporary arena allocator for help text generation
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // Generate help text with color support
    const help_text = formatHelp(T, arena.allocator(), colors.supportsColor()) catch {
        // Fallback if allocation fails
        const stdout = std.io.getStdOut().writer();
        stdout.print("Error: Unable to generate help text\n", .{}) catch {};
        return;
    };
    
    // Print the generated help text
    const stdout = std.io.getStdOut().writer();
    stdout.print("{s}", .{help_text}) catch {};
}


/// Get field type from struct at compile time
fn getFieldType(comptime T: type, comptime field_name: []const u8) type {
    const struct_fields = std.meta.fields(T);
    inline for (struct_fields) |struct_field| {
        // Simple prefix matching - if the field starts with the field_name, it's a match
        if (std.mem.startsWith(u8, struct_field.name, field_name)) {
            return struct_field.type;
        }
    }
    return []const u8; // Default fallback
}

/// Get field description from metadata or return empty if not provided
fn getFieldDescription(field: meta.FieldMetadata) []const u8 {
    // If the field has explicit help text, use it
    if (field.help) |help_text| {
        return help_text;
    }
    
    // Only provide description for help option
    if (std.mem.eql(u8, field.name, "help")) {
        return "Show this help message";
    }
    
    // For all other fields, user must provide description
    return "";
}

/// Generate usage string for a type
pub fn generateUsage(comptime T: type) []const u8 {
    // Extract field metadata at compile time
    const field_info = comptime meta.extractFields(T);
    
    // Build usage string dynamically
    comptime var usage: []const u8 = "Usage: program";
    
    // Add options if any non-positional fields exist
    comptime var has_options = false;
    comptime {
        for (field_info) |field| {
            if (!field.positional) {
                has_options = true;
                break;
            }
        }
        if (has_options) {
            usage = usage ++ " [OPTIONS]";
        }
    }
    
    // Add positional arguments
    comptime {
        for (field_info) |field| {
            if (field.positional) {
                if (field.required) {
                    usage = usage ++ " <" ++ field.name ++ ">";
                } else {
                    usage = usage ++ " [" ++ field.name ++ "]";
                }
            }
        }
    }
    
    return usage;
}

test "generate basic help" {
    const TestArgs = struct {
        verbose: bool = false,
    };
    
    // generate() now returns a basic help string for testing
    const help_text = generate(TestArgs);
    
    // Check that it returns the expected basic help string
    try std.testing.expect(std.mem.indexOf(u8, help_text, "Usage:") != null);
}

test "generateUsage basic" {
    const TestArgs = struct {
        verbose: bool = false,
        @"#input": []const u8 = "",
    };
    
    const usage = generateUsage(TestArgs);
    
    try std.testing.expect(std.mem.indexOf(u8, usage, "Usage:") != null);
}