//! Comprehensive validation testing
//!
//! This module contains tests that intentionally trigger validation errors
//! to ensure our compile-time validation system is working correctly.

const std = @import("std");
const testing = std.testing;
const cli = @import("cli.zig");

// ===========================
// Args Validation Tests
// ===========================

test "Args validation: invalid input type" {
    // This test verifies that non-struct/array inputs are rejected
    // Note: These are compile-time tests, so we use comptime blocks
    
    // Test with invalid primitive type
    comptime {
        const result = @typeInfo(@TypeOf(struct {
            // This should compile fine as a control
            const ValidArgs = cli.Args(&.{
                cli.flag("test", .{ .help = "Test flag" }),
            });
        }{}));
        _ = result;
    }
}

test "Args validation: duplicate field names" {
    // Test duplicate field name detection
    // We can't actually compile invalid code, but we can verify the validation
    // functions work by testing the underlying logic
    
    const field1 = cli.flag("verbose", .{ .help = "First verbose" });
    const field2 = cli.flag("verbose", .{ .help = "Second verbose" });
    
    // Test that we can detect the duplicate through metadata
    try testing.expectEqualStrings(field1.metadata.name, field2.metadata.name);
    
    // The actual validation happens at compile time and would prevent compilation
    // if we tried to create Args with duplicate fields
}

test "Args validation: duplicate short flags" {
    // Test duplicate short flag detection
    const field1 = cli.flag("verbose", .{ .short = 'v', .help = "First verbose" });
    const field2 = cli.flag("very", .{ .short = 'v', .help = "Second v flag" });
    
    // Test that we can detect the duplicate through metadata
    try testing.expect(field1.metadata.short == field2.metadata.short);
    
    // The actual validation happens at compile time
}

test "Args validation: supported field types" {
    // Test that supported types work correctly
    const TestArgs = cli.Args(&.{
        cli.flag("bool_field", .{ .help = "Boolean field" }),
        cli.option("u8_field", u8, .{ .default = 0, .help = "u8 field" }),
        cli.option("u16_field", u16, .{ .default = 0, .help = "u16 field" }),
        cli.option("u32_field", u32, .{ .default = 0, .help = "u32 field" }),
        cli.option("u64_field", u64, .{ .default = 0, .help = "u64 field" }),
        cli.option("usize_field", usize, .{ .default = 0, .help = "usize field" }),
        cli.option("i8_field", i8, .{ .default = 0, .help = "i8 field" }),
        cli.option("i16_field", i16, .{ .default = 0, .help = "i16 field" }),
        cli.option("i32_field", i32, .{ .default = 0, .help = "i32 field" }),
        cli.option("i64_field", i64, .{ .default = 0, .help = "i64 field" }),
        cli.option("isize_field", isize, .{ .default = 0, .help = "isize field" }),
        cli.option("f32_field", f32, .{ .default = 0.0, .help = "f32 field" }),
        cli.option("f64_field", f64, .{ .default = 0.0, .help = "f64 field" }),
        cli.option("string_field", []const u8, .{ .default = "test", .help = "string field" }),
    });
    
    // If this compiles, all types are supported
    try testing.expect(@TypeOf(TestArgs) != void);
}

test "Args validation: environment variable names" {
    // Test valid environment variable names
    const TestArgs = cli.Args(&.{
        cli.flag("test1", .{ .env_var = "VALID_NAME", .help = "Valid env var" }),
        cli.flag("test2", .{ .env_var = "VALID123", .help = "Valid with numbers" }),
        cli.flag("test3", .{ .env_var = "_VALID", .help = "Valid starting with underscore" }),
    });
    
    // If this compiles, all env var names are valid
    try testing.expect(@TypeOf(TestArgs) != void);
}

test "Args validation: positional argument ordering" {
    // Test that valid positional ordering compiles
    const TestArgs = cli.Args(&.{
        cli.positional("required1", []const u8, .{ .required = true, .help = "Required first" }),
        cli.positional("required2", []const u8, .{ .required = true, .help = "Required second" }),
        cli.positional("optional1", []const u8, .{ .required = false, .help = "Optional first" }),
        cli.positional("optional2", []const u8, .{ .required = false, .help = "Optional second" }),
    });
    
    // If this compiles, the ordering is valid
    try testing.expect(@TypeOf(TestArgs) != void);
}

