# Zync-CLI: Modern CLI Library Specification

## 1. Core Design Philosophy

### 1.1 Zig-First Design
- **Compile-time everything**: All parsing logic resolved at compile time
- **Zero runtime overhead**: Generated code as efficient as hand-written parsing
- **Type-safe by design**: Impossible to access non-existent arguments
- **Memory conscious**: Arena-based allocation for automatic cleanup
- **Leverage Zig's unique features**: Comptime, reflection, automatic metadata generation

### 1.2 Modern Function-Based DSL
Zync-CLI uses a modern function-based DSL that provides clean, IDE-friendly syntax:

```zig
const cli = @import("zync-cli");

const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
    cli.option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
    cli.required("config", []const u8, .{ .short = 'c', .help = "Configuration file path" }),
    cli.positional("input", []const u8, .{ .help = "Input file path" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    const args = Args.parse(arena.allocator()) catch |err| switch (err) {
        error.HelpRequested => return,
        else => return err,
    };
    
    if (args.verbose) {
        std.debug.print("Verbose mode enabled!\n", .{});
    }
    
    std.debug.print("Hello, {s}!\n", .{args.name});
}
```

## 2. Function-Based DSL API

### 2.1 Core Functions

#### `flag(name, config)`
Creates a boolean flag argument.

```zig
cli.flag("verbose", .{ 
    .short = 'v', 
    .help = "Enable verbose output",
    .env_var = "VERBOSE"  // Optional environment variable
})
```

#### `option(name, Type, config)`
Creates an optional argument with a default value.

```zig
cli.option("port", u16, .{ 
    .short = 'p', 
    .default = 8080,
    .help = "Server port",
    .env_var = "PORT"
})
```

#### `required(name, Type, config)`
Creates a required argument that must be provided.

```zig
cli.required("config", []const u8, .{ 
    .short = 'c', 
    .help = "Configuration file path",
    .env_var = "CONFIG_FILE"
})
```

#### `positional(name, Type, config)`
Creates a positional argument.

```zig
cli.positional("input", []const u8, .{ 
    .help = "Input file path",
    .required = true
})
```

### 2.2 Configuration Types

#### `FlagConfig`
Configuration for boolean flags.

```zig
pub const FlagConfig = struct {
    short: ?u8 = null,              // Short flag character (-v)
    help: ?[]const u8 = null,       // Help text
    default: bool = false,          // Default value
    hidden: bool = false,           // Hide from help output
    env_var: ?[]const u8 = null,    // Environment variable name
};
```

#### `OptionConfig(T)`
Configuration for optional arguments.

```zig
pub fn OptionConfig(comptime T: type) type {
    return struct {
        short: ?u8 = null,              // Short flag character
        help: ?[]const u8 = null,       // Help text
        default: T,                     // Default value (required)
        hidden: bool = false,           // Hide from help output
        env_var: ?[]const u8 = null,    // Environment variable name
    };
}
```

#### `RequiredConfig(T)`
Configuration for required arguments.

```zig
pub fn RequiredConfig(comptime T: type) type {
    return struct {
        short: ?u8 = null,              // Short flag character
        help: ?[]const u8 = null,       // Help text
        hidden: bool = false,           // Hide from help output
        env_var: ?[]const u8 = null,    // Environment variable name
    };
}
```

#### `PositionalConfig(T)`
Configuration for positional arguments.

```zig
pub fn PositionalConfig(comptime T: type) type {
    return struct {
        help: ?[]const u8 = null,       // Help text
        required: bool = false,         // Whether positional is required
        default: ?T = null,             // Default value if not required
    };
}
```

## 3. Argument Parsing

### 3.1 Parsing Priority Chain

Arguments are resolved in the following priority order:

1. **CLI arguments** (highest priority)
2. **Environment variables** (if CLI argument not provided)
3. **Default values** (if neither CLI nor environment variable provided)
4. **Required validation** (error if required field has no value)

### 3.2 Supported Flag Formats

#### Long Flags
```bash
--verbose                    # Boolean flag
--name=Alice                # Embedded value
--name Alice                # Separate value
```

