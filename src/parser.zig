//! Simplified argument parsing functionality
//!
//! This module implements a clean, idiomatic Zig parser for command-line arguments.

const std = @import("std");
const meta = @import("meta.zig");
const help = @import("help.zig");

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

/// Parse arguments from a string array into the specified type
pub fn parseFrom(comptime T: type, allocator: std.mem.Allocator, args: []const []const u8) !T {
    // Validate the structure at compile time
    comptime meta.validate(T);
    
    // Check for help flags FIRST, before any validation
    try checkForHelpRequest(T, args);
    
    // Initialize the result structure with defaults
    var result = T{};
    
    // Track which fields were provided
    var provided_fields = std.ArrayList([]const u8).init(allocator);
    defer provided_fields.deinit();
    
    // Extract field metadata at compile time
    const field_info = comptime meta.extractFields(T);
    
    // Use all provided arguments (don't skip any)
    const cli_args = args;
    
    // Parse arguments
    var i: usize = 0;
    while (i < cli_args.len) {
        const arg = cli_args[i];
        
        if (std.mem.startsWith(u8, arg, "--")) {
            // Long flag (--flag or --flag=value)
            i = try parseLongFlag(T, field_info, &result, cli_args, i, &provided_fields, allocator);
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
            // Short flag (-f or -fvalue)
            i = try parseShortFlag(T, field_info, &result, cli_args, i, &provided_fields, allocator);
        } else {
            // Positional argument
            i = try parsePositional(T, field_info, &result, cli_args, i, &provided_fields, allocator);
        }
    }
    
    // Apply default values for fields that weren't provided
    try applyDefaults(T, field_info, &result, provided_fields.items, allocator);
    
    // Check for missing required arguments
    try validateRequired(T, field_info, result, provided_fields.items);
    
    return result;
}

/// Parse a long flag (--flag or --flag=value)
fn parseLongFlag(
    comptime T: type,
    field_info: anytype,
    result: *T,
    args: []const []const u8,
    index: usize,
    provided_fields: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
) !usize {
    const arg = args[index];
    const flag_start = 2; // Skip "--"
    
    // Check if flag has embedded value (--flag=value)
    if (std.mem.indexOf(u8, arg, "=")) |eq_pos| {
        const flag_name = arg[flag_start..eq_pos];
        const flag_value = arg[eq_pos + 1..];
        
        // Find the field and set its value
        if (findFieldByName(field_info, flag_name)) |field_index| {
            const field = field_info[field_index];
            try setFieldValue(T, result, field, flag_value, allocator);
            try provided_fields.append(field.name);
        } else {
            return ParseError.UnknownFlag;
        }
        
        return index + 1;
    } else {
        // Flag without embedded value
        const flag_name = arg[flag_start..];
        
        if (findFieldByName(field_info, flag_name)) |field_index| {
            const field = field_info[field_index];
            if (isBooleanField(T, field)) {
                // Boolean flag, set to true
                try setFieldValue(T, result, field, "true", allocator);
                try provided_fields.append(field.name);
                return index + 1;
            } else {
                // Flag requires a value, get it from next argument
                if (index + 1 >= args.len) {
                    return ParseError.MissingValue;
                }
                
                const flag_value = args[index + 1];
                try setFieldValue(T, result, field, flag_value, allocator);
                try provided_fields.append(field.name);
                return index + 2;
            }
        } else {
            return ParseError.UnknownFlag;
        }
    }
}

