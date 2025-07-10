//! Test utilities for consistent behavior across the library
//!
//! This module provides common test utilities to avoid duplication.

const std = @import("std");

/// Check if currently running in test mode
pub inline fn isTestMode() bool {
    return @import("builtin").is_test;
}

/// Return early if in test mode, useful for avoiding output/hanging in tests
pub inline fn exitIfTest() void {
    if (isTestMode()) return;
}

/// Return an error if in test mode, useful for test control flow
pub inline fn errorIfTest(comptime error_type: anytype) !void {
    if (isTestMode()) return error_type;
}