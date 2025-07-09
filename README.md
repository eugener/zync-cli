# Zync-CLI

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](#testing)
[![Tests](https://img.shields.io/badge/tests-156%2F156%20passing-brightgreen)](#testing)
[![Memory Safe](https://img.shields.io/badge/memory-leak%20free-brightgreen)](#memory-management)
[![Zig Version](https://img.shields.io/badge/zig-0.14.1-orange)](https://ziglang.org/)

A powerful, ergonomic command-line interface library for Zig that leverages compile-time metaprogramming for zero-runtime overhead argument parsing.

## Features

- **Zero Runtime Overhead** - All parsing logic resolved at compile time
- **Type Safe** - Full compile-time type checking and validation
- **Method-Style API** - Ergonomic `Args.parse()` interface with zero-duplication metadata extraction
- **Environment Variable Support** - Seamless integration with standard priority chain
- **Memory Safe** - Automatic memory management with zero leaks
- **Rich Diagnostics** - Helpful error messages with suggestions
- **Battle Tested** - 156 comprehensive tests covering all functionality
- **Automatic Help** - Built-in help generation with dynamic program name detection and zero boilerplate
- **Colorized Output** - Beautiful terminal colors with smart detection and fallback

## Quick Start

### Installation

Add to your `build.zig`:

```zig
const zync_cli = b.dependency("zync-cli", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("zync-cli", zync_cli.module("zync-cli"));
```

### Basic Usage

```zig
const std = @import("std");
const cli = @import("zync-cli");

const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output", .env_var = "APP_VERBOSE" }),
    cli.option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet", .env_var = "APP_NAME" }),
    cli.option("count", u32, .{ .short = 'c', .default = 1, .help = "Number of times to greet", .env_var = "APP_COUNT" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // Clean and simple - no boilerplate needed!
    const args = try Args.parse(arena.allocator());
    
    if (args.verbose) {
        std.debug.print("Verbose mode enabled!\n", .{});
    }
    
    var i: u32 = 0;
    while (i < args.count) : (i += 1) {
        std.debug.print("Hello, {s}!\n", .{args.name});
    }
}
```


**Running the example:**
```bash
# Using CLI arguments
$ ./myapp --verbose --name Alice --count 3
Verbose mode enabled!
Hello, Alice!
Hello, Alice!
Hello, Alice!

# Using environment variables
$ APP_VERBOSE=true APP_NAME=Bob APP_COUNT=2 ./myapp
Verbose mode enabled!
Hello, Bob!
Hello, Bob!

# CLI arguments override environment variables
$ APP_NAME=Bob ./myapp --name Alice
Hello, Alice!

$ ./myapp --help
myapp - TODO: Add custom title using .title in Args config
TODO: Add description using .description in Args config

Usage: myapp [OPTIONS]

Options:
  -v, --verbose           Enable verbose output [env: APP_VERBOSE]
  -n, --name [value]      Name to greet [env: APP_NAME] (default: World)
  -c, --count [value]     Number of times to greet [env: APP_COUNT] (default: 1)
  -h, --help              Show this help message
```

## Environment Variable Support

Zync-CLI provides first-class environment variable support with a standard priority chain:

### Priority Chain

**CLI arguments → Environment variables → Default values**

```zig
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output", .env_var = "APP_VERBOSE" }),
    cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on", .env_var = "APP_PORT" }),
    cli.required("config", []const u8, .{ .short = 'c', .help = "Config file path", .env_var = "APP_CONFIG" }),
});
```

### Usage Examples

```bash
# Environment variables can satisfy required fields
$ APP_CONFIG=config.toml ./myapp
# Uses APP_CONFIG for config, default 8080 for port

# CLI args override environment variables
$ APP_PORT=3000 ./myapp --port 9000
# Uses 9000 (CLI) for port, not 3000 (env var)

# Mix and match
$ APP_VERBOSE=true APP_CONFIG=config.toml ./myapp --port 3000
# Uses env var for verbose and config, CLI arg for port
```

### Supported Types

Environment variables work with all supported types and are automatically converted:

- **Boolean flags**: `"true"`, `"1"` → `true`; `"false"`, `"0"` → `false`
- **Integers**: `"42"` → `42`
- **Floats**: `"3.14"` → `3.14`
- **Strings**: Used directly
- **Required fields**: Environment variables satisfy required field validation

### Automatic Help Documentation

Environment variables are automatically documented in help text:

```bash
$ ./myapp --help
Options:
  -v, --verbose           Enable verbose output [env: APP_VERBOSE]
  -p, --port [value]      Port to listen on [env: APP_PORT] (default: 8080)
  -c, --config <value>    Config file path [env: APP_CONFIG] (required)
```

The `[env: VAR_NAME]` indicator shows users which environment variables are available for each option.

### Environment Variable Naming

Choose descriptive, consistent names for your environment variables:

```zig
const Args = cli.Args(&.{
    cli.flag("debug", .{ .env_var = "MYAPP_DEBUG" }),
    cli.option("host", []const u8, .{ .env_var = "MYAPP_HOST" }),
    cli.option("timeout", u32, .{ .env_var = "MYAPP_TIMEOUT" }),
    cli.required("api_key", []const u8, .{ .env_var = "MYAPP_API_KEY" }),
});
```

## Colorized Output

Zync-CLI automatically provides beautiful, colorized terminal output that enhances readability and user experience:

### Smart Color Detection

- **Automatic Detection** - Colors are enabled when supported by the terminal
- **Environment Aware** - Respects `NO_COLOR` and `FORCE_COLOR` environment variables
- **Graceful Fallback** - Falls back to plain text when colors aren't supported
- **Cross-Platform** - Works consistently across different operating systems

### Colorized Help

- **Titles** appear in bright cyan for clear visual hierarchy
- **Flags** are highlighted in green (`-v, --verbose`)
- **Required arguments** are shown in red (`<value>`)
- **Optional arguments** appear dimmed (`[value]`)
- **Default values** are highlighted in magenta
- **Examples** are shown in cyan for easy identification

### Colorized Errors

```bash
$ ./myapp --invalid-flag
Error: Unknown flag ('invalid-flag')

Suggestion: Use --help to see available options

$ ./myapp --count abc
Error: Invalid value for flag ('count')

Suggestion: Expected integer value for flag
```

**Error colors:**
- **Error messages** appear in red for immediate attention
- **Context** (problematic values) shown in bright red
- **Suggestions** highlighted in yellow for actionable guidance

### Color Configuration

```bash
# Disable colors entirely
NO_COLOR=1 ./myapp --help

# Force colors even when not detected
FORCE_COLOR=1 ./myapp --help

# Colors work automatically in supported terminals
./myapp --help
```

## Function-based DSL

Zync-CLI uses a function-based DSL for defining CLI arguments:

Clean, IDE-friendly syntax with explicit configuration and environment variable support:

```zig
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output", .env_var = "APP_VERBOSE" }),
    cli.option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet", .env_var = "APP_NAME" }),
    cli.option("count", u32, .{ .short = 'c', .default = 1, .help = "Number of times to greet", .env_var = "APP_COUNT" }),
    cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port number to listen on", .env_var = "APP_PORT" }),
    cli.required("config", []const u8, .{ .short = 'f', .help = "Configuration file path", .env_var = "APP_CONFIG" }),
    cli.positional("input", []const u8, .{ .help = "Input file to process" }),
});
```

**Benefits:**
- Clean, readable field names (`args.verbose` vs `args.@"verbose|v"`)
- IDE auto-completion and syntax highlighting
- Rich help text and descriptions
- Environment variable integration with priority chain
- Type-safe configuration structs
- Future-proof for advanced features

### Enhanced Features

The function-based DSL includes powerful features that eliminate duplication and ensure type safety:

```zig
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output", .env_var = "APP_VERBOSE" }),
    cli.flag("debug", .{ .short = 'd', .help = "Debug mode", .hidden = true, .env_var = "APP_DEBUG" }),
    cli.option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet", .env_var = "APP_NAME" }),
    cli.option("count", u32, .{ .short = 'c', .default = 5, .help = "Number of iterations", .env_var = "APP_COUNT" }),
    cli.required("config", []const u8, .{ .short = 'f', .help = "Configuration file path", .env_var = "APP_CONFIG" }),
    cli.positional("input", []const u8, .{ .help = "Input file to process" }),
});
```

**Key Benefits:**
- **Zero duplication** - Single function call defines everything
- **Type safety** - Compile-time validation of all configurations
- **Environment integration** - Native support for environment variables
- **Hidden flags** - Support for flags that work but don't appear in help text
- **Automatic metadata** - Help text and parsing automatically generated
- **Clean syntax** - Minimal, readable DSL with full IDE support

## Custom Title and Description

Zync-CLI encourages customization by showing helpful TODO reminders when default title/description are used:

### Default Behavior (Encourages Customization)

Without custom configuration:
```zig
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
    cli.option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
});
```

```bash
$ ./myapp --help
myapp - TODO: Add custom title using .title in Args config
TODO: Add description using .description in Args config

Usage: myapp [OPTIONS]
...
```

### Custom Configuration

Add custom title and description to your Args configuration:

```zig
const Args = cli.Args(.{
    &.{
        cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        cli.option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
    },
    .{
        .title = "MyApp - A powerful CLI tool",
        .description = "Process files with advanced options and environment variable support.",
    },
});
```

```bash
$ ./myapp --help
MyApp - A powerful CLI tool
Process files with advanced options and environment variable support.

Usage: myapp [OPTIONS]
...
```

### Features

- **Encourages Customization** - TODO messages guide users to add custom titles and descriptions
- **Professional Output** - Custom titles and descriptions create polished help text
- **Banner Support** - Supports ASCII art banners and multi-line titles
- **Consistent Styling** - Maintains colorized output with custom content
- **Zero Boilerplate** - Simple configuration structure with sensible defaults



## Supported Types

Zync-CLI supports a wide range of Zig types with automatic conversion:

### Primitive Types
- **Boolean**: `bool` - Automatic flag detection
- **Integers**: `u8`, `u16`, `u32`, `u64`, `i8`, `i16`, `i32`, `i64`
- **Floats**: `f16`, `f32`, `f64`
- **Strings**: `[]const u8` - Safe memory management

### Optional Types
- **Optional primitives**: `?u32`, `?[]const u8`, etc.
- **Nullable with defaults**: Automatic handling

### Advanced Types (Planned)
- **Arrays**: `[N]T` for fixed-size collections
- **Slices**: `[]T` for dynamic arrays
- **Enums**: Automatic string-to-enum conversion
- **Tagged Unions**: For subcommand systems

## API Reference

### Method-Style API (Recommended)

The modern method-style API provides the most ergonomic way to use Zync-CLI:

#### `Args.parse(allocator)`
Parse command-line arguments from process argv. Help is handled automatically.

```zig
// Clean and simple - no boilerplate!
const args = try Args.parse(arena.allocator());
```

#### `Args.parseFrom(allocator, args)`
Parse from custom argument array. Help is handled automatically.

```zig
const test_args = &.{"--verbose", "--name", "Alice"};
const args = try Args.parseFrom(arena.allocator(), test_args);
```

#### `Args.parseFromRaw(allocator, args)`
Parse from custom argument array with manual help handling. Use this only when you need full control over help behavior.

```zig
const args = Args.parseFromRaw(arena.allocator(), test_args) catch |err| switch (err) {
    error.HelpRequested => {
        // Handle help manually
        return;
    },
    else => return err,
};
```

#### `Args.help(allocator)`
Generate help text for this argument structure.

```zig
const help_text = try Args.help(arena.allocator());
std.debug.print("{s}\n", .{help_text});
```

#### `Args.validate()`
Compile-time validation of argument structure.

```zig
comptime Args.validate(); // Validates at compile time
```

### DSL Functions

#### `Args(definitions)`
Create argument struct from DSL definitions.

```zig
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output", .env_var = "APP_VERBOSE" }),
    cli.option("name", []const u8, .{ .default = "World", .help = "Name to greet", .env_var = "APP_NAME" }),
    cli.required("config", []const u8, .{ .short = 'c', .help = "Configuration file path", .env_var = "APP_CONFIG" }),
    cli.positional("input", []const u8, .{ .help = "Input file path" }),
});
```

#### `flag(name, config)`
Define a boolean flag with optional environment variable support.

```zig
cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output", .env_var = "APP_VERBOSE" })
```

#### `option(name, type, config)`
Define an optional value with default and optional environment variable support.

```zig
cli.option("count", u32, .{ .short = 'c', .default = 1, .help = "Number of iterations", .env_var = "APP_COUNT" })
```

#### `required(name, type, config)`
Define a required value with optional environment variable support.

```zig
cli.required("config", []const u8, .{ .short = 'f', .help = "Configuration file path", .env_var = "APP_CONFIG" })
```

#### `positional(name, type, config)`
Define a positional argument (environment variables not supported for positional args).

```zig
cli.positional("input", []const u8, .{ .help = "Input file path" })
```

### Simple Return Values

Parsing functions now return the parsed arguments directly:

```zig
// Simple and clean - no boilerplate needed!
const args = try Args.parse(arena.allocator());
// No manual cleanup needed - arena handles memory
```

### Error Handling & Automatic Help

Zync-CLI automatically handles help flags and displays help text before any validation occurs:

```zig
// Help is handled automatically - no boilerplate needed!
const args = try Args.parse(arena.allocator());
```

For advanced use cases where you need control over help handling, use `parseFromRaw`:

```zig
const args = Args.parseFromRaw(arena.allocator(), custom_args) catch |err| switch (err) {
    error.HelpRequested => {
        // Handle help manually if needed
        return;
    },
    else => return err,
};
```

**Key Features:**
- **Automatic help processing** - Help flags are processed automatically
- **Pre-validation help** - Help works even when required fields are missing
- **Standard conventions** - Supports both `--help` and `-h` flags
- **Environment variable support** - Integrates seamlessly with standard priority chain
- **Automatic error handling** - Errors are displayed automatically with suggestions

## Testing

Zync-CLI includes comprehensive testing utilities and maintains 100% test coverage:

### Running Tests

```bash
# Run all tests
zig build test

# Run specific module tests  
zig build test-parser     # Parser functionality
zig build test-types      # Type definitions
zig build test-meta       # Metadata extraction

# Detailed test output
zig build test --summary all
```

### Test Utilities

```zig
const cli = @import("zync-cli");

test "my CLI parsing" {
    const Args = cli.Args(&.{
        cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output", .env_var = "TEST_VERBOSE" }),
        cli.option("name", []const u8, .{ .short = 'n', .default = "test", .help = "Name to use", .env_var = "TEST_NAME" }),
    });
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    // Test successful parsing with method-style API
    const result = try Args.parseFrom(arena.allocator(), &.{"--verbose", "--name", "Alice"});
    try std.testing.expect(result.verbose == true);
    try std.testing.expectEqualStrings(result.name, "Alice");
    
    // Test error conditions
    try std.testing.expectError(error.UnknownFlag, 
        Args.parseFrom(arena.allocator(), &.{"--invalid"}));
}
```

### Current Test Coverage

- **156 total tests** across all modules
- **Method-style API** - Ergonomic `Args.parse()` and `Args.parseFrom()` methods
- **Function-based DSL** - Zero-duplication metadata extraction
- **Argument parsing** for all supported types
- **Environment variable support** - Priority chain and type conversion
- **Required field validation** with `required()` function
- **Default value handling** with `option()` function
- **Positional arguments** with `positional()` function
- **Automatic help handling** with `--help` and `-h` flags
- **Error handling** for all error conditions
- **Memory management** with arena allocation
- **Help generation** and formatting
- **Colorized output** with smart terminal detection
- **Cross-platform color support** with environment variable controls
- **Integration testing** with real CLI scenarios

## Memory Management

Zync-CLI provides automatic, leak-free memory management:

### Arena-Based Memory Management

```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit(); // Automatically frees all allocated memory

const args = try Args.parse(arena.allocator());
// No manual string cleanup required!
```

### Memory Safety Features

- **Zero Leaks**: Arena-based allocation ensures no memory leaks
- **Safe Defaults**: No dangling pointers or invalid memory access
- **Allocator Flexibility**: Works with any Zig allocator
- **Simple Cleanup**: Single `arena.deinit()` call cleans everything
- **Testing Integration**: Memory leak detection in test suite

### Performance Characteristics

- **Compile-Time Parsing**: Zero runtime overhead for argument definitions
- **Minimal Allocations**: Only allocates memory for string arguments and diagnostics
- **Automatic Cleanup**: O(1) cleanup cost regardless of argument count
- **Cache Friendly**: Contiguous memory layout for parsed arguments

## Project Structure

```
zync-cli/
├── src/
│   ├── root.zig        # Main library API (simplified, idiomatic)
│   ├── types.zig       # Core type definitions
│   ├── parser.zig      # Argument parsing engine with detailed errors
│   ├── meta.zig        # Compile-time metadata extraction
│   ├── dsl.zig         # Function-based DSL implementation
│   ├── help.zig        # Help text generation
│   ├── colors.zig      # Advanced color API with format support and writer interface
│   ├── testing.zig     # Testing utilities
│   └── main.zig        # Demo application
├── build.zig           # Build configuration
├── README.md           # This file
├── CLAUDE.md           # Project documentation
└── spec.md             # Library specification
```

## Development

### Building

```bash
# Build library and demo
zig build

# Run demo application
zig build run -- --verbose --name Developer --count 2

# Install library
zig build install
```

### Contributing

1. **Follow Zig conventions** - Use existing code patterns
2. **Write tests first** - All new features require tests
3. **Maintain memory safety** - No leaks allowed
4. **Update documentation** - Keep README and examples current

### Development Workflow

```bash
# Development cycle
zig build test && zig build run -- --help

# Memory leak checking
zig build test 2>&1 | grep -i leak # Should be empty

# Performance testing
zig build -Drelease-fast && time ./zig-out/bin/zync_cli --help
```

## Roadmap

### Completed (v0.1.0)
- [x] Core argument parsing engine
- [x] Function-based DSL
- [x] Memory-safe string handling
- [x] Comprehensive test suite
- [x] Help text generation
- [x] Error handling with diagnostics

### Completed (v0.2.0)
- [x] Required field validation
- [x] Default value handling
- [x] Positional argument support
- [x] Idiomatic Zig architecture with arena allocation
- [x] Comprehensive error handling
- [x] Dynamic help generation from field metadata
- [x] Automatic help flag processing

### Completed (v0.3.0)
- [x] **Function-based DSL** - Zero-duplication metadata extraction
- [x] **Enhanced color system** - Format support and writer interface
- [x] **Improved error handling** - Clean messages without stacktraces
- [x] **Function optimization** - Removed redundant functions, improved naming
- [x] **Stdlib integration** - Uses `std.io.tty` for color detection
- [x] **103 comprehensive tests** - Full coverage of current functionality

### Completed (v0.4.0)
- [x] **Environment variable support** - Complete integration with priority chain
- [x] **CLI args → env vars → defaults** - Standard priority implementation
- [x] **Type-safe environment variables** - Works with all supported types
- [x] **Required field satisfaction** - Environment variables satisfy validation
- [x] **Comprehensive testing** - Full test coverage for environment variables

### Planned (v0.5.0)
- [ ] Configuration file parsing
- [ ] Subcommand system with tagged unions

### Future (v1.0.0)
- [ ] Plugin system for custom types
- [ ] Shell completion generation
- [ ] Documentation generation
- [ ] Performance optimizations

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests for any improvements.

---

**Built with Zig** | **Zero Runtime Overhead** | **Memory Safe** | **Type Safe**