/// Parse a short flag (-f or -fvalue)
fn parseShortFlag(
    comptime T: type,
    field_info: anytype,
    result: *T,
    args: []const []const u8,
    index: usize,
    provided_fields: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
) !usize {
    const arg = args[index];
    const flag_char = arg[1];
    
    // Find field by short flag
    if (findFieldByShort(field_info, flag_char)) |field_index| {
        const field = field_info[field_index];
        
        if (arg.len > 2) {
            // Value embedded in flag (-fvalue)
            const flag_value = arg[2..];
            try setFieldValue(T, result, field, flag_value, allocator);
            try provided_fields.append(field.name);
            return index + 1;
        } else if (isBooleanField(T, field)) {
            // Boolean flag
            try setFieldValue(T, result, field, "true", allocator);
            try provided_fields.append(field.name);
            return index + 1;
        } else {
            // Value in next argument
            if (index + 1 >= args.len) {
                return ParseError.MissingValue;
            }
            
            const flag_value = args[index + 1];
            try setFieldValue(T, result, field, flag_value, allocator);
            try provided_fields.append(field.name);
            return index + 2;
        }
    } else {
        return ParseError.UnknownFlag;
    }
}

/// Parse a positional argument
fn parsePositional(
    comptime T: type,
    field_info: anytype,
    result: *T,
    args: []const []const u8,
    index: usize,
    provided_fields: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
) !usize {
    const arg = args[index];
    
    // Find the next positional field that hasn't been provided
    const provided_positional_count = countProvidedPositional(field_info, provided_fields.items);
    
    if (findPositionalField(field_info, provided_positional_count)) |field_index| {
        const field = field_info[field_index];
        try setFieldValue(T, result, field, arg, allocator);
        try provided_fields.append(field.name);
        return index + 1;
    } else {
        return ParseError.TooManyPositionalArgs;
    }
}

/// Find field by name
fn findFieldByName(field_info: anytype, name: []const u8) ?usize {
    for (field_info, 0..) |field, i| {
        if (std.mem.eql(u8, field.name, name)) {
            return i;
        }
    }
    return null;
}

/// Find field by short flag
fn findFieldByShort(field_info: anytype, short: u8) ?usize {
    for (field_info, 0..) |field, i| {
        if (field.short) |s| {
            if (s == short) {
                return i;
            }
        }
    }
    return null;
}

/// Find positional field by position
fn findPositionalField(field_info: anytype, position: usize) ?usize {
    var pos_count: usize = 0;
    for (field_info, 0..) |field, i| {
        if (field.positional) {
            if (pos_count == position) {
                return i;
            }
            pos_count += 1;
        }
    }
    return null;
}

/// Count provided positional arguments
fn countProvidedPositional(field_info: anytype, provided: []const []const u8) usize {
    var count: usize = 0;
    for (field_info) |field| {
        if (field.positional) {
            for (provided) |provided_name| {
                if (std.mem.eql(u8, field.name, provided_name)) {
                    count += 1;
                    break;
                }
            }
        }
    }
    return count;
}

/// Check if a field is boolean
fn isBooleanField(comptime T: type, field: meta.FieldMetadata) bool {
    const struct_fields = std.meta.fields(T);
    inline for (struct_fields) |struct_field| {
        if (std.mem.eql(u8, struct_field.name, field.name) or
            std.mem.startsWith(u8, struct_field.name, field.name) or
            std.mem.endsWith(u8, struct_field.name, field.name)) {
            return struct_field.type == bool;
        }
    }
    return false;
}

