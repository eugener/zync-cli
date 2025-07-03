//! Core argument parsing functionality
//!
//! This module implements the main parsing logic for command-line arguments,
//! including tokenization, type conversion, and validation.

const std = @import("std");
const types = @import("types.zig");
const meta = @import("meta.zig");

const ParseResult = types.ParseResult;
const ParseError = types.ParseError;
const Diagnostic = types.Diagnostic;

/// Parse arguments from a string array into the specified type
pub fn parseFrom(comptime T: type, allocator: std.mem.Allocator, args: []const []const u8) !ParseResult(T) {
    // Validate the structure at compile time
    comptime meta.validate(T);
    
    // Initialize the result structure with defaults
    var result = T{};
    var diagnostics = std.ArrayList(Diagnostic).init(allocator);
    
    // Extract field metadata at compile time
    const field_info = comptime meta.extractFields(T);
    
    
    // Skip the program name (first argument)
    const cli_args = if (args.len > 0) args[1..] else args;
    
    // Parse arguments
    var i: usize = 0;
    while (i < cli_args.len) {
        const arg = cli_args[i];
        
        if (std.mem.startsWith(u8, arg, "--")) {
            // Long flag (--flag or --flag=value)
            i = try parseLongFlag(T, field_info, &result, cli_args, i, &diagnostics, allocator);
        } else if (std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
            // Short flag (-f or -fvalue)
            i = try parseShortFlag(T, field_info, &result, cli_args, i, &diagnostics, allocator);
        } else {
            // Positional argument
            i = try parsePositional(T, field_info, &result, cli_args, i, &diagnostics, allocator);
        }
    }
    
    // Check for missing required arguments
    try validateRequired(T, field_info, result, &diagnostics, allocator);
    
    return ParseResult(T){
        .args = result,
        .diagnostics = try diagnostics.toOwnedSlice(),
        .allocator = allocator,
    };
}

/// Parse a long flag (--flag or --flag=value)
fn parseLongFlag(
    comptime T: type,
    field_info: anytype,
    result: *T,
    args: []const []const u8,
    index: usize,
    diagnostics: *std.ArrayList(Diagnostic),
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
        } else {
            try diagnostics.append(Diagnostic{
                .level = .err,
                .message = try std.fmt.allocPrint(allocator, "Unknown flag: --{s}", .{flag_name}),
                .suggestion = blk: {
                    const similar = try findSimilarFlag(field_info, flag_name, allocator);
                    break :blk if (similar) |s| try std.fmt.allocPrint(allocator, "Did you mean '--{s}'?", .{s}) else null;
                },
                .location = .{ .arg_index = index, .char_index = 0 },
            });
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
                return index + 1;
            } else {
                // Flag requires a value, get it from next argument
                if (index + 1 >= args.len) {
                    try diagnostics.append(Diagnostic{
                        .level = .err,
                        .message = try std.fmt.allocPrint(allocator, "Flag --{s} requires a value", .{flag_name}),
                        .location = .{ .arg_index = index, .char_index = 0 },
                    });
                    return index + 1;
                }
                
                const flag_value = args[index + 1];
                try setFieldValue(T, result, field, flag_value, allocator);
                return index + 2;
            }
        } else {
            try diagnostics.append(Diagnostic{
                .level = .err,
                .message = try std.fmt.allocPrint(allocator, "Unknown flag: --{s}", .{flag_name}),
                .suggestion = blk: {
                    const similar = try findSimilarFlag(field_info, flag_name, allocator);
                    break :blk if (similar) |s| try std.fmt.allocPrint(allocator, "Did you mean '--{s}'?", .{s}) else null;
                },
                .location = .{ .arg_index = index, .char_index = 0 },
            });
            return index + 1;
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
    diagnostics: *std.ArrayList(Diagnostic),
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
            return index + 1;
        } else if (isBooleanField(T, field)) {
            // Boolean flag
            try setFieldValue(T, result, field, "true", allocator);
            return index + 1;
        } else {
            // Flag requires a value from next argument
            if (index + 1 >= args.len) {
                try diagnostics.append(Diagnostic{
                    .level = .err,
                    .message = try std.fmt.allocPrint(allocator, "Flag -{c} requires a value", .{flag_char}),
                    .location = .{ .arg_index = index, .char_index = 1 },
                });
                return index + 1;
            }
            
            const flag_value = args[index + 1];
            try setFieldValue(T, result, field, flag_value, allocator);
            return index + 2;
        }
    } else {
        try diagnostics.append(Diagnostic{
            .level = .err,
            .message = try std.fmt.allocPrint(allocator, "Unknown flag: -{c}", .{flag_char}),
            .location = .{ .arg_index = index, .char_index = 1 },
        });
        return index + 1;
    }
}

