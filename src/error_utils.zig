//! Error utilities for consistent error creation and formatting
//!
//! This module provides common utilities for creating detailed parse errors
//! to avoid duplication across the codebase.

const std = @import("std");
const types = @import("types.zig");
const meta = @import("meta.zig");

/// Errors that can occur during argument parsing
pub const ParseError = types.ParseError;

/// Create a detailed error with formatted message and suggestion
pub fn createDetailedError(
    error_type: ParseError,
    comptime message_fmt: []const u8,
    message_args: anytype,
    context: ?[]const u8,
    comptime suggestion_fmt: []const u8,
    suggestion_args: anytype,
    allocator: std.mem.Allocator,
) !types.DetailedParseError {
    const message = try std.fmt.allocPrint(allocator, message_fmt, message_args);
    const suggestion = try std.fmt.allocPrint(allocator, suggestion_fmt, suggestion_args);
    
    return types.DetailedParseError{
        .error_type = error_type,
        .message = message,
        .context = context,
        .suggestion = suggestion,
    };
}

/// Create an unknown flag error with suggestions
pub fn createUnknownFlagError(
    flag: []const u8,
    alternatives: ?[]const []const u8,
    allocator: std.mem.Allocator,
) !types.DetailedParseError {
    _ = allocator;
    return types.DetailedParseError{
        .error_type = ParseError.UnknownFlag,
        .message = "Unknown flag",
        .context = flag,
        .suggestion = "Use --help to see available options",
        .alternatives = alternatives,
    };
}

/// Create a missing value error
pub fn createMissingValueError(flag: []const u8, allocator: std.mem.Allocator) !types.DetailedParseError {
    _ = allocator;
    return types.DetailedParseError{
        .error_type = ParseError.MissingValue,
        .message = "Flag requires a value",
        .context = flag,
        .suggestion = "Provide a value after the flag (e.g., --flag=value or --flag value)",
    };
}

/// Create an invalid value error
pub fn createInvalidValueError(
    flag: []const u8,
    expected_type: []const u8,
    allocator: std.mem.Allocator,
) !types.DetailedParseError {
    return createDetailedError(
        ParseError.InvalidValue,
        "Invalid value for flag",
        .{},
        flag,
        "Expected {s} value for flag",
        .{expected_type},
        allocator,
    );
}

/// Create a missing required argument error
pub fn createMissingRequiredError(field_name: []const u8, allocator: std.mem.Allocator) !types.DetailedParseError {
    return createDetailedError(
        ParseError.MissingRequiredArgument,
        "Missing required argument",
        .{},
        field_name,
        "The --{s} flag is required",
        .{field_name},
        allocator,
    );
}