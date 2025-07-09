//! Metadata extraction and compile-time validation
//!
//! This module handles extracting field metadata from struct types using
//! the automatic DSL and validating argument structures.

const std = @import("std");
const types = @import("types.zig");

pub const FieldMetadata = types.FieldMetadata;

/// Validate a type's structure for CLI argument parsing
pub fn validate(comptime T: type) void {
    const type_info = @typeInfo(T);
    
    switch (type_info) {
        .@"struct" => |struct_info| {
            // Field validation is handled at runtime during parsing
            _ = struct_info;
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




/// Extract field metadata from a struct type
pub fn extractFields(comptime T: type) []const FieldMetadata {
    const type_info = @typeInfo(T);
    
    switch (type_info) {
        .@"struct" => |struct_info| {
            const field_count = struct_info.fields.len;
            if (field_count == 0) return &[_]FieldMetadata{};
            
            // Check if struct has explicit DSL metadata first
            if (extractDslMetadata(T)) |dsl_metadata| {
                return dsl_metadata;
            }
            
            // Build the field array at compile time using a comptime block
            const result = comptime blk: {
                var fields: [field_count]FieldMetadata = undefined;
                for (struct_info.fields, 0..) |field, i| {
                    // Only support automatic DSL - simple field names with no encoding
                    const metadata = FieldMetadata{
                        .name = field.name,
                    };
                    
                    fields[i] = metadata;
                }
                break :blk fields;
            };
            
            return &result;
        },
        else => {
            @compileError("extractFields only works on struct types");
        }
    }
}


/// Extract metadata for structs using function-based DSL with explicit metadata
fn extractDslMetadata(comptime T: type) ?[]const FieldMetadata {
    // Check if the struct has DSL metadata declaration
    if (@hasDecl(T, "dsl_metadata")) {
        // T.dsl_metadata is a pointer to an array, convert to slice
        const metadata_ptr = @field(T, "dsl_metadata");
        return metadata_ptr[0..];
    }
    return null;
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

test "validate automatic DSL struct" {
    const cli = @import("cli.zig");
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        cli.option("count", u32, .{ .short = 'c', .default = 0, .help = "Set count" }),
    });
    
    // Should not cause compile error - validate the wrapper type that has metadata
    validate(TestArgs);
}

test "extractFields with automatic DSL" {
    const cli = @import("cli.zig");
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        cli.option("name", []const u8, .{ .short = 'n', .default = "test", .help = "Set name" }),
    });
    
    // For automatic DSL, we need to extract from the wrapper type that has dsl_metadata
    const fields = extractFields(TestArgs);
    
    try std.testing.expect(fields.len == 2);
    try std.testing.expectEqualStrings(fields[0].name, "verbose");
    try std.testing.expect(fields[0].short.? == 'v');
    try std.testing.expectEqualStrings(fields[0].help.?, "Enable verbose output");
    try std.testing.expectEqualStrings(fields[1].name, "name");
    try std.testing.expect(fields[1].short.? == 'n');
    try std.testing.expectEqualStrings(fields[1].default.?, "test");
}