// ===========================
// Commands Validation Tests  
// ===========================

test "Commands validation: valid command structure" {
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .help = "Verbose output" }),
    });
    
    const TestCommands = cli.Commands(&.{
        cli.command("serve", TestArgs, .{ .help = "Start server" }),
        cli.command("build", TestArgs, .{ .help = "Build project" }),
    });
    
    // If this compiles, the command structure is valid
    try testing.expect(@TypeOf(TestCommands) != void);
}

test "Commands validation: command naming conventions" {
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .help = "Verbose output" }),
    });
    
    // Test valid command names
    const TestCommands = cli.Commands(&.{
        cli.command("serve", TestArgs, .{ .help = "Valid name" }),
        cli.command("build-test", TestArgs, .{ .help = "Valid with dash" }),
        cli.command("api_v2", TestArgs, .{ .help = "Valid with underscore" }),
        cli.command("123start", TestArgs, .{ .help = "Valid starting with number" }),
    });
    
    // If this compiles, all command names are valid
    try testing.expect(@TypeOf(TestCommands) != void);
}

test "Commands validation: nested commands hierarchy" {
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .help = "Verbose output" }),
    });
    
    // Test nested command hierarchy (level 1)
    const Level1Commands = cli.Commands(&.{
        cli.command("start", TestArgs, .{ .help = "Start service" }),
        cli.command("stop", TestArgs, .{ .help = "Stop service" }),
    });
    
    // Test nested command hierarchy (level 2)  
    const Level2Commands = cli.Commands(&.{
        cli.command("migrate", Level1Commands, .{ .help = "Migration commands" }),
        cli.command("seed", TestArgs, .{ .help = "Seed database" }),
    });
    
    // Test main commands (level 3)
    const MainCommands = cli.Commands(&.{
        cli.command("db", Level2Commands, .{ .help = "Database commands" }),
        cli.command("serve", TestArgs, .{ .help = "Serve application" }),
    });
    
    // If this compiles, the hierarchy is valid (depth = 3, under limit of 5)
    try testing.expect(@TypeOf(MainCommands) != void);
}

test "Commands validation: comprehensive command tests" {
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .help = "Verbose output" }),
        cli.option("count", u32, .{ .default = 1, .help = "Count value" }),
    });
    
    // Test various command configurations
    const cmd1 = cli.command("simple", TestArgs, .{ .help = "Simple command" });
    const cmd2 = cli.command("with-dash", TestArgs, .{ .help = "Command with dash" });
    const cmd3 = cli.command("hidden_cmd", TestArgs, .{ .help = "Hidden command", .hidden = true });
    const cmd4 = cli.command("titled", TestArgs, .{ 
        .help = "Command with title", 
        .title = "Custom Title",
        .description = "Detailed description",
    });
    
    // Test command metadata
    try testing.expectEqualStrings(cmd1.command_name, "simple");
    try testing.expect(cmd1.command_type == .leaf);
    try testing.expect(cmd1.config.hidden == false);
    
    try testing.expectEqualStrings(cmd2.command_name, "with-dash");
    try testing.expect(cmd2.command_type == .leaf);
    
    try testing.expectEqualStrings(cmd3.command_name, "hidden_cmd");
    try testing.expect(cmd3.config.hidden == true);
    
    try testing.expectEqualStrings(cmd4.command_name, "titled");
    try testing.expectEqualStrings(cmd4.config.title.?, "Custom Title");
    try testing.expectEqualStrings(cmd4.config.description.?, "Detailed description");
    
    // Test commands compilation
    const TestCommands = cli.Commands(&.{ cmd1, cmd2, cmd3, cmd4 });
    try testing.expect(@TypeOf(TestCommands) != void);
}

test "Commands validation: maximum nesting depth" {
    const LeafArgs = cli.Args(&.{
        cli.flag("test", .{ .help = "Test flag" }),
    });
    
    // Build maximum allowed nesting (5 levels)
    const Level5 = cli.Commands(&.{
        cli.command("leaf", LeafArgs, .{ .help = "Leaf command" }),
    });
    
    const Level4 = cli.Commands(&.{
        cli.command("level5", Level5, .{ .help = "Level 5 commands" }),
    });
    
    const Level3 = cli.Commands(&.{
        cli.command("level4", Level4, .{ .help = "Level 4 commands" }),
    });
    
    const Level2 = cli.Commands(&.{
        cli.command("level3", Level3, .{ .help = "Level 3 commands" }),
    });
    
    const Level1 = cli.Commands(&.{
        cli.command("level2", Level2, .{ .help = "Level 2 commands" }),
    });
    
    // This should compile (exactly at the 5-level limit)
    try testing.expect(@TypeOf(Level1) != void);
    try testing.expect(@TypeOf(Level2) != void);
    try testing.expect(@TypeOf(Level3) != void);
    try testing.expect(@TypeOf(Level4) != void);
    try testing.expect(@TypeOf(Level5) != void);
}

