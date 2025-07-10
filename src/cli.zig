//! Zync-CLI Automatic DSL - Zero Duplication, No Explicit Metadata
//!
//! This module implements a DSL where metadata is automatically extracted
//! from field definitions without requiring explicit dsl_metadata declarations.

const std = @import("std");
const FieldMetadata = @import("meta.zig").FieldMetadata;



/// Configuration for boolean flag arguments
pub const FlagConfig = struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    default: ?bool = null,
    hidden: bool = false,
    env_var: ?[]const u8 = null,
};

/// Configuration for optional arguments with defaults
pub fn OptionConfig(comptime T: type) type {
    return struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        default: T,
        hidden: bool = false,
        env_var: ?[]const u8 = null,
    };
}

/// Configuration for required arguments
pub fn RequiredConfig(comptime T: type) type {
    _ = T;
    return struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        hidden: bool = false,
        env_var: ?[]const u8 = null,
    };
}

/// Configuration for positional arguments
pub fn PositionalConfig(comptime T: type) type {
    return struct {
        help: ?[]const u8 = null,
        default: ?T = null,
        required: bool = true,
    };
}

/// Container that holds both a value and its metadata
pub fn FieldDef(comptime T: type) type {
    return struct {
        value: T,
        metadata: FieldMetadata,
        
        const Self = @This();
        
        /// Get the default value for this field
        pub fn getValue(self: Self) T {
            return self.value;
        }
        
        /// Get the metadata for this field
        pub fn getMeta(self: Self) FieldMetadata {
            return self.metadata;
        }
    };
}

/// Create a boolean flag field definition with metadata
pub fn flag(comptime field_name: []const u8, comptime config: FlagConfig) FieldDef(bool) {
    const metadata = FieldMetadata{
        .name = field_name,
        .short = config.short,
        .help = config.help,
        .hidden = config.hidden,
        .env_var = config.env_var,
    };
    
    return FieldDef(bool){
        .value = config.default orelse false,
        .metadata = metadata,
    };
}

/// Create an option field definition with metadata
pub fn option(comptime field_name: []const u8, comptime T: type, comptime config: OptionConfig(T)) FieldDef(T) {
    const default_str = blk: {
        const default_val = config.default;
        if (T == []const u8) {
            break :blk default_val;
        } else if (@typeInfo(T) == .int) {
            break :blk std.fmt.comptimePrint("{}", .{default_val});
        } else if (@typeInfo(T) == .float) {
            break :blk std.fmt.comptimePrint("{d}", .{default_val});
        } else if (T == bool) {
            break :blk if (default_val) "true" else "false";
        } else {
            break :blk null;
        }
    };
    
    const metadata = FieldMetadata{
        .name = field_name,
        .short = config.short,
        .help = config.help,
        .default = default_str,
        .hidden = config.hidden,
        .env_var = config.env_var,
    };
    
    return FieldDef(T){
        .value = config.default,
        .metadata = metadata,
    };
}

/// Create a required field definition with metadata
pub fn required(comptime field_name: []const u8, comptime T: type, comptime config: RequiredConfig(T)) FieldDef(T) {
    const metadata = FieldMetadata{
        .name = field_name,
        .short = config.short,
        .help = config.help,
        .required = true,
        .hidden = config.hidden,
        .env_var = config.env_var,
    };
    
    return FieldDef(T){
        .value = @as(T, undefined), // Will be set during parsing
        .metadata = metadata,
    };
}

/// Create a positional field definition with metadata
pub fn positional(comptime field_name: []const u8, comptime T: type, comptime config: PositionalConfig(T)) FieldDef(T) {
    const default_str = if (config.default) |default_val| blk: {
        if (T == []const u8) {
            break :blk default_val;
        } else if (@typeInfo(T) == .int) {
            break :blk std.fmt.comptimePrint("{}", .{default_val});
        } else if (@typeInfo(T) == .float) {
            break :blk std.fmt.comptimePrint("{d}", .{default_val});
        } else if (T == bool) {
            break :blk if (default_val) "true" else "false";
        } else {
            break :blk null;
        }
    } else null;
    
    const metadata = FieldMetadata{
        .name = field_name,
        .help = config.help,
        .default = default_str,
        .required = config.required,
        .positional = true,
    };
    
    return FieldDef(T){
        .value = config.default orelse @as(T, undefined),
        .metadata = metadata,
    };
}

/// Configuration for the Args struct
pub const ArgsConfig = struct {
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
};

