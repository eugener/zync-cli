//! Metadata extraction and compile-time validation
//!
//! This module handles extracting field metadata from struct types,
//! parsing encoded field names, and validating argument structures.

const std = @import("std");
const types = @import("types.zig");
const builtin = @import("builtin");

const FieldMetadata = types.FieldMetadata;

/// Validate a type's structure for CLI argument parsing
pub fn validate(comptime T: type) void {
    const type_info = @typeInfo(T);
    
    switch (type_info) {
        .@"struct" => |struct_info| {
            // Check that all fields are valid for CLI parsing
            for (struct_info.fields) |field| {
                validateField(field);
            }
            
            // Check for CLI metadata if present
            if (@hasDecl(T, "cli")) {
                validateCliMetadata(T.cli);
            }
        },
        .@"union" => |union_info| {
            // Validate union for subcommand parsing
            if (union_info.tag_type == null) {
                @compileError("Union type must be tagged for subcommand parsing");
            }
            
            // Check that all variants are valid
            for (union_info.fields) |field| {
                validate(field.type);
            }
        },
        else => {
            @compileError("Type must be a struct or tagged union for CLI parsing");
        }
    }
}

/// Validate a single field for CLI compatibility
fn validateField(comptime field: std.builtin.Type.StructField) void {
    const field_type = field.type;
    
    // Check if field type is supported
    if (!isSupportedType(field_type)) {
        @compileError("Field '" ++ field.name ++ "' has unsupported type: " ++ @typeName(field_type));
    }
    
    // Parse and validate field encoding if present
    if (std.mem.startsWith(u8, field.name, "@\"")) {
        const encoded_name = field.name[2..field.name.len-1];
        const metadata = parseFieldEncoding(encoded_name);
        
        // Validate that encoding makes sense for the field type
        if (metadata.counting and field_type != u8) {
            @compileError("Counting flag must be of type u8");
        }
        
        if (metadata.multiple and !isArrayType(field_type)) {
            @compileError("Multiple flag must be an array type");
        }
    }
}

/// Check if a type is supported for CLI parsing
fn isSupportedType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .bool => true,
        .int => true,
        .float => true,
        .pointer => |ptr| switch (ptr.size) {
            .slice => ptr.child == u8, // []const u8 for strings
            else => false,
        },
        .array => |arr| arr.child == u8, // [N]u8 for fixed strings
        .optional => |opt| isSupportedType(opt.child),
        .@"enum" => true,
        .@"union" => |union_info| union_info.tag_type != null, // Tagged unions for subcommands
        else => false,
    };
}

/// Check if a type is an array type
fn isArrayType(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |ptr| ptr.size == .slice,
        .array => true,
        else => false,
    };
}

/// Extract field metadata from a struct type
pub fn extractFields(comptime T: type) []const FieldMetadata {
    const type_info = @typeInfo(T);
    
    switch (type_info) {
        .@"struct" => |struct_info| {
            var fields: []const FieldMetadata = &.{};
            
            for (struct_info.fields) |field| {
                const metadata = if (std.mem.indexOf(u8, field.name, "|") != null or 
                                   std.mem.indexOf(u8, field.name, "!") != null or
                                   std.mem.indexOf(u8, field.name, "=") != null or
                                   std.mem.indexOf(u8, field.name, "#") != null or
                                   std.mem.indexOf(u8, field.name, "*") != null or
                                   std.mem.indexOf(u8, field.name, "+") != null or
                                   std.mem.indexOf(u8, field.name, "$") != null or
                                   std.mem.indexOf(u8, field.name, "~") != null or
                                   std.mem.indexOf(u8, field.name, "@") != null or
                                   std.mem.indexOf(u8, field.name, "%") != null or
                                   std.mem.indexOf(u8, field.name, "&") != null) blk: {
                    // Field has encoded name
                    break :blk parseFieldEncoding(field.name);
                } else blk: {
                    // Simple field name
                    break :blk FieldMetadata{
                        .name = field.name,
                    };
                };
                
                fields = fields ++ &[_]FieldMetadata{metadata};
            }
            
            return fields;
        },
        else => {
            @compileError("extractFields only works on struct types");
        }
    }
}