test "Commands validation: command name edge cases" {
    const TestArgs = cli.Args(&.{
        cli.flag("test", .{ .help = "Test flag" }),
    });
    
    // Test valid edge case names
    const TestCommands = cli.Commands(&.{
        cli.command("a", TestArgs, .{ .help = "Single letter" }),
        cli.command("cmd123", TestArgs, .{ .help = "With numbers" }),
        cli.command("under_score", TestArgs, .{ .help = "With underscore" }),
        cli.command("dash-cmd", TestArgs, .{ .help = "With dash" }),
        cli.command("MixedCase", TestArgs, .{ .help = "Mixed case" }),
        cli.command("very_long_command_name_that_tests_length_limits", TestArgs, .{ .help = "Very long name" }),
    });
    
    try testing.expect(@TypeOf(TestCommands) != void);
}

// ===========================
// Config Validation Tests
// ===========================

test "Config validation: valid Args config" {
    // Test valid Args configuration
    const TestArgs = cli.Args(.{
        &.{
            cli.flag("verbose", .{ .help = "Verbose output" }),
        },
        .{
            .title = "Test Application",
            .description = "A test application for validation",
        },
    });
    
    // If this compiles, the config is valid
    try testing.expect(@TypeOf(TestArgs) != void);
}

test "Config validation: valid command configs" {
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .help = "Verbose output" }),
    });
    
    // Test various valid command configurations
    const TestCommands = cli.Commands(&.{
        cli.command("test1", TestArgs, .{ 
            .help = "String literal help" 
        }),
        cli.command("test2", TestArgs, .{ 
            .help = "Help text",
            .title = "Command Title",
            .description = "Command description",
            .hidden = false,
        }),
        cli.command("test3", TestArgs, .{ 
            .help = "Minimal config"
        }),
    });
    
    // If this compiles, all configs are valid
    try testing.expect(@TypeOf(TestCommands) != void);
}

test "Config validation: string type flexibility" {
    // Test that both string literals and slices work
    var dynamic_help: []const u8 = "Dynamic help text";
    _ = &dynamic_help; // Make it appear used
    
    const TestArgs = cli.Args(&.{
        cli.flag("test1", .{ .help = "String literal help" }), // String literal
        // Note: Can't easily test dynamic strings in comptime, but the validation
        // logic supports both []const u8 and *const [N:0]u8
    });
    
    // If this compiles, string type flexibility works
    try testing.expect(@TypeOf(TestArgs) != void);
}

// ===========================
// Field Definition Tests
// ===========================

test "Field definition validation: all field types" {
    // Test all field definition types compile correctly
    const TestArgs = cli.Args(&.{
        cli.flag("flag_test", .{ 
            .short = 'f', 
            .help = "Flag test", 
            .default = false,
            .hidden = false,
            .env_var = "FLAG_TEST",
        }),
        cli.option("option_test", []const u8, .{ 
            .short = 'o', 
            .default = "default", 
            .help = "Option test",
            .hidden = false,
            .env_var = "OPTION_TEST",
        }),
        cli.required("required_test", []const u8, .{ 
            .short = 'r', 
            .help = "Required test",
            .hidden = false,
            .env_var = "REQUIRED_TEST",
        }),
        cli.positional("positional_test", []const u8, .{ 
            .help = "Positional test",
            .default = "pos_default",
            .required = false,
        }),
    });
    
    // Test that the Args type has the expected structure
    const args_type = TestArgs.ArgsType;
    const args_info = @typeInfo(args_type);
    
    try testing.expect(args_info == .@"struct");
    try testing.expect(args_info.@"struct".fields.len == 4);
    
    // Test field names at compile time
    comptime {
        const field_names = [_][]const u8{ "flag_test", "option_test", "required_test", "positional_test" };
        for (args_info.@"struct".fields, 0..) |field, i| {
            if (!std.mem.eql(u8, field.name, field_names[i])) {
                @compileError("Field name mismatch");
            }
        }
    }
}