#### Short Flags
```bash
-v                          # Boolean flag
-n Alice                    # Separate value
-nAlice                     # Embedded value
```

#### Combined Short Flags
```bash
-vn Alice                   # Multiple flags: -v -n Alice
```

### 3.3 Supported Types

- **Boolean**: `bool`
- **Integers**: `u8`, `u16`, `u32`, `u64`, `i8`, `i16`, `i32`, `i64`
- **Floats**: `f32`, `f64`
- **Strings**: `[]const u8`
- **Optional types**: `?T` for any supported type T
- **Enums**: Basic enum support with string conversion

### 3.4 Environment Variable Support

All argument types support environment variables:

```zig
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .env_var = "VERBOSE" }),
    cli.option("port", u16, .{ .default = 8080, .env_var = "PORT" }),
    cli.required("config", []const u8, .{ .env_var = "CONFIG_FILE" }),
});
```

```bash
# Environment variables can satisfy required fields
CONFIG_FILE=config.toml ./myapp

# CLI arguments override environment variables
PORT=3000 ./myapp --port 9000  # Uses 9000, not 3000
```

## 4. Memory Management

### 4.1 Arena-Based Allocation

Zync-CLI uses arena-based allocation for automatic, leak-free memory management:

```zig
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();  // Automatically frees all allocated memory
    
    const args = Args.parse(arena.allocator()) catch |err| switch (err) {
        error.HelpRequested => return,
        else => return err,
    };
    // No manual cleanup required!
}
```

### 4.2 Memory Safety Features

- **Zero leaks**: All string allocations tied to arena lifetime
- **Automatic cleanup**: Single `defer arena.deinit()` call
- **No manual management**: No individual string cleanup required
- **Testing verified**: All tests pass with leak detection enabled

## 5. Help System

### 5.1 Automatic Help Generation

The library automatically generates help text from argument definitions:

```zig
// Automatically handles --help and -h flags
const args = Args.parse(arena.allocator()) catch |err| switch (err) {
        error.HelpRequested => return,
        else => return err,
    };
```

### 5.2 Help Features

- **Automatic help flags**: Handles `--help` and `-h` before validation
- **Colorized output**: Uses terminal colors for better readability
- **Smart formatting**: Automatically calculates column alignment
- **Environment indicators**: Shows `[env: VAR_NAME]` for environment variables
- **Default values**: Displays `(default: value)` for optional arguments
- **Required highlighting**: Shows `(required)` for required arguments

### 5.3 Help Output Example

```
Usage: myapp [OPTIONS] <INPUT>

Options:
  -v, --verbose     Enable verbose output [env: VERBOSE]
  -n, --name        Name to greet (default: World) [env: NAME]
  -c, --config      Configuration file path (required) [env: CONFIG_FILE]
  -h, --help        Show this help message

Arguments:
  <INPUT>          Input file path
```

## 6. Error Handling

### 6.1 Error Types

```zig
pub const ParseError = error{
    UnknownFlag,           // Unknown flag provided
    MissingValue,          // Flag requires value but none provided
    InvalidValue,          // Value cannot be converted to target type
    MissingRequired,       // Required argument not provided
    TooManyPositional,     // More positional args than expected
    HelpRequested,         // Help flag was provided
};
```

### 6.2 Detailed Error Information

```zig
pub const DetailedParseError = struct {
    err: ParseError,
    flag: ?[]const u8 = null,
    value: ?[]const u8 = null,
    suggestion: ?[]const u8 = null,
    context: ?[]const u8 = null,
};
```

### 6.3 Error Handling Example

```zig
const args = Args.parse(arena.allocator()) catch |err| switch (err) {
    error.HelpRequested => return,  // Help was shown, exit normally
    error.UnknownFlag => {
        std.debug.print("Unknown flag. Use --help for usage.\n", .{});
        return;
    },
    error.MissingRequired => {
        std.debug.print("Missing required argument. Use --help for usage.\n", .{});
        return;
    },
    else => return err,
};
```

## 7. Testing

### 7.1 Test Coverage

The library includes comprehensive testing:

- **107 total tests** across all modules
- **Parser tests**: Argument parsing, type conversion, error handling
- **Help tests**: Help generation, formatting, color output
- **Environment tests**: Environment variable integration
- **Memory tests**: Leak detection and arena allocation
- **Integration tests**: End-to-end functionality

### 7.2 Running Tests

```bash
# Run all tests
zig build test

# Run specific module tests
zig build test-parser
zig build test-help
zig build test-types

# Run with detailed output
zig build test --summary all
```

### 7.3 Testing Utilities

The library provides testing utilities for users:

```zig
const testing = @import("zync-cli/testing.zig");

test "my CLI parsing" {
    const TestArgs = cli.Args(&.{
        cli.flag("verbose", .{ .short = 'v' }),
        cli.option("name", []const u8, .{ .short = 'n', .default = "Test" }),
    });
    
    const allocator = std.testing.allocator;
    const args = &.{"test", "-v", "--name", "Alice"};
    
    const result = try testing.parseArgs(TestArgs, allocator, args);
    defer testing.cleanup(result);
    
    try std.testing.expect(result.verbose == true);
    try std.testing.expectEqualStrings(result.name, "Alice");
}
```

## 8. API Reference

### 8.1 Core Functions

#### `parse(Args, allocator, argv)`
Parse command-line arguments into the specified Args type.

```zig
const args = Args.parse(arena.allocator()) catch |err| switch (err) {
        error.HelpRequested => return,
        else => return err,
    };
```

#### `Args(definitions)`
Create an Args type from DSL definitions.

```zig
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v' }),
    cli.option("name", []const u8, .{ .default = "World" }),
});
```

### 8.2 DSL Functions

All DSL functions are available through the `cli` namespace:

- `cli.flag(name, config)` - Boolean flags
- `cli.option(name, Type, config)` - Optional arguments
- `cli.required(name, Type, config)` - Required arguments
- `cli.positional(name, Type, config)` - Positional arguments

### 8.3 Generated Struct

The `Args()` function generates a struct with:

- **Typed fields** for each argument
- **Default values** from DSL definitions
- **Automatic metadata** for help generation
- **Environment variable support**

## 9. Advanced Features

### 9.1 Program Name Detection

The library automatically detects the program name from `argv[0]`:

```zig
// Automatically uses actual program name in help
Usage: myapp [OPTIONS] <INPUT>
```

### 9.2 Colorized Output

Terminal colors are automatically detected and used for:

- **Help output**: Colorized flags, options, and descriptions
- **Error messages**: Red errors with context highlighting
- **Environment support**: Respects `NO_COLOR` and `FORCE_COLOR`

### 9.3 Edit Distance Suggestions

Unknown flags trigger smart suggestions:

```bash
$ myapp --verbos
Error: Unknown flag '--verbos'. Did you mean '--verbose'?
```

## 10. Current Limitations

### 10.1 Not Yet Implemented

- **Multiple values**: No support for array arguments
- **Subcommands**: No tagged union support for subcommands
- **Configuration files**: No TOML/JSON configuration support
- **Custom validators**: No validation beyond type conversion
- **Shell completion**: No completion script generation

### 10.2 Future Roadmap

1. **v0.3.0**: Multiple value support and counting flags
2. **v0.4.0**: Subcommand system with tagged unions
3. **v0.5.0**: Configuration file integration
4. **v1.0.0**: Stable API with full feature set

## 11. Migration Guide

### 11.1 From Previous Versions

If upgrading from versions that used field encoding DSL (`@"verbose|v"`), migrate to the function-based DSL:

```zig
// Old (not implemented)
const Args = struct {
    @"verbose|v": bool = false,
    @"name|n=World": []const u8,
};

// New (current implementation)
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v' }),
    cli.option("name", []const u8, .{ .short = 'n', .default = "World" }),
});
```

### 11.2 Benefits of Function-Based DSL

- **IDE support**: Auto-completion and error checking
- **Type safety**: Compile-time type validation
- **Extensibility**: Easy to add new configuration options
- **Readability**: Clear, explicit argument definitions
- **Maintainability**: Easier to modify and extend

This specification reflects the actual implementation of Zync-CLI as of the current version, focusing on the modern function-based DSL approach with comprehensive environment variable support and arena-based memory management.