/// Parse field encoding from an encoded field name
pub fn parseFieldEncoding(encoded_name: []const u8) FieldMetadata {
    var metadata = FieldMetadata{
        .name = encoded_name, // Default to full encoded name
    };
    
    var remaining = encoded_name;
    
    // Parse components in order
    
    // 1. Extract base name (everything before first special character)
    var base_end = remaining.len;
    for (remaining, 0..) |char, i| {
        if (char == '|' or char == '!' or char == '=' or char == '#' or 
            char == '*' or char == '+' or char == '$' or char == '~' or 
            char == '@' or char == '%' or char == '&' or char == '"') {
            base_end = i;
            break;
        }
    }
    
    if (base_end == 0) {
        // Return invalid metadata for runtime handling
        return FieldMetadata{ .name = "" };
    }
    
    // Handle positional arguments (#name)
    if (remaining[0] == '#') {
        metadata.positional = true;
        metadata.name = remaining[1..base_end];
        remaining = remaining[base_end..];
    } else {
        metadata.name = remaining[0..base_end];
        remaining = remaining[base_end..];
    }
    
    // Parse remaining components
    while (remaining.len > 0) {
        const char = remaining[0];
        remaining = remaining[1..];
        
        switch (char) {
            '|' => {
                // Short flag
                if (remaining.len == 0) {
                    // Skip invalid short flag
                    continue;
                }
                metadata.short = remaining[0];
                remaining = remaining[1..];
            },
            '!' => {
                // Required
                metadata.required = true;
            },
            '=' => {
                // Default value
                const default_end = findNextSpecialChar(remaining);
                metadata.default = remaining[0..default_end];
                remaining = remaining[default_end..];
            },
            '*' => {
                // Multiple values
                metadata.multiple = true;
            },
            '+' => {
                // Counting
                metadata.counting = true;
            },
            '$' => {
                // Environment variable
                const env_end = findNextSpecialChar(remaining);
                metadata.env_var = remaining[0..env_end];
                remaining = remaining[env_end..];
            },
            '~' => {
                // Hidden
                metadata.hidden = true;
            },
            '@' => {
                // Validator
                const validator_end = findNextSpecialChar(remaining);
                metadata.validator = remaining[0..validator_end];
                remaining = remaining[validator_end..];
            },
            '%' => {
                // Choices
                const choices_end = findNextSpecialChar(remaining);
                const choices_str = remaining[0..choices_end];
                metadata.choices = parseChoices(choices_str);
                remaining = remaining[choices_end..];
            },
            '&' => {
                // Aliases
                const aliases_end = findNextSpecialChar(remaining);
                const aliases_str = remaining[0..aliases_end];
                metadata.aliases = parseAliases(aliases_str);
                remaining = remaining[aliases_end..];
            },
            '"' => {
                // Help text (everything until closing quote)
                const help_end = std.mem.indexOf(u8, remaining, "\"") orelse remaining.len;
                metadata.help = remaining[0..help_end];
                remaining = remaining[help_end..];
                if (remaining.len > 0 and remaining[0] == '"') {
                    remaining = remaining[1..]; // Skip closing quote
                }
            },
            else => {
                // Skip unknown characters for now
                // TODO: Add proper error handling
                continue;
            }
        }
    }
    
    return metadata;
}

/// Find the next special character in a string
fn findNextSpecialChar(str: []const u8) usize {
    for (str, 0..) |char, i| {
        if (char == '|' or char == '!' or char == '=' or char == '#' or 
            char == '*' or char == '+' or char == '$' or char == '~' or 
            char == '@' or char == '%' or char == '&' or char == '"') {
            return i;
        }
    }
    return str.len;
}

/// Parse choices from a comma-separated string
fn parseChoices(choices_str: []const u8) []const []const u8 {
    // For now, return empty slice - will implement proper parsing later
    _ = choices_str;
    return &.{};
}

/// Parse aliases from a comma-separated string
fn parseAliases(aliases_str: []const u8) []const []const u8 {
    // For now, return empty slice - will implement proper parsing later
    _ = aliases_str;
    return &.{};
}

/// Validate CLI metadata structure
fn validateCliMetadata(comptime cli_meta: anytype) void {
    const meta_type = @TypeOf(cli_meta);
    const type_info = @typeInfo(meta_type);
    
    switch (type_info) {
        .@"struct" => {
            // Valid CLI metadata
        },
        else => {
            @compileError("CLI metadata must be a struct");
        }
    }
}

test "validate basic struct" {
    const TestArgs = struct {
        verbose: bool = false,
        count: u32 = 0,
        name: []const u8 = "",
    };
    
    // Should not cause compile error
    validate(TestArgs);
}

test "validate encoded field names" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"count|c=10": u32,
        @"#input": []const u8,
    };
    
    // Should not cause compile error
    validate(TestArgs);
}

test "parseFieldEncoding basic" {
    const metadata = parseFieldEncoding("verbose|v");
    
    try std.testing.expectEqualStrings(metadata.name, "verbose");
    try std.testing.expect(metadata.short.? == 'v');
    try std.testing.expect(metadata.required == false);
}

test "parseFieldEncoding complex" {
    const metadata = parseFieldEncoding("config|c!$CONFIG_FILE");
    
    try std.testing.expectEqualStrings(metadata.name, "config");
    try std.testing.expect(metadata.short.? == 'c');
    try std.testing.expect(metadata.required == true);
    try std.testing.expectEqualStrings(metadata.env_var.?, "CONFIG_FILE");
}

test "parseFieldEncoding positional" {
    const metadata = parseFieldEncoding("#input");
    
    try std.testing.expectEqualStrings(metadata.name, "input");
    try std.testing.expect(metadata.positional == true);
}

test "extractFields basic" {
    const TestArgs = struct {
        verbose: bool = false,
        @"count|c": u32 = 0,
    };
    
    const fields = extractFields(TestArgs);
    
    try std.testing.expect(fields.len == 2);
    try std.testing.expectEqualStrings(fields[0].name, "verbose");
    try std.testing.expectEqualStrings(fields[1].name, "count");
    try std.testing.expect(fields[1].short.? == 'c');
}