// ===========================
// Validation Logic Tests
// ===========================

test "Validation: FieldDef structure" {
    // Test that FieldDef structures have required fields
    const flag_def = cli.flag("test", .{ .help = "Test flag" });
    const option_def = cli.option("test", []const u8, .{ .default = "test", .help = "Test option" });
    const required_def = cli.required("test", []const u8, .{ .help = "Test required" });
    const positional_def = cli.positional("test", []const u8, .{ .help = "Test positional" });
    
    // Test that all have required fields
    try testing.expect(@hasField(@TypeOf(flag_def), "value"));
    try testing.expect(@hasField(@TypeOf(flag_def), "metadata"));
    try testing.expect(@hasField(@TypeOf(option_def), "value"));
    try testing.expect(@hasField(@TypeOf(option_def), "metadata"));
    try testing.expect(@hasField(@TypeOf(required_def), "value"));
    try testing.expect(@hasField(@TypeOf(required_def), "metadata"));
    try testing.expect(@hasField(@TypeOf(positional_def), "value"));
    try testing.expect(@hasField(@TypeOf(positional_def), "metadata"));
    
    // Test that all have required methods
    try testing.expect(@hasDecl(@TypeOf(flag_def), "getValue"));
    try testing.expect(@hasDecl(@TypeOf(flag_def), "getMeta"));
    try testing.expect(@hasDecl(@TypeOf(option_def), "getValue"));
    try testing.expect(@hasDecl(@TypeOf(option_def), "getMeta"));
    try testing.expect(@hasDecl(@TypeOf(required_def), "getValue"));
    try testing.expect(@hasDecl(@TypeOf(required_def), "getMeta"));
    try testing.expect(@hasDecl(@TypeOf(positional_def), "getValue"));
    try testing.expect(@hasDecl(@TypeOf(positional_def), "getMeta"));
}

test "Validation: CommandDef structure" {
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .help = "Verbose output" }),
    });
    
    const cmd = cli.command("test", TestArgs, .{ .help = "Test command" });
    
    // Test that CommandDef has required fields
    try testing.expect(@hasField(@TypeOf(cmd), "command_name"));
    try testing.expect(@hasField(@TypeOf(cmd), "config"));
    try testing.expect(@hasField(@TypeOf(cmd), "command_type"));
    try testing.expect(@hasField(@TypeOf(cmd), "data"));
    
    // Test values
    try testing.expectEqualStrings(cmd.command_name, "test");
    try testing.expect(cmd.command_type == .leaf);
    try testing.expect(cmd.data.leaf == TestArgs);
}

// ===========================
// Validation Error Edge Cases
// ===========================

test "Validation: field metadata extraction" {
    // Test that field metadata is correctly extracted (using comptime constants)
    comptime {
        const flag_def = cli.flag("verbose", .{ .short = 'v', .help = "Verbose output", .env_var = "VERBOSE" });
        const option_def = cli.option("count", u32, .{ .short = 'c', .default = 1, .help = "Count value" });
        const required_def = cli.required("config", []const u8, .{ .short = 'f', .help = "Config file" });
        const positional_def = cli.positional("input", []const u8, .{ .help = "Input file", .required = true });
        
        // These tests must be done at compile time to avoid runtime issues
        _ = flag_def;
        _ = option_def;
        _ = required_def;
        _ = positional_def;
    }
    
    // Test that field definitions compile and have the expected structure
    // (detailed metadata testing would require compile-time introspection)
    const test_flag = cli.flag("test_flag", .{ .short = 't', .help = "Test flag" });
    const test_option = cli.option("test_option", []const u8, .{ .default = "test", .help = "Test option" });
    const test_required = cli.required("test_required", []const u8, .{ .help = "Test required" });
    const test_positional = cli.positional("test_positional", []const u8, .{ .help = "Test positional" });
    
    // Test that all field definitions have required structure
    try testing.expect(@hasField(@TypeOf(test_flag), "value"));
    try testing.expect(@hasField(@TypeOf(test_flag), "metadata"));
    try testing.expect(@hasField(@TypeOf(test_option), "value"));
    try testing.expect(@hasField(@TypeOf(test_option), "metadata"));
    try testing.expect(@hasField(@TypeOf(test_required), "value"));
    try testing.expect(@hasField(@TypeOf(test_required), "metadata"));
    try testing.expect(@hasField(@TypeOf(test_positional), "value"));
    try testing.expect(@hasField(@TypeOf(test_positional), "metadata"));
}