/// Set field value from string
fn setFieldValue(comptime T: type, result: *T, field: meta.FieldMetadata, value: []const u8, allocator: std.mem.Allocator) !void {
    const struct_fields = std.meta.fields(T);
    
    inline for (struct_fields) |struct_field| {
        // For positional fields, match exact encoded name
        if (field.positional) {
            if (std.mem.startsWith(u8, struct_field.name, "#") and 
                std.mem.endsWith(u8, struct_field.name, field.name)) {
                const field_ptr = &@field(result, struct_field.name);
                
                switch (struct_field.type) {
                    bool => {
                        field_ptr.* = std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1");
                    },
                    u8, u16, u32, u64, usize => {
                        field_ptr.* = std.fmt.parseInt(struct_field.type, value, 10) catch return ParseError.InvalidValue;
                    },
                    i8, i16, i32, i64, isize => {
                        field_ptr.* = std.fmt.parseInt(struct_field.type, value, 10) catch return ParseError.InvalidValue;
                    },
                    f32, f64 => {
                        field_ptr.* = std.fmt.parseFloat(struct_field.type, value) catch return ParseError.InvalidValue;
                    },
                    []const u8 => {
                        field_ptr.* = try allocator.dupe(u8, value);
                    },
                    else => {
                        @compileError("Unsupported field type: " ++ @typeName(struct_field.type));
                    },
                }
                return;
            }
        } else {
            // For non-positional fields, use existing logic
            if (std.mem.eql(u8, struct_field.name, field.name) or
                std.mem.startsWith(u8, struct_field.name, field.name)) {
                const field_ptr = &@field(result, struct_field.name);
                
                switch (struct_field.type) {
                    bool => {
                        field_ptr.* = std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1");
                    },
                    u8, u16, u32, u64, usize => {
                        field_ptr.* = std.fmt.parseInt(struct_field.type, value, 10) catch return ParseError.InvalidValue;
                    },
                    i8, i16, i32, i64, isize => {
                        field_ptr.* = std.fmt.parseInt(struct_field.type, value, 10) catch return ParseError.InvalidValue;
                    },
                    f32, f64 => {
                        field_ptr.* = std.fmt.parseFloat(struct_field.type, value) catch return ParseError.InvalidValue;
                    },
                    []const u8 => {
                        field_ptr.* = try allocator.dupe(u8, value);
                    },
                    else => {
                        @compileError("Unsupported field type: " ++ @typeName(struct_field.type));
                    },
                }
                return;
            }
        }
    }
}

/// Apply default values for fields that weren't provided
fn applyDefaults(comptime T: type, field_info: anytype, result: *T, provided: []const []const u8, allocator: std.mem.Allocator) !void {
    for (field_info) |field| {
        if (field.default) |default_value| {
            var is_provided = false;
            for (provided) |provided_name| {
                if (std.mem.eql(u8, field.name, provided_name)) {
                    is_provided = true;
                    break;
                }
            }
            
            if (!is_provided) {
                try setFieldValue(T, result, field, default_value, allocator);
            }
        }
    }
}

/// Validate required fields
fn validateRequired(comptime T: type, field_info: anytype, result: T, provided: []const []const u8) !void {
    _ = result;
    for (field_info) |field| {
        if (field.required) {
            var is_provided = false;
            for (provided) |provided_name| {
                if (std.mem.eql(u8, field.name, provided_name)) {
                    is_provided = true;
                    break;
                }
            }
            
            if (!is_provided) {
                return ParseError.MissingRequiredArgument;
            }
        }
    }
}

/// Check if help was requested and handle it automatically
fn checkForHelpRequest(comptime T: type, args: []const []const u8) !void {
    // Extract field metadata to find help flags
    const field_info = comptime meta.extractFields(T);
    
    // Scan arguments for help requests
    for (args) |arg| {
        if (std.mem.startsWith(u8, arg, "--")) {
            const flag_name = arg[2..];
            // Check for common help flags
            if (std.mem.eql(u8, flag_name, "help") or std.mem.eql(u8, flag_name, "h")) {
                printHelpAndExit(T);
                return ParseError.HelpRequested;
            }
            
            // Check against struct-defined help flags
            inline for (field_info) |field| {
                if (std.mem.eql(u8, field.name, "help") or std.mem.eql(u8, field.name, "h")) {
                    if (std.mem.eql(u8, flag_name, field.name)) {
                        printHelpAndExit(T);
                        return ParseError.HelpRequested;
                    }
                }
            }
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len == 2) {
            const flag_char = arg[1];
            // Check for common short help flag
            if (flag_char == 'h') {
                printHelpAndExit(T);
                return ParseError.HelpRequested;
            }
            
            // Check against struct-defined short help flags
            inline for (field_info) |field| {
                if (field.short) |short| {
                    if ((std.mem.eql(u8, field.name, "help") or std.mem.eql(u8, field.name, "h")) and
                        flag_char == short) {
                        printHelpAndExit(T);
                        return ParseError.HelpRequested;
                    }
                }
            }
        }
    }
}