/// Automatic struct generator that creates CLI argument structs
/// This creates a struct where metadata is automatically extracted from field definitions
/// Usage: Args(.{ field_definitions, config }) or Args(.{ field_definitions })
pub fn Args(args: anytype) type {
    const args_info = @typeInfo(@TypeOf(args));
    if (args_info == .@"struct" and args_info.@"struct".is_tuple) {
        const fields = args_info.@"struct".fields;
        if (fields.len == 2) {
            // Two arguments: field_definitions and config
            // Convert the anonymous struct to ArgsConfig
            const config = ArgsConfig{
                .title = if (@hasField(@TypeOf(args[1]), "title")) args[1].title else null,
                .description = if (@hasField(@TypeOf(args[1]), "description")) args[1].description else null,
            };
            return ArgsWithConfig(args[0], config);
        } else if (fields.len == 1) {
            // One argument: field_definitions only
            return ArgsWithConfig(args[0], ArgsConfig{});
        } else {
            @compileError("Args() expects 1 or 2 arguments");
        }
    } else {
        // Direct field definitions array
        return ArgsWithConfig(args, ArgsConfig{});
    }
}

/// Internal function that implements the Args generation logic
fn ArgsWithConfig(comptime field_definitions: anytype, comptime config: ArgsConfig) type {
    const field_count = field_definitions.len;
    
    // Extract metadata from field definitions
    const metadata_array = comptime blk: {
        var metadata: [field_count]FieldMetadata = undefined;
        for (field_definitions, 0..) |field_def, i| {
            metadata[i] = field_def.metadata;
        }
        break :blk metadata;
    };
    
    // Create struct fields for each definition using the actual field names from metadata
    const struct_fields = comptime blk: {
        var fields: [field_count]std.builtin.Type.StructField = undefined;
        for (field_definitions, 0..) |field_def, i| {
            // Create a null-terminated string for the field name
            const field_name = field_def.metadata.name;
            const field_name_z = field_name ++ [_]u8{0}; // Add null terminator
            
            fields[i] = std.builtin.Type.StructField{
                .name = field_name_z[0..field_name.len :0], // Create null-terminated slice
                .type = @TypeOf(field_def.value),
                .default_value_ptr = @as(?*const anyopaque, @ptrCast(&field_def.value)),
                .is_comptime = false,
                .alignment = @alignOf(@TypeOf(field_def.value)),
            };
        }
        break :blk fields;
    };
    
    // Generate the struct type using @Type
    const GeneratedStruct = @Type(std.builtin.Type{
        .@"struct" = std.builtin.Type.Struct{
            .layout = .auto,
            .fields = &struct_fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
    
    // Return a wrapper struct that provides access to the generated struct
    return struct {
        pub const ArgsType = GeneratedStruct;
        
        // AUTOMATIC metadata - NO explicit declaration needed!
        pub const dsl_metadata = &metadata_array;
        
        // Store the configuration
        pub const args_config = config;
        
        // Initialize with defaults
        pub fn init() ArgsType {
            return ArgsType{};
        }
        
        // Direct struct access
        args: ArgsType,
        
        pub fn initFromStruct(s: ArgsType) @This() {
            return @This(){ .args = s };
        }
        
        
        // Method-style API for ergonomic parsing
        /// Parse command-line arguments from process argv
        /// Automatically handles help requests and exits gracefully
        /// NOTE: Use arena allocator for automatic cleanup
        pub fn parse(allocator: std.mem.Allocator) !ArgsType {
            const args = try std.process.argsAlloc(allocator);
            defer std.process.argsFree(allocator, args);
            // Skip the program name (first argument)
            const cli_args = if (args.len > 0) args[1..] else args;
            return parseFrom(allocator, cli_args) catch |err| switch (err) {
                error.HelpRequested => {
                    // In test mode, re-throw the error for test control
                    if (@import("builtin").is_test) {
                        return err;
                    }
                    // In normal mode, help was already displayed, exit gracefully
                    std.process.exit(0);
                },
                else => {
                    // In test mode, return error for testing
                    if (@import("builtin").is_test) {
                        return err;
                    }
                    // In normal mode, parser already exited, this should never be reached
                    unreachable;
                },
            };
        }
        
        /// Parse command-line arguments from custom argument array
        /// Automatically handles help requests and exits gracefully
        /// NOTE: Use arena allocator for automatic cleanup
        pub fn parseFrom(allocator: std.mem.Allocator, args: []const []const u8) !ArgsType {
            return parseFromRaw(allocator, args) catch |err| switch (err) {
                error.HelpRequested => {
                    // In test mode, re-throw the error for test control
                    if (@import("builtin").is_test) {
                        return err;
                    }
                    // In normal mode, help was already displayed, exit gracefully
                    std.process.exit(0);
                },
                else => {
                    // In test mode, return error for testing
                    if (@import("builtin").is_test) {
                        return err;
                    }
                    // In normal mode, parser already exited, this should never be reached
                    unreachable;
                },
            };
        }
        
        /// Parse command-line arguments from custom argument array (raw version)
        /// Returns HelpRequested error for manual handling - use this only when you need
        /// full control over help behavior (e.g., custom help handlers)
        /// NOTE: Use arena allocator for automatic cleanup
        pub fn parseFromRaw(allocator: std.mem.Allocator, args: []const []const u8) !ArgsType {
            const parser = @import("parser.zig");
            return parser.parseFromWithMeta(ArgsType, @This(), allocator, args);
        }
        
        /// Generate formatted help text for this argument structure
        pub fn help(allocator: std.mem.Allocator) ![]const u8 {
            const help_gen = @import("help.zig");
            // Extract the actual program name from process arguments
            const program_name = help_gen.extractProgramName(allocator) catch "program";
            return help_gen.formatHelpWithConfig(@This(), allocator, program_name, @This().args_config);
        }
        
        /// Validate arguments structure at compile time
        pub fn validate() void {
            const meta = @import("meta.zig");
            return meta.validate(@This());
        }
    };
}


test "automatic DSL" {
    // Automatic DSL: NO explicit metadata declarations needed!
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
        option("count", u32, .{ .short = 'c', .default = 1, .help = "Number of iterations" }),
        required("config", []const u8, .{ .short = 'f', .help = "Configuration file path" }),
    });
    
    // Verify automatic metadata extraction
    const metadata = TestArgs.dsl_metadata;
    try std.testing.expect(metadata.len == 4);
    
    // Verify the metadata is correct
    try std.testing.expectEqualStrings(metadata[0].name, "verbose");
    try std.testing.expect(metadata[0].short.? == 'v');
    try std.testing.expectEqualStrings(metadata[0].help.?, "Enable verbose output");
    
    try std.testing.expectEqualStrings(metadata[1].name, "name");
    try std.testing.expect(metadata[1].short.? == 'n');
    try std.testing.expectEqualStrings(metadata[1].default.?, "World");
    
    try std.testing.expectEqualStrings(metadata[2].name, "count");
    try std.testing.expect(metadata[2].short.? == 'c');
    try std.testing.expectEqualStrings(metadata[2].default.?, "1");
    
    try std.testing.expectEqualStrings(metadata[3].name, "config");
    try std.testing.expect(metadata[3].short.? == 'f');
    try std.testing.expect(metadata[3].required == true);
    
    // Test that the struct works normally
    const args = TestArgs.init();
    // The generated struct has the right type
    try std.testing.expect(@TypeOf(args) == TestArgs.ArgsType);
    
    // We can access fields through the actual struct
    // Note: In practice, the parser would return TestArgs.ArgsType
    const struct_info = @typeInfo(TestArgs.ArgsType).@"struct";
    try std.testing.expect(struct_info.fields.len == 4);
    
    // Test that field names match what we expect
    try std.testing.expectEqualStrings(struct_info.fields[0].name, "verbose");
    try std.testing.expectEqualStrings(struct_info.fields[1].name, "name");
    try std.testing.expectEqualStrings(struct_info.fields[2].name, "count");
    try std.testing.expectEqualStrings(struct_info.fields[3].name, "config");
}

test "method-style API" {
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
        required("config", []const u8, .{ .short = 'c', .help = "Configuration file path" }),
    });
    
    // Test that the method-style API exists and has the right type
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const test_args = &.{"--verbose", "--name", "Alice", "--config", "test.conf"};
    
    // Test parseFrom method with arena allocator (automatic cleanup)
    const result = try TestArgs.parseFrom(allocator, test_args);
    
    // Verify the parsing worked
    try std.testing.expect(result.verbose == true);
    try std.testing.expectEqualStrings(result.name, "Alice");
    try std.testing.expectEqualStrings(result.config, "test.conf");
    
    // Test help method exists
    const help_text = try TestArgs.help(allocator);
    try std.testing.expect(help_text.len > 0);
    
    // Test validate method exists (compile-time check)
    TestArgs.validate();
}