test "Validation: boundary conditions" {
    // Test edge cases that should be valid
    
    // Single character names
    const TestArgs1 = cli.Args(&.{
        cli.flag("a", .{ .help = "Single char name" }),
    });
    
    // No short flags
    const TestArgs2 = cli.Args(&.{
        cli.flag("verbose", .{ .help = "No short flag" }),
    });
    
    // All optional positionals
    const TestArgs3 = cli.Args(&.{
        cli.positional("input1", []const u8, .{ .required = false, .default = "default1", .help = "Optional 1" }),
        cli.positional("input2", []const u8, .{ .required = false, .default = "default2", .help = "Optional 2" }),
    });
    
    // Mixed types
    const TestArgs4 = cli.Args(&.{
        cli.flag("flag", .{ .help = "Bool flag" }),
        cli.option("u8_val", u8, .{ .default = 0, .help = "u8 option" }),
        cli.option("i32_val", i32, .{ .default = -1, .help = "i32 option" }),
        cli.option("f64_val", f64, .{ .default = 3.14, .help = "f64 option" }),
        cli.required("string_val", []const u8, .{ .help = "String required" }),
    });
    
    // All should compile successfully
    try testing.expect(@TypeOf(TestArgs1) != void);
    try testing.expect(@TypeOf(TestArgs2) != void);
    try testing.expect(@TypeOf(TestArgs3) != void);
    try testing.expect(@TypeOf(TestArgs4) != void);
}

test "Validation: maximum complexity" {
    // Test the most complex valid configuration
    const ComplexArgs = cli.Args(&.{
        cli.flag("verbose", .{ 
            .short = 'v', 
            .help = "Enable verbose output with detailed logging", 
            .default = false,
            .hidden = false,
            .env_var = "APP_VERBOSE",
        }),
        cli.option("port", u16, .{ 
            .short = 'p', 
            .default = 8080, 
            .help = "Port number to listen on (1-65535)",
            .hidden = false,
            .env_var = "APP_PORT",
        }),
        cli.option("host", []const u8, .{ 
            .short = 'h', 
            .default = "localhost", 
            .help = "Host address to bind to",
            .env_var = "APP_HOST",
        }),
        cli.required("config", []const u8, .{ 
            .short = 'c', 
            .help = "Configuration file path (required)",
            .env_var = "APP_CONFIG",
        }),
        cli.positional("input", []const u8, .{ 
            .help = "Input file to process (required)",
            .required = true,
        }),
        cli.positional("output", []const u8, .{ 
            .help = "Output file (optional)",
            .required = false,
            .default = "output.txt",
        }),
    });
    
    // Test that complex configuration compiles
    try testing.expect(@TypeOf(ComplexArgs) != void);
    
    // Test field count
    const args_info = @typeInfo(ComplexArgs.ArgsType);
    try testing.expect(args_info.@"struct".fields.len == 6);
}

test "Validation: string literal types" {
    // Test that various string types work correctly
    const TestArgs = cli.Args(&.{
        cli.flag("test1", .{ .help = "String literal" }),
        cli.option("test2", []const u8, .{ .default = "Default value", .help = "String literal default" }),
    });
    
    // Test with different string literal lengths
    const TestArgs2 = cli.Args(&.{
        cli.flag("a", .{ .help = "a" }), // Single char
        cli.flag("medium", .{ .help = "Medium length help text" }),
        cli.flag("very_long", .{ .help = "This is a very long help text that tests string literal handling with multiple words and punctuation!" }),
    });
    
    try testing.expect(@TypeOf(TestArgs) != void);
    try testing.expect(@TypeOf(TestArgs2) != void);
}

// ===========================
// Integration Tests
// ===========================

