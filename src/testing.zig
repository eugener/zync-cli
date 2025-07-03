//! Testing utilities for the Zync-CLI library
//!
//! This module provides helper functions for testing CLI argument parsing
//! and validation in user code.

const std = @import("std");
const types = @import("types.zig");
const parser = @import("parser.zig");

const ParseResult = types.ParseResult;
const ParseError = types.ParseError;

/// Parse arguments for testing purposes
pub fn parse(comptime T: type, args: []const []const u8) !ParseResult(T) {
    return parser.parseFrom(T, std.testing.allocator, args);
}

/// Parse arguments and automatically clean up memory
pub fn parseAndCleanup(comptime T: type, args: []const []const u8) !T {
    var result = try parse(T, args);
    defer result.deinit();
    return result.args;
}

/// Expect that parsing succeeds and returns the expected result
pub fn expectParse(comptime T: type, args: []const []const u8, expected: T) !void {
    const result = try parseAndCleanup(T, args);
    try expectEqualValues(T, expected, result);
}

/// Expect that parsing fails with the specified error
pub fn expectParseError(expected_error: ParseError, comptime T: type, args: []const []const u8) !void {
    const result = parse(T, args);
    try std.testing.expectError(expected_error, result);
}

/// Expect that parsing succeeds but generates diagnostics
pub fn expectDiagnostics(comptime T: type, args: []const []const u8, expected_count: usize) !void {
    var result = try parse(T, args);
    defer result.deinit();
    
    try std.testing.expect(result.diagnostics.len == expected_count);
}

/// Compare two values of the same type for equality
fn expectEqualValues(comptime T: type, expected: T, actual: T) !void {
    const type_info = @typeInfo(T);
    
    switch (type_info) {
        .@"struct" => |struct_info| {
            inline for (struct_info.fields) |field| {
                const expected_field = @field(expected, field.name);
                const actual_field = @field(actual, field.name);
                try expectEqualValues(field.type, expected_field, actual_field);
            }
        },
        .bool => {
            try std.testing.expect(expected == actual);
        },
        .int => {
            try std.testing.expect(expected == actual);
        },
        .float => {
            try std.testing.expectApproxEqRel(expected, actual, 1e-6);
        },
        .pointer => |ptr| {
            if (ptr.size == .slice and ptr.child == u8) {
                try std.testing.expectEqualStrings(expected, actual);
            } else {
                try std.testing.expect(expected == actual);
            }
        },
        .optional => {
            if (expected == null and actual == null) {
                return;
            }
            if (expected == null or actual == null) {
                try std.testing.expect(false); // One is null, other isn't
            }
            try expectEqualValues(@TypeOf(expected.?), expected.?, actual.?);
        },
        .@"enum" => {
            try std.testing.expect(expected == actual);
        },
        else => {
            // For other types, just compare directly
            try std.testing.expect(expected == actual);
        }
    }
}

// Re-export common testing functions for convenience
pub const expect = std.testing.expect;
pub const expectEqual = std.testing.expectEqual;
pub const expectEqualStrings = std.testing.expectEqualStrings;
pub const expectError = std.testing.expectError;
pub const allocator = std.testing.allocator;

test "parse basic arguments" {
    const TestArgs = struct {
        verbose: bool = false,
        count: u32 = 0,
    };
    
    var result = try parse(TestArgs, &.{"test"});
    defer result.deinit();
    
    try expect(result.args.verbose == false);
    try expect(result.args.count == 0);
}

test "parseAndCleanup" {
    const TestArgs = struct {
        verbose: bool = false,
    };
    
    const args = try parseAndCleanup(TestArgs, &.{"test"});
    try expect(args.verbose == false);
}

test "expectEqual struct" {
    const TestArgs = struct {
        verbose: bool = false,
        count: u32 = 42,
    };
    
    const expected = TestArgs{ .verbose = true, .count = 42 };
    const actual = TestArgs{ .verbose = true, .count = 42 };
    
    try expectEqualValues(TestArgs, expected, actual);
}

test "expectEqual string" {
    try expectEqualValues([]const u8, "hello", "hello");
}

test "expectEqual optional" {
    const expected: ?u32 = 42;
    const actual: ?u32 = 42;
    try expectEqualValues(?u32, expected, actual);
    
    const expected_null: ?u32 = null;
    const actual_null: ?u32 = null;
    try expectEqualValues(?u32, expected_null, actual_null);
}