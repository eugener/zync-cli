//! Field utilities for consistent struct field operations
//!
//! This module provides common utilities for working with struct fields
//! to avoid duplication across the codebase.

const std = @import("std");
const meta = @import("meta.zig");

/// Find a struct field by name with fuzzy matching
pub fn findFieldByName(comptime T: type, field_name: []const u8) ?std.builtin.Type.StructField {
    const struct_fields = std.meta.fields(T);
    inline for (struct_fields) |struct_field| {
        if (std.mem.eql(u8, struct_field.name, field_name) or
            std.mem.startsWith(u8, struct_field.name, field_name) or
            std.mem.endsWith(u8, struct_field.name, field_name)) {
            return struct_field;
        }
    }
    return null;
}

/// Check if a field matches a metadata field (handles positional vs regular fields)
pub fn fieldMatches(struct_field: std.builtin.Type.StructField, field: meta.FieldMetadata) bool {
    return if (field.positional)
        // For positional fields, match field name directly (automatic DSL uses clean names)
        std.mem.eql(u8, struct_field.name, field.name)
    else
        // For non-positional fields, use fuzzy matching
        std.mem.eql(u8, struct_field.name, field.name) or std.mem.startsWith(u8, struct_field.name, field.name);
}

/// Check if a struct field is boolean by type
pub fn isFieldBoolean(comptime T: type, field: meta.FieldMetadata) bool {
    const struct_fields = std.meta.fields(T);
    inline for (struct_fields) |struct_field| {
        if (fieldMatches(struct_field, field)) {
            return struct_field.type == bool;
        }
    }
    return false;
}

/// Get field type for a metadata field
pub fn getFieldType(comptime T: type, field_name: []const u8) ?type {
    const struct_fields = std.meta.fields(T);
    inline for (struct_fields) |struct_field| {
        if (std.mem.eql(u8, struct_field.name, field_name)) {
            return struct_field.type;
        }
    }
    return null;
}