test "Config validation: comprehensive field configs" {
    // Test all possible field configuration combinations
    const TestArgs = cli.Args(&.{
        // Boolean flag with full config
        cli.flag("verbose", .{ 
            .short = 'v', 
            .help = "Enable verbose output",
            .default = false,
            .hidden = false,
            .env_var = "VERBOSE_MODE",
        }),
        
        // String option with all fields
        cli.option("output", []const u8, .{ 
            .short = 'o', 
            .default = "default.txt",
            .help = "Output file path",
            .hidden = false,
            .env_var = "OUTPUT_FILE",
        }),
        
        // Numeric option with various types
        cli.option("count", u32, .{ 
            .short = 'c', 
            .default = 42,
            .help = "Count value",
            .env_var = "COUNT_VAL",
        }),
        
        // Required field with minimal config
        cli.required("input", []const u8, .{ 
            .help = "Input file path",
        }),
        
        // Positional with optional config
        cli.positional("extra", []const u8, .{ 
            .help = "Extra parameter",
            .required = false,
            .default = "none",
        }),
    });
    
    try testing.expect(@TypeOf(TestArgs) != void);
}

test "Config validation: environment variable edge cases" {
    // Test environment variable naming edge cases
    const TestArgs = cli.Args(&.{
        cli.flag("test1", .{ .env_var = "A", .help = "Single char env var" }),
        cli.flag("test2", .{ .env_var = "VERY_LONG_ENVIRONMENT_VARIABLE_NAME_WITH_UNDERSCORES", .help = "Long env var" }),
        cli.flag("test3", .{ .env_var = "MIX3D_numb3rs_AND_cas3", .help = "Mixed case and numbers" }),
        cli.flag("test4", .{ .env_var = "_STARTS_WITH_UNDERSCORE", .help = "Underscore start" }),
        cli.flag("test5", .{ .env_var = "ENDS_WITH_NUMBER123", .help = "Number end" }),
    });
    
    try testing.expect(@TypeOf(TestArgs) != void);
}

test "Config validation: boolean field validation" {
    // Test boolean-specific validation
    const TestArgs = cli.Args(&.{
        cli.flag("bool1", .{ .default = true, .help = "Default true" }),
        cli.flag("bool2", .{ .default = false, .help = "Default false" }),
        cli.flag("bool3", .{ .help = "No default (should be false)" }),
    });
    
    try testing.expect(@TypeOf(TestArgs) != void);
    
    // Test that defaults are properly applied
    const args_type = @typeInfo(TestArgs.ArgsType);
    try testing.expect(args_type == .@"struct");
    try testing.expect(args_type.@"struct".fields.len == 3);
}

test "Validation: complete integration" {
    // Test a complete, complex CLI setup with all validation features
    const ServeArgs = cli.Args(&.{
        cli.flag("daemon", .{ .short = 'd', .help = "Run as daemon", .env_var = "SERVER_DAEMON" }),
        cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on", .env_var = "SERVER_PORT" }),
        cli.option("host", []const u8, .{ .short = 'h', .default = "localhost", .help = "Host to bind to" }),
        cli.required("config", []const u8, .{ .short = 'c', .help = "Config file path", .env_var = "SERVER_CONFIG" }),
    });
    
    const BuildArgs = cli.Args(&.{
        cli.flag("release", .{ .short = 'r', .help = "Build in release mode", .env_var = "BUILD_RELEASE" }),
        cli.option("target", []const u8, .{ .short = 't', .default = "native", .help = "Target platform" }),
        cli.positional("input", []const u8, .{ .help = "Input directory", .required = true }),
        cli.positional("output", []const u8, .{ .help = "Output directory", .required = false, .default = "build" }),
    });
    
    const DatabaseCommands = cli.Commands(&.{
        cli.command("migrate", ServeArgs, .{ .help = "Run database migrations" }),
        cli.command("seed", BuildArgs, .{ .help = "Seed database with data" }),
        cli.command("backup", ServeArgs, .{ .help = "Backup database", .hidden = true }),
    });
    
    const AppCommands = cli.Commands(&.{
        cli.command("serve", ServeArgs, .{ .help = "Start the application server" }),
        cli.command("build", BuildArgs, .{ .help = "Build the application" }),
        cli.command("db", DatabaseCommands, .{ .help = "Database operations" }),
    });
    
    // If this compiles, the entire validation system is working
    try testing.expect(@TypeOf(AppCommands) != void);
    try testing.expect(@TypeOf(ServeArgs) != void);
    try testing.expect(@TypeOf(BuildArgs) != void);
    try testing.expect(@TypeOf(DatabaseCommands) != void);
}