/// Print help text and indicate program should exit
fn printHelpAndExit(comptime T: type) void {
    const help_text = help.generate(T);
    std.debug.print("{s}\n", .{help_text});
}

test "parse simple arguments" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"name|n=Test": []const u8 = "",
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--verbose", "--name", "Alice"};
    const result = try parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expect(result.@"verbose|v" == true);
    try std.testing.expectEqualStrings(result.@"name|n=Test", "Alice");
}

test "parse with short flags" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"count|c=5": u32 = 0,
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"-v", "-c", "10"};
    const result = try parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expect(result.@"verbose|v" == true);
    try std.testing.expect(result.@"count|c=5" == 10);
}

test "parse positional arguments" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"#input": []const u8 = "",
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--verbose", "input.txt"};
    const result = try parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expect(result.@"verbose|v" == true);
    try std.testing.expectEqualStrings(result.@"#input", "input.txt");
}

test "parse with integer values" {
    const TestArgs = struct {
        @"count|c=5": u32 = 0,
        @"port|p": u16 = 8080,
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--count", "42", "--port", "3000"};
    const result = try parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expect(result.@"count|c=5" == 42);
    try std.testing.expect(result.@"port|p" == 3000);
}

test "required field validation - missing required field" {
    const TestArgs = struct {
        @"config|c!": []const u8 = "",
        @"verbose|v": bool = false,
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--verbose"};
    const result = parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expectError(ParseError.MissingRequiredArgument, result);
}

test "required field validation - required field provided" {
    const TestArgs = struct {
        @"config|c!": []const u8 = "",
        @"verbose|v": bool = false,
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--verbose", "--config", "test.conf"};
    const result = try parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expect(result.@"verbose|v" == true);
    try std.testing.expectEqualStrings(result.@"config|c!", "test.conf");
}

test "default value handling - string default" {
    const TestArgs = struct {
        @"name|n=Default": []const u8 = "",
        @"verbose|v": bool = false,
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--verbose"};
    const result = try parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expect(result.@"verbose|v" == true);
    try std.testing.expectEqualStrings(result.@"name|n=Default", "Default");
}

test "default value handling - integer default" {
    const TestArgs = struct {
        @"count|c=42": u32 = 0,
        @"verbose|v": bool = false,
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--verbose"};
    const result = try parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expect(result.@"verbose|v" == true);
    try std.testing.expect(result.@"count|c=42" == 42);
}

test "default value handling - override default" {
    const TestArgs = struct {
        @"count|c=42": u32 = 0,
        @"name|n=Default": []const u8 = "",
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--count", "100", "--name", "Custom"};
    const result = try parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expect(result.@"count|c=42" == 100);
    try std.testing.expectEqualStrings(result.@"name|n=Default", "Custom");
}

test "flag with embedded value" {
    const TestArgs = struct {
        @"name|n": []const u8 = "",
        @"count|c": u32 = 0,
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--name=Alice", "--count=42"};
    const result = try parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expectEqualStrings(result.@"name|n", "Alice");
    try std.testing.expect(result.@"count|c" == 42);
}

test "unknown flag error" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--unknown"};
    const result = parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expectError(ParseError.UnknownFlag, result);
}

test "missing value for flag" {
    const TestArgs = struct {
        @"name|n": []const u8 = "",
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--name"};
    const result = parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expectError(ParseError.MissingValue, result);
}

test "automatic help handling - long flag" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"name|n": []const u8 = "",
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--help"};
    const result = parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expectError(ParseError.HelpRequested, result);
}

test "automatic help handling - short flag" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"config|c!": []const u8 = "",
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"-h"};
    const result = parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expectError(ParseError.HelpRequested, result);
}

test "automatic help handling - custom help field" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
        @"help|h": bool = false,
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = &.{"--help"};
    const result = parseFrom(TestArgs, arena.allocator(), test_args);
    
    try std.testing.expectError(ParseError.HelpRequested, result);
}