test "help handling API" {
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
    });
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Test parseFromRaw returns HelpRequested error for manual handling
    const help_args = &.{"--help"};
    try std.testing.expectError(error.HelpRequested, TestArgs.parseFromRaw(allocator, help_args));
    
    // Test parseFrom returns HelpRequested error in test mode 
    // (automatic help handling is disabled in tests)
    try std.testing.expectError(error.HelpRequested, TestArgs.parseFrom(allocator, help_args));
    
    // Test normal args work fine
    const normal_args = &.{"--verbose", "--name", "Alice"};
    const result = try TestArgs.parseFrom(allocator, normal_args);
    try std.testing.expect(result.verbose == true);
    try std.testing.expectEqualStrings(result.name, "Alice");
}

test "title and description API" {
    const TestArgs = Args(.{
        &.{
            flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
            option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
        },
        .{
            .title = "🚀 Test Application 🚀",
            .description = "A test application with custom title and description.",
        },
    });
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Test that the configuration is stored
    try std.testing.expectEqualStrings(TestArgs.args_config.title.?, "🚀 Test Application 🚀");
    try std.testing.expectEqualStrings(TestArgs.args_config.description.?, "A test application with custom title and description.");
    
    // Test help generation includes the custom title and description
    const help_text = try TestArgs.help(allocator);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "🚀 Test Application 🚀") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "A test application with custom title and description.") != null);
}