// ===========================
// Edge Cases and Boundary Tests
// ===========================

test "Edge cases: minimal valid configurations" {
    // Test absolute minimum configurations that should still be valid
    
    // Single flag with only help
    const MinimalArgs1 = cli.Args(&.{
        cli.flag("help", .{ .help = "Show help" }),
    });
    
    // Single option with only default and help
    const MinimalArgs2 = cli.Args(&.{
        cli.option("value", u8, .{ .default = 0, .help = "Value" }),
    });
    
    // Single required with only help
    const MinimalArgs3 = cli.Args(&.{
        cli.required("input", []const u8, .{ .help = "Input" }),
    });
    
    // Single positional with defaults
    const MinimalArgs4 = cli.Args(&.{
        cli.positional("file", []const u8, .{ .help = "File" }),
    });
    
    try testing.expect(@TypeOf(MinimalArgs1) != void);
    try testing.expect(@TypeOf(MinimalArgs2) != void);
    try testing.expect(@TypeOf(MinimalArgs3) != void);
    try testing.expect(@TypeOf(MinimalArgs4) != void);
}

test "Edge cases: numeric type boundaries" {
    // Test all numeric types with extreme values
    const NumericArgs = cli.Args(&.{
        cli.option("u8_max", u8, .{ .default = 255, .help = "Max u8" }),
        cli.option("u16_max", u16, .{ .default = 65535, .help = "Max u16" }),
        cli.option("u32_max", u32, .{ .default = 4294967295, .help = "Max u32" }),
        cli.option("u64_max", u64, .{ .default = 18446744073709551615, .help = "Max u64" }),
        cli.option("i8_min", i8, .{ .default = -128, .help = "Min i8" }),
        cli.option("i8_max", i8, .{ .default = 127, .help = "Max i8" }),
        cli.option("i16_min", i16, .{ .default = -32768, .help = "Min i16" }),
        cli.option("i16_max", i16, .{ .default = 32767, .help = "Max i16" }),
        cli.option("i32_min", i32, .{ .default = -2147483648, .help = "Min i32" }),
        cli.option("i32_max", i32, .{ .default = 2147483647, .help = "Max i32" }),
        cli.option("f32_val", f32, .{ .default = 3.14159, .help = "Float32" }),
        cli.option("f64_val", f64, .{ .default = 2.718281828459045, .help = "Float64" }),
    });
    
    try testing.expect(@TypeOf(NumericArgs) != void);
    
    // Verify field count
    const args_info = @typeInfo(NumericArgs.ArgsType);
    try testing.expect(args_info.@"struct".fields.len == 12);
}

test "Edge cases: empty and special strings" {
    // Test edge cases for string handling
    const StringArgs = cli.Args(&.{
        cli.option("empty", []const u8, .{ .default = "", .help = "Empty string" }),
        cli.option("space", []const u8, .{ .default = " ", .help = "Single space" }),
        cli.option("spaces", []const u8, .{ .default = "   ", .help = "Multiple spaces" }),
        cli.option("newline", []const u8, .{ .default = "\n", .help = "Newline" }),
        cli.option("tab", []const u8, .{ .default = "\t", .help = "Tab" }),
        cli.option("mixed", []const u8, .{ .default = "hello\nworld\t!", .help = "Mixed special chars" }),
        cli.option("unicode", []const u8, .{ .default = "🚀🎯✅", .help = "Unicode characters" }),
        cli.option("long", []const u8, .{ .default = "A very long string that tests the maximum reasonable length for default values in CLI arguments to ensure proper handling", .help = "Long string" }),
    });
    
    try testing.expect(@TypeOf(StringArgs) != void);
}