/// Parse a positional argument
fn parsePositional(
    comptime T: type,
    field_info: anytype,
    result: *T,
    args: []const []const u8,
    index: usize,
    diagnostics: *std.ArrayList(Diagnostic),
    allocator: std.mem.Allocator,
) !usize {
    // For now, just add a warning about unrecognized positional arguments
    // This will be implemented properly when we add positional argument support
    _ = field_info;
    _ = result;
    
    try diagnostics.append(Diagnostic{
        .level = .warning,
        .message = try std.fmt.allocPrint(allocator, "Unrecognized argument: {s}", .{args[index]}),
        .location = .{ .arg_index = index, .char_index = 0 },
    });
    
    return index + 1;
}

/// Validate that all required fields have been provided
fn validateRequired(
    comptime T: type,
    field_info: anytype,
    result: T,
    diagnostics: *std.ArrayList(Diagnostic),
    allocator: std.mem.Allocator,
) !void {
    // This will be implemented when we add field metadata extraction
    _ = field_info;
    _ = result;
    _ = diagnostics;
    _ = allocator;
}

/// Find a field by its long name
fn findFieldByName(field_info: []const types.FieldMetadata, name: []const u8) ?usize {
    for (field_info, 0..) |field, i| {
        if (std.mem.eql(u8, field.name, name)) {
            return i;
        }
        // Check aliases if present
        if (field.aliases) |aliases| {
            for (aliases) |alias| {
                if (std.mem.eql(u8, alias, name)) {
                    return i;
                }
            }
        }
    }
    return null;
}

/// Find a field by its short flag character
fn findFieldByShort(field_info: []const types.FieldMetadata, short: u8) ?usize {
    for (field_info, 0..) |field, i| {
        if (field.short) |field_short| {
            if (field_short == short) {
                return i;
            }
        }
    }
    return null;
}

/// Check if a field is boolean based on metadata and type
fn isBooleanField(comptime T: type, field: types.FieldMetadata) bool {
    // Check the actual field type in the struct
    const type_info = @typeInfo(T);
    if (type_info != .@"struct") return false;
    
    const struct_info = type_info.@"struct";
    inline for (struct_info.fields) |struct_field| {
        const parsed_field = meta.parseFieldEncoding(struct_field.name);
        if (std.mem.eql(u8, parsed_field.name, field.name)) {
            return @typeInfo(struct_field.type) == .bool;
        }
    }
    
    return false;
}

/// Set a field value from a string
fn setFieldValue(comptime T: type, result: *T, field: types.FieldMetadata, value: []const u8, allocator: std.mem.Allocator) !void {
    // For now, implement basic type conversion
    // This will be expanded to handle all types properly
    
    _ = allocator; // Will be used for string allocation later
    
    const type_info = @typeInfo(T);
    if (type_info != .@"struct") {
        @compileError("setFieldValue only works with struct types");
    }
    
    const struct_info = type_info.@"struct";
    inline for (struct_info.fields) |struct_field| {
        // Parse the field to get its base name
        const parsed_field = meta.parseFieldEncoding(struct_field.name);
            
        if (std.mem.eql(u8, parsed_field.name, field.name)) {
            const field_type = struct_field.type;
            const field_ptr = &@field(result.*, struct_field.name);
            
            // Convert string value to the appropriate type
            switch (@typeInfo(field_type)) {
                .bool => {
                    field_ptr.* = std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1");
                },
                .int => {
                    field_ptr.* = std.fmt.parseInt(field_type, value, 10) catch {
                        return ParseError.InvalidValue;
                    };
                },
                .float => {
                    field_ptr.* = std.fmt.parseFloat(field_type, value) catch {
                        return ParseError.InvalidValue;
                    };
                },
                .pointer => |ptr| {
                    if (ptr.size == .slice and ptr.child == u8) {
                        // String type - for now just reference the input
                        // TODO: Properly allocate and manage string memory
                        field_ptr.* = value;
                    }
                },
                .optional => |opt| {
                    // Handle optional types
                    switch (@typeInfo(opt.child)) {
                        .pointer => |ptr| {
                            if (ptr.size == .slice and ptr.child == u8) {
                                field_ptr.* = value;
                            }
                        },
                        else => {
                            // TODO: Handle other optional types
                            field_ptr.* = null;
                        }
                    }
                },
                else => {
                    // For now, skip unsupported types
                    return;
                }
            }
            return;
        }
    }
}

