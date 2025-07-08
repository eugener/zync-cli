# Zync-CLI

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](#testing)
[![Tests](https://img.shields.io/badge/tests-156%2F156%20passing-brightgreen)](#testing)
[![Memory Safe](https://img.shields.io/badge/memory-leak%20free-brightgreen)](#memory-management)
[![Zig Version](https://img.shields.io/badge/zig-0.14.1-orange)](https://ziglang.org/)

A powerful, ergonomic command-line interface library for Zig that leverages compile-time metaprogramming for zero-runtime overhead argument parsing.

## Features

- **Zero Runtime Overhead** - All parsing logic resolved at compile time
- **Type Safe** - Full compile-time type checking and validation
- **Dual DSL Support** - Both modern function-based and legacy field encoding syntax
- **Memory Safe** - Automatic memory management with zero leaks
- **Rich Diagnostics** - Helpful error messages with suggestions
- **Battle Tested** - 156 comprehensive tests covering all functionality
- **Self-Documenting** - Automatic help generation from field definitions
- **Automatic Help** - Built-in help flag processing with no user code required
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

### Basic Usage (Function-Based DSL)

```zig
const std = @import("std");
const zync_cli = @import("zync-cli");

const Args = struct {
    verbose: bool = zync_cli.flag(.{ .short = 'v', .help = "Enable verbose output" }),
    name: []const u8 = zync_cli.option(zync_cli.OptionConfig([]const u8){ 
        .short = 'n', 
        .default = "World", 
        .help = "Name to greet" 
    }),
    count: u32 = zync_cli.option(zync_cli.Option(u32){ 
        .short = 'c', 
        .default = 1, 
        .help = "Number of times to greet" 
    }),
    
    // Enhanced metadata using helper functions (eliminates duplication!)
    pub const dsl_metadata = &[_]zync_cli.FieldMetadata{
        zync_cli.flagMeta("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        zync_cli.optionMeta([]const u8, "name", .{ .short = 'n', .default = "World", .help = "Name to greet" }),
        zync_cli.optionMeta(u32, "count", .{ .short = 'c', .default = 1, .help = "Number of times to greet" }),
    };
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    const args = zync_cli.parseProcess(Args, arena.allocator()) catch |err| switch (err) {
        error.HelpRequested => {
            // Help was automatically displayed by the parser
            return;
        },
        else => return err,
    };
    
    if (args.verbose) {
        std.debug.print("Verbose mode enabled!\n", .{});
    }
    
    var i: u32 = 0;
    while (i < args.count) : (i += 1) {
        std.debug.print("Hello, {s}!\n", .{args.name});
    }
}
```

### Legacy Field Encoding DSL (Still Supported)

```zig
const Args = struct {
    @"verbose|v": bool = false,
    @"name|n=World": []const u8 = "",
    @"count|c=1": u32 = 0,
};

// Usage: args.@"verbose|v", args.@"name|n=World", etc.
```

**Running the example:**
```bash
$ ./myapp --verbose --name Alice --count 3
Verbose mode enabled!
Hello, Alice!
Hello, Alice!
Hello, Alice!

$ ./myapp --help
zync-cli-demo

A demonstration of the Zync-CLI library

Usage: zync-cli-demo [OPTIONS]

Options:
  -v, --verbose         Enable verbose output
  -n, --name [value]    Set name value (default: World)
  -c, --count [value]   Set count value (default: 1)
  -p, --port [value]    Set port value (default: 8080)
  -h, --help            Show this help message
  -f, --config <value>  Set config value (required)

Examples:
  zync-cli-demo --name Alice --config app.conf
  zync-cli-demo -v --count 3 --config /etc/myapp.conf
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

## Dual DSL Support

Zync-CLI supports two approaches for defining CLI arguments:

### 1. Modern Function-Based DSL (Recommended)

Clean, IDE-friendly syntax with explicit configuration:

```zig
const Args = struct {
    verbose: bool = zync_cli.flag(.{ .short = 'v', .help = "Enable verbose output" }),
    config: []const u8 = zync_cli.required([]const u8, zync_cli.RequiredConfig([]const u8){ 
        .short = 'c', 
        .help = "Configuration file path" 
    }),
    port: u16 = zync_cli.option(zync_cli.Option(u16){ 
        .short = 'p', 
        .default = 8080, 
        .help = "Port number to listen on" 
    }),
    input: []const u8 = zync_cli.positional([]const u8, zync_cli.PositionalConfig([]const u8){ 
        .help = "Input file path" 
    }),
    
    pub const dsl_metadata = &[_]zync_cli.FieldMetadata{
        .{ .name = "verbose", .short = 'v', .help = "Enable verbose output" },
        .{ .name = "config", .short = 'c', .required = true, .help = "Configuration file path" },
        .{ .name = "port", .short = 'p', .default = "8080", .help = "Port number to listen on" },
        .{ .name = "input", .positional = true, .help = "Input file path" },
    };
};
```

**Benefits:**
- Clean, readable field names (`args.verbose` vs `args.@"verbose|v"`)
- IDE auto-completion and syntax highlighting
- Rich help text and descriptions
- Type-safe configuration structs
- Future-proof for advanced features

### 2. Enhanced Metadata Helpers

The function-based DSL now includes helper functions that eliminate duplication and ensure type safety:

```zig
const Args = struct {
    // Field definitions using DSL functions
    verbose: bool = zync_cli.flag(.{ .short = 'v', .help = "Enable verbose output" }),
    debug: bool = zync_cli.flag(.{ .short = 'd', .help = "Debug mode", .hidden = true }),
    name: []const u8 = zync_cli.option(zync_cli.Option([]const u8){ 
        .short = 'n', 
        .default = "World", 
        .help = "Name to greet" 
    }),
    count: u32 = zync_cli.option(zync_cli.Option(u32){ 
        .short = 'c', 
        .default = 5, 
        .help = "Number of iterations" 
    }),
    config: []const u8 = zync_cli.required([]const u8, zync_cli.RequiredConfig([]const u8){ 
        .short = 'f', 
        .help = "Configuration file path" 
    }),
    
    // Metadata using helper functions - no duplication, automatic type conversion!
    pub const dsl_metadata = &[_]zync_cli.FieldMetadata{
        zync_cli.flagMeta("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        zync_cli.flagMeta("debug", .{ .short = 'd', .help = "Debug mode", .hidden = true }),
        zync_cli.optionMeta([]const u8, "name", .{ .short = 'n', .default = "World", .help = "Name to greet" }),
        zync_cli.optionMeta(u32, "count", .{ .short = 'c', .default = 5, .help = "Number of iterations" }),
        zync_cli.requiredMeta("config", .{ .short = 'f', .help = "Configuration file path" }),
    };
};
```

**Key Benefits:**
- **No duplication** - Same configuration objects used for both field definitions and metadata
- **Type safety** - Automatic type checking and conversion between field types and string defaults
- **Hidden flags** - Support for flags that work but don't appear in help text
- **Automatic conversion** - Numbers and booleans automatically converted to string defaults
- **Clean syntax** - Much more readable than manual FieldMetadata construction

### 3. Legacy Field Encoding DSL (Still Supported)

Compact syntax embedded in struct field names:

### Syntax Reference

| Syntax | Description | Example |
|--------|-------------|---------|
| `\|x` | Short flag | `@"verbose\|v"` → `--verbose`, `-v` |
| `!` | Required field | `@"config\|c!"` → Must be provided |
| `=value` | Default value | `@"port\|p=8080"` → Defaults to 8080 |
| `#` | Positional argument | `@"#input"` → Positional parameter |
| `*` | Multiple values | `@"files\|f*"` → Accept multiple files |
| `+` | Counting flag | `@"verbose\|v+"` → `-vvv` for level 3 |
| `$VAR` | Environment variable | `@"token\|t$API_TOKEN"` → From env var |

### Examples

```zig
const Config = struct {
    // Basic flags
    @"verbose|v": bool = false,
    @"quiet|q": bool = false,
    
    // Required string argument
    @"config|c!": []const u8,
    
    // Optional with default
    @"port|p=8080": u16,
    @"host|h=localhost": []const u8,
    
    // Positional arguments
    @"#input": []const u8,
    @"#output": ?[]const u8 = null,
    
    // Advanced features (planned)
    @"files|f*": [][]const u8,      // Multiple values
    @"debug|d+": u8,               // Counting (-ddd = 3)
    @"token|t$API_TOKEN": []const u8, // From environment
};
```

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

### Core Functions

#### `parse(T, allocator, args)`
Parse from custom argument array.

```zig
const args = &.{"--verbose", "--name", "Alice"};
const result = try zync_cli.parse(Args, arena.allocator(), args);
```

#### `parseProcess(T, allocator)`
Parse command-line arguments from process (automatically skips program name).

```zig
const result = try zync_cli.parseProcess(Args, arena.allocator());
```

#### `Parser(T)`
Type-specific parser with compile-time optimization.

```zig
const result = try zync_cli.Parser(Args).parse(allocator, args);
const help_text = zync_cli.Parser(Args).help();
```

#### `help(T)`
Generate help text for struct type `T`.

```zig
const help_text = zync_cli.help(Args);
std.debug.print("{s}\n", .{help_text});
```

#### `validate(T)`
Compile-time validation of struct definition.

```zig
comptime zync_cli.validate(Args); // Validates at compile time
```

### DSL Metadata Helpers

#### `flagMeta(name, config)`
Create FieldMetadata from FlagConfig.

```zig
const metadata = zync_cli.flagMeta("verbose", .{ .short = 'v', .help = "Enable verbose output" });
```

#### `optionMeta(T, name, config)`
Create FieldMetadata from OptionConfig with automatic type conversion.

```zig
const metadata = zync_cli.optionMeta(u32, "count", .{ .short = 'c', .default = 5, .help = "Number of iterations" });
```

#### `requiredMeta(name, config)`
Create FieldMetadata from RequiredConfig.

```zig
const metadata = zync_cli.requiredMeta("config", .{ .short = 'f', .help = "Configuration file path" });
```

#### `positionalMeta(T, name, config)`
Create FieldMetadata from PositionalConfig.

```zig
const metadata = zync_cli.positionalMeta([]const u8, "input", .{ .help = "Input file path" });
```

### Simple Return Values

Parsing functions now return the parsed arguments directly:

```zig
// Simple and clean
const args = try zync_cli.parseProcess(Args, arena.allocator());
// No manual cleanup needed - arena handles memory
```

### Error Handling & Automatic Help

Zync-CLI automatically handles help flags and displays help text before any validation occurs:

```zig
const args = zync_cli.parseProcess(Args, arena.allocator()) catch |err| switch (err) {
    error.HelpRequested => {
        // Help was automatically displayed by the parser
        return;
    },
    error.UnknownFlag => {
        std.debug.print("Unknown flag provided. Use --help for usage.\n", .{});
        return;
    },
    error.MissingRequiredArgument => {
        std.debug.print("Missing required argument. Use --help for usage.\n", .{});
        return;
    },
    error.MissingValue => {
        std.debug.print("Missing required value. Use --help for usage.\n", .{});
        return;
    },
    error.InvalidValue => {
        std.debug.print("Invalid value format. Use --help for usage.\n", .{});
        return;
    },
    else => return err,
};
```

**Key Features:**
- **No manual help checking required** - Help flags are processed automatically
- **Pre-validation help** - Help works even when required fields are missing
- **Standard conventions** - Supports both `--help` and `-h` flags
- **Custom help fields** - Automatically detects help fields in your struct

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
const zync_cli = @import("zync-cli");

test "my CLI parsing" {
    const Args = struct {
        verbose: bool = zync_cli.flag(.{ .short = 'v', .help = "Enable verbose output" }),
        name: []const u8 = zync_cli.option(zync_cli.OptionConfig([]const u8){ 
            .short = 'n', 
            .default = "test", 
            .help = "Name to use" 
        }),
        
        pub const dsl_metadata = &[_]zync_cli.FieldMetadata{
            .{ .name = "verbose", .short = 'v', .help = "Enable verbose output" },
            .{ .name = "name", .short = 'n', .default = "test", .help = "Name to use" },
        };
    };
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    // Test successful parsing
    const result = try zync_cli.parse(Args, arena.allocator(), &.{"--verbose", "--name", "Alice"});
    try std.testing.expect(result.verbose == true);
    try std.testing.expectEqualStrings(result.name, "Alice");
    
    // Test error conditions
    try std.testing.expectError(error.UnknownFlag, 
        zync_cli.parse(Args, arena.allocator(), &.{"--invalid"}));
}
```

### Current Test Coverage

- **156 total tests** across all modules
- **Dual DSL support** - Both function-based and field encoding DSL
- **Function-based DSL** configuration and metadata extraction
- **Field encoding DSL** parsing and validation  
- **Argument parsing** for all supported types
- **Required field validation** with `!` syntax and `required()` function
- **Default value handling** with `=value` syntax and `option()` function
- **Positional arguments** with `#` syntax and `positional()` function
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

const args = try zync_cli.parseProcess(Args, arena.allocator());
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
- **Automatic Cleanup**: O(1) cleanup cost proportional to allocated strings
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
│   ├── colors.zig      # Terminal color support and formatting
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
- [x] Field encoding DSL
- [x] Memory-safe string handling
- [x] Comprehensive test suite
- [x] Help text generation
- [x] Error handling with diagnostics

### Completed (v0.2.0)
- [x] Required field validation with `!` syntax
- [x] Default value handling with `=value` syntax
- [x] Positional argument support with `#` syntax
- [x] Idiomatic Zig architecture with arena allocation
- [x] Type-specific parsers with compile-time optimization
- [x] Comprehensive error handling
- [x] Dynamic help generation from field metadata
- [x] Automatic help flag processing (no user code required)
- [x] Colorized terminal output with smart detection
- [x] Cross-platform color support with environment controls
- [x] Enhanced error messages with context and suggestions
- [x] 119 comprehensive tests

### Completed (v0.3.0)
- [x] Colorized help and error output
- [x] Smart color detection with environment variable support
- [x] Enhanced error messages with detailed context
- [x] ANSI color support with graceful fallback

### Completed (v0.4.0)
- [x] Function-based DSL with clean, IDE-friendly syntax
- [x] Dual DSL support (function-based + legacy field encoding)
- [x] Enhanced metadata system with explicit configuration
- [x] Rich help text with descriptions and type information
- [x] Type-safe configuration structs
- [x] 156 comprehensive tests covering both DSL approaches

### Completed (v0.4.1) - Major Breakthrough!
- [x] **Enhanced DSL metadata helpers** - Dramatically reduces duplication by reusing config objects
- [x] **Automatic type conversion** - Intelligent conversion of defaults (int/float/bool to string)
- [x] **Hidden flag support** - Flags that work but don't appear in help (fixed in help generation)
- [x] **Flexible metadata helpers** - Type-safe helpers for all DSL configuration types
- [x] **Proof of concept for automatic DSL** - Demonstrated full metadata extraction from field definitions

### In Progress
- [ ] Advanced field encodings (`*`, `+`, `$`)
- [ ] Complete automatic DSL metadata generation (eliminate explicit declarations)

### Planned (v0.5.0)
- [ ] Environment variable integration
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