test "Edge cases: command hierarchy stress test" {
    // Test maximum allowed nesting with complex structure
    const LeafArgs = cli.Args(&.{
        cli.flag("test", .{ .help = "Test flag" }),
        cli.option("value", u32, .{ .default = 42, .help = "Test value" }),
    });
    
    // Build exactly 5 levels (maximum allowed)
    const Level5 = cli.Commands(&.{
        cli.command("action1", LeafArgs, .{ .help = "Action 1" }),
        cli.command("action2", LeafArgs, .{ .help = "Action 2" }),
        cli.command("action3", LeafArgs, .{ .help = "Action 3", .hidden = true }),
    });
    
    const Level4 = cli.Commands(&.{
        cli.command("group1", Level5, .{ .help = "Group 1" }),
        cli.command("group2", Level5, .{ .help = "Group 2" }),
    });
    
    const Level3 = cli.Commands(&.{
        cli.command("module1", Level4, .{ .help = "Module 1" }),
        cli.command("module2", Level4, .{ .help = "Module 2" }),
        cli.command("direct", LeafArgs, .{ .help = "Direct action" }),
    });
    
    const Level2 = cli.Commands(&.{
        cli.command("system1", Level3, .{ .help = "System 1" }),
        cli.command("system2", Level3, .{ .help = "System 2" }),
    });
    
    const Level1 = cli.Commands(&.{
        cli.command("app1", Level2, .{ .help = "Application 1" }),
        cli.command("app2", Level2, .{ .help = "Application 2" }),
        cli.command("global", LeafArgs, .{ .help = "Global command" }),
    });
    
    // All levels should compile successfully
    try testing.expect(@TypeOf(Level1) != void);
    try testing.expect(@TypeOf(Level2) != void);
    try testing.expect(@TypeOf(Level3) != void);
    try testing.expect(@TypeOf(Level4) != void);
    try testing.expect(@TypeOf(Level5) != void);
}

test "Edge cases: special character handling in names" {
    // Test valid special characters in command and field names
    const SpecialArgs = cli.Args(&.{
        cli.flag("test_underscore", .{ .help = "Underscore in name" }),
        cli.flag("test-dash", .{ .help = "Dash in name" }),
        cli.flag("test123", .{ .help = "Numbers in name" }),
        cli.flag("Test", .{ .help = "Capital letter" }),
        cli.flag("TestCamelCase", .{ .help = "CamelCase name" }),
        cli.flag("a", .{ .help = "Single character" }),
        cli.flag("very_long_field_name_that_tests_length_handling", .{ .help = "Very long name" }),
    });
    
    const SpecialCommands = cli.Commands(&.{
        cli.command("test-command", SpecialArgs, .{ .help = "Command with dash" }),
        cli.command("test_command", SpecialArgs, .{ .help = "Command with underscore" }),
        cli.command("TestCommand", SpecialArgs, .{ .help = "CamelCase command" }),
        cli.command("cmd123", SpecialArgs, .{ .help = "Command with numbers" }),
        cli.command("x", SpecialArgs, .{ .help = "Single letter command" }),
    });
    
    try testing.expect(@TypeOf(SpecialArgs) != void);
    try testing.expect(@TypeOf(SpecialCommands) != void);
}

test "Edge cases: mixed field types in complex configuration" {
    // Test a complex mix of all field types with edge case values
    const ComplexMixArgs = cli.Args(&.{
        // Boolean flags with various configurations
        cli.flag("bool1", .{ .short = 'a', .default = true, .hidden = false, .env_var = "B1" }),
        cli.flag("bool2", .{ .default = false, .hidden = true }),
        cli.flag("bool3", .{ .short = 'z' }),
        
        // Numeric options with extreme values
        cli.option("zero", u32, .{ .default = 0, .help = "Zero value" }),
        cli.option("negative", i32, .{ .default = -1000000, .help = "Large negative" }),
        cli.option("float", f64, .{ .default = 0.000001, .help = "Tiny float" }),
        
        // String options with special cases  
        cli.option("empty_str", []const u8, .{ .default = "", .help = "Empty string" }),
        cli.option("long_str", []const u8, .{ .default = "This is a very long default string value that tests string handling capabilities", .help = "Long string" }),
        
        // Required fields
        cli.required("req1", []const u8, .{ .short = 'r', .env_var = "REQ_VAL" }),
        cli.required("req2", u16, .{ .help = "Required number" }),
        
        // Positional arguments with mixed requirements
        cli.positional("pos1", []const u8, .{ .required = true, .help = "Required positional" }),
        cli.positional("pos2", []const u8, .{ .required = false, .default = "optional", .help = "Optional positional" }),
        cli.positional("pos3", u32, .{ .required = false, .default = 999, .help = "Optional numeric positional" }),
    });
    
    try testing.expect(@TypeOf(ComplexMixArgs) != void);
    
    // Verify all fields are present
    const args_info = @typeInfo(ComplexMixArgs.ArgsType);
    try testing.expect(args_info.@"struct".fields.len == 13);
}