/// Extract the actual field name from an encoded field name
fn extractFieldName(encoded_name: []const u8) []const u8 {
    if (std.mem.startsWith(u8, encoded_name, "@\"") and std.mem.endsWith(u8, encoded_name, "\"")) {
        const inner = encoded_name[2..encoded_name.len-1];
        
        // Find the base name (before any special characters)
        for (inner, 0..) |char, i| {
            if (char == '|' or char == '!' or char == '=' or char == '#' or 
                char == '*' or char == '+' or char == '$' or char == '~' or 
                char == '@' or char == '%' or char == '&' or char == '"') {
                if (i == 0 and char == '#') {
                    // Positional argument, skip the #
                    continue;
                }
                return if (char == '#') inner[1..i] else inner[0..i];
            }
        }
        return if (std.mem.startsWith(u8, inner, "#")) inner[1..] else inner;
    }
    return encoded_name;
}

/// Find a similar flag name for suggestions
fn findSimilarFlag(field_info: []const types.FieldMetadata, name: []const u8, allocator: std.mem.Allocator) !?[]const u8 {
    // Simple suggestion algorithm - find the closest name by edit distance
    _ = allocator; // Will be used for formatting suggestions later
    
    var best_match: ?[]const u8 = null;
    var best_distance: usize = std.math.maxInt(usize);
    
    for (field_info) |field| {
        const distance = editDistance(name, field.name);
        if (distance < best_distance and distance <= 2) { // Only suggest if reasonably close
            best_distance = distance;
            best_match = field.name;
        }
    }
    
    return best_match;
}

/// Calculate simple edit distance between two strings
fn editDistance(a: []const u8, b: []const u8) usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;
    
    // Simple implementation - count character differences
    var differences: usize = 0;
    const min_len = @min(a.len, b.len);
    
    for (0..min_len) |i| {
        if (a[i] != b[i]) {
            differences += 1;
        }
    }
    
    // Add length difference
    differences += @max(a.len, b.len) - min_len;
    
    return differences;
}

test "parseFrom basic functionality" {
    const TestArgs = struct {
        verbose: bool = false,
    };
    
    const allocator = std.testing.allocator;
    
    // Test parsing empty arguments
    var result = try parseFrom(TestArgs, allocator, &.{"test"});
    defer result.deinit();
    
    try std.testing.expect(result.args.verbose == false);
}

test "parseFrom with boolean flag" {
    const TestArgs = struct {
        @"verbose|v": bool = false,
    };
    
    const allocator = std.testing.allocator;
    
    // Test parsing --verbose
    var result1 = try parseFrom(TestArgs, allocator, &.{"test", "--verbose"});
    defer result1.deinit();
    try std.testing.expect(result1.args.@"verbose|v" == true);
    
    // Test parsing -v
    var result2 = try parseFrom(TestArgs, allocator, &.{"test", "-v"});
    defer result2.deinit();
    try std.testing.expect(result2.args.@"verbose|v" == true);
}

test "parseFrom with string value" {
    const TestArgs = struct {
        @"name|n": []const u8 = "default",
    };
    
    const allocator = std.testing.allocator;
    
    // Test parsing --name value
    var result1 = try parseFrom(TestArgs, allocator, &.{"test", "--name", "hello"});
    defer result1.deinit();
    try std.testing.expectEqualStrings(result1.args.@"name|n", "hello");
    
    // Test parsing --name=value
    var result2 = try parseFrom(TestArgs, allocator, &.{"test", "--name=world"});
    defer result2.deinit();
    try std.testing.expectEqualStrings(result2.args.@"name|n", "world");
    
    // Test parsing -n value
    var result3 = try parseFrom(TestArgs, allocator, &.{"test", "-n", "short"});
    defer result3.deinit();
    try std.testing.expectEqualStrings(result3.args.@"name|n", "short");
}

test "parseFrom with integer value" {
    const TestArgs = struct {
        @"count|c": u32 = 0,
    };
    
    const allocator = std.testing.allocator;
    
    // Test parsing --count 42
    var result = try parseFrom(TestArgs, allocator, &.{"test", "--count", "42"});
    defer result.deinit();
    try std.testing.expect(result.args.@"count|c" == 42);
}