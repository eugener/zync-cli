//! Help text generation system
//!
//! This module handles generating help text, usage information, and
//! documentation for CLI applications.

const std = @import("std");
const types = @import("types.zig");
const meta = @import("meta.zig");
const colors = @import("colors.zig");

/// Extract the program name from process arguments
pub fn extractProgramName(allocator: std.mem.Allocator) ![]const u8 {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    
    if (args.len > 0) {
        // Extract just the filename from the full path
        const full_path = args[0];
        var i = full_path.len;
        while (i > 0) {
            i -= 1;
            if (full_path[i] == '/' or full_path[i] == '\\') {
                const program_name = full_path[i + 1..];
                // Make a copy to ensure it's null-terminated and safe
                return try allocator.dupe(u8, program_name);
            }
        }
        // Make a copy to ensure it's null-terminated and safe
        return try allocator.dupe(u8, full_path);
    }
    return "program";
}


/// Generate formatted help text for a type
pub fn formatHelp(comptime T: type, allocator: std.mem.Allocator, program_name: ?[]const u8) ![]const u8 {
    const cli = @import("cli.zig");
    const default_config = cli.ArgsConfig{};
    return formatHelpWithConfig(T, allocator, program_name, default_config);
}

/// Generate formatted help text for a type with configuration
pub fn formatHelpWithConfig(comptime T: type, allocator: std.mem.Allocator, program_name: ?[]const u8, config: @import("cli.zig").ArgsConfig) ![]const u8 {
    // Extract field metadata at compile time
    const field_info = comptime meta.extractFields(T);
    
    var help_text = std.ArrayList(u8).init(allocator);
    defer help_text.deinit();
    
    // Get the actual program name for both title and usage
    const actual_program_name = program_name orelse "program";
    
    // Add blank line before title
    try colors.addText(&help_text, .dim, "\n");
    
    // Title (custom title or program name)
    const title = config.title orelse actual_program_name;
    try colors.addText(&help_text, .bright_cyan, title);
    try colors.addText(&help_text, .dim, "\n");
    
    // Description (if provided)
    if (config.description) |description| {
        try colors.addText(&help_text, .dim, description);
        try colors.addText(&help_text, .dim, "\n");
    }
    
    try colors.addText(&help_text, .dim, "\n");
    try colors.addText(&help_text, .dim, "Usage: ");
    try colors.addText(&help_text, .bright_white, actual_program_name);
    
    // Add options if any non-positional fields exist
    comptime var has_options = false;
    comptime {
        for (field_info) |field| {
            if (!field.positional) {
                has_options = true;
                break;
            }
        }
    }
    if (has_options) {
        try colors.addText(&help_text, .dim, " [OPTIONS]");
    }
    
    // Add positional args to usage if any
    comptime var has_positional = false;
    inline for (field_info) |field| {
        if (field.positional) {
            if (!has_positional) {
                try colors.addText(&help_text, .dim, " [ARGS...]");
                has_positional = true;
            }
        }
    }
    try colors.addText(&help_text, .dim, "\n\n");
    
    // Options section
    try colors.addText(&help_text, .bold, "Options:");
    try colors.addText(&help_text, .dim, "\n");
    
    // Calculate the maximum width for proper alignment
    comptime var max_option_width: usize = 0;
    comptime {
        for (field_info) |field| {
            if (!field.positional and !field.hidden) {
                const field_type = extractFieldType(T, field.name);
                const is_bool = field_type == bool;
                
                var width: usize = 2; // "  " prefix
                
                // Short flag width
                if (field.short != null) {
                    width += 4; // "-x, "
                } else {
                    width += 4; // "    "
                }
                
                // Long flag width
                width += 2 + field.name.len; // "--fieldname"
                
                // Value indicator width
                if (!is_bool) {
                    width += 8; // " [value]" or " <value>"
                }
                
                if (width > max_option_width) {
                    max_option_width = width;
                }
            }
        }
        // Add some padding between columns
        max_option_width += 4;
    }
    
    // List options with proper alignment
    inline for (field_info) |field| {
        if (!field.positional and !field.hidden) {
            const field_type = extractFieldType(T, field.name);
            const is_bool = field_type == bool;
            
            var option_width: usize = 0;
            
            try colors.addText(&help_text, .dim, "  ");
            option_width += 2;
            
            // Short flag
            if (field.short) |short| {
                try colors.addText(&help_text, .green, "-");
                try help_text.append(short);
                try colors.addText(&help_text, .green, ", ");
                option_width += 4;
            } else {
                try colors.addText(&help_text, .dim, "    ");
                option_width += 4;
            }
            
            // Long flag  
            try colors.addText(&help_text, .green, "--");
            try colors.addText(&help_text, .green, field.name);
            option_width += 2 + field.name.len;
            
            // Value type indicator
            if (!is_bool) {
                try colors.addText(&help_text, .dim, " ");
                if (field.required) {
                    try colors.addText(&help_text, .red, "<value>");
                } else {
                    try colors.addText(&help_text, .dim, "[value]");
                }
                option_width += 8;
            }
            
            // Add padding to align descriptions
            const padding_needed = max_option_width - option_width;
            var i: usize = 0;
            while (i < padding_needed) : (i += 1) {
                try help_text.append(' ');
            }
            
            // Description
            const desc = extractFieldDescription(field);
            try help_text.appendSlice(desc);
            
            // Environment variable indicator
            if (field.env_var) |env_var| {
                try colors.addText(&help_text, .dim, " [env: ");
                try colors.addText(&help_text, .cyan, env_var);
                try colors.addText(&help_text, .dim, "]");
            }
            
            // Default value or required indicator
            if (field.default) |default| {
                try colors.addText(&help_text, .dim, " (default: ");
                try colors.addText(&help_text, .magenta, default);
                try colors.addText(&help_text, .dim, ")");
            } else if (field.required) {
                try colors.addText(&help_text, .dim, " (");
                try colors.addText(&help_text, .red, "required");
                try colors.addText(&help_text, .dim, ")");
            }
            
            try colors.addText(&help_text, .dim, "\n");
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
        try colors.addText(&help_text, .dim, "  ");
        try colors.addText(&help_text, .green, "-h, --help");
        
        // Add proper padding for help option
        const help_option_width = 2 + 4 + 6; // "  " + "-h, " + "--help"
        const help_padding_needed = max_option_width - help_option_width;
        var help_i: usize = 0;
        while (help_i < help_padding_needed) : (help_i += 1) {
            try help_text.append(' ');
        }
        
        try colors.addText(&help_text, .dim, "Show this help message\n");
    }
    
    // Show positional arguments if any
    comptime var has_printed_pos_header = false;
    comptime var max_arg_width: usize = 0;
    
    // Calculate max argument name width
    comptime {
        for (field_info) |field| {
            if (field.positional) {
                const arg_width = 2 + field.name.len; // "  " + name
                if (arg_width > max_arg_width) {
                    max_arg_width = arg_width;
                }
            }
        }
        // Add padding between columns
        max_arg_width += 4;
    }
    
    inline for (field_info) |field| {
        if (field.positional) {
            if (!has_printed_pos_header) {
                try colors.addText(&help_text, .dim, "\n");
                try colors.addText(&help_text, .bold, "Arguments:");
                try colors.addText(&help_text, .dim, "\n");
                has_printed_pos_header = true;
            }
            
            var arg_width: usize = 0;
            try colors.addText(&help_text, .dim, "  ");
            arg_width += 2;
            
            try colors.addText(&help_text, .green, field.name);
            arg_width += field.name.len;
            
            // Add padding to align descriptions
            const arg_padding_needed = max_arg_width - arg_width;
            var arg_i: usize = 0;
            while (arg_i < arg_padding_needed) : (arg_i += 1) {
                try help_text.append(' ');
            }
            
            try colors.addText(&help_text, .dim, extractFieldDescription(field));
            try colors.addText(&help_text, .dim, "\n");
        }
    }
    
    return help_text.toOwnedSlice();
}

/// Generate help text for a type (backwards compatibility)

/// Print help text with colors for a specific type
pub fn printHelp(comptime T: type) void {
    // In test mode, do nothing to avoid hanging
    if (@import("builtin").is_test) {
        return;
    }
    
    // Use a temporary arena allocator for help text generation
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // Get the actual program name from process args
    const program_name = extractProgramName(arena.allocator()) catch "program";
    
    // Generate help text with color support and actual program name
    const help_text = formatHelp(T, arena.allocator(), program_name) catch {
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
fn extractFieldType(comptime T: type, comptime field_name: []const u8) type {
    // Handle automatic DSL types that have ArgsType
    const TargetType = if (@hasDecl(T, "ArgsType")) T.ArgsType else T;
    
    const struct_fields = std.meta.fields(TargetType);
    inline for (struct_fields) |struct_field| {
        // Exact field name matching
        if (std.mem.eql(u8, struct_field.name, field_name)) {
            return struct_field.type;
        }
    }
    return []const u8; // Default fallback
}

/// Get field description from metadata or return empty if not provided
pub fn extractFieldDescription(field: meta.FieldMetadata) []const u8 {
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
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    // Use formatHelp for testing
    const help_text = try formatHelp(TestArgs, arena.allocator(), "test-program");
    defer arena.allocator().free(help_text);
    
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

test "environment variable in help text" {
    const cli = @import("cli.zig");
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output", .env_var = "TEST_VERBOSE" }),
        cli.option("name", []const u8, .{ .short = 'n', .default = "test", .help = "Name to use", .env_var = "TEST_NAME" }),
    });
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const help_text = try formatHelp(TestArgs, arena.allocator(), "test-program");
    defer arena.allocator().free(help_text);
    
    // Check that environment variables appear in help 
    // (may contain color codes, so search for the environment variable names)
    try std.testing.expect(std.mem.indexOf(u8, help_text, "TEST_VERBOSE") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "TEST_NAME") != null);
    
    // Also check for the env indicator pattern (even with potential color codes)
    try std.testing.expect(std.mem.indexOf(u8, help_text, "[env:") != null);
}