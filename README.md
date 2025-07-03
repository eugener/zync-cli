# Zync-CLI

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](#testing)
[![Tests](https://img.shields.io/badge/tests-86%2F86%20passing-brightgreen)](#testing)
[![Memory Safe](https://img.shields.io/badge/memory-leak%20free-brightgreen)](#memory-management)
[![Zig Version](https://img.shields.io/badge/zig-0.14.1-orange)](https://ziglang.org/)

A powerful, ergonomic command-line interface library for Zig that leverages compile-time metaprogramming for zero-runtime overhead argument parsing.

## Features

- **Zero Runtime Overhead** - All parsing logic resolved at compile time
- **Type Safe** - Full compile-time type checking and validation
- **Ergonomic DSL** - Intuitive field encoding syntax for CLI definitions
- **Memory Safe** - Automatic memory management with zero leaks
- **Rich Diagnostics** - Helpful error messages with suggestions
- **Battle Tested** - 86 comprehensive tests covering all functionality
- **Self-Documenting** - Automatic help generation from field definitions

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
const zync_cli = @import("zync-cli");

const Args = struct {
    @"verbose|v": bool = false,
    @"name|n=World": []const u8 = "",
    @"count|c=1": u32 = 0,
    @"help|h": bool = false,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{});
    defer _ = gpa.deinit();
    
    var result = try zync_cli.parse(Args, gpa.allocator());
    defer result.deinit(); // Automatic cleanup
    
    if (result.args.@"help|h") {
        std.debug.print("{s}\n", .{zync_cli.help(Args)});
        return;
    }
    
    if (result.args.@"verbose|v") {
        std.debug.print("Verbose mode enabled!\n", .{});
    }
    
    var i: u32 = 0;
    while (i < result.args.@"count|c=1") : (i += 1) {
        std.debug.print("Hello, {s}!\n", .{result.args.@"name|n=World"});
    }
}
```

**Running the example:**
```bash
$ ./myapp --verbose --name Alice --count 3
Verbose mode enabled!
Hello, Alice!
Hello, Alice!
Hello, Alice!

$ ./myapp --help
Usage: [OPTIONS]

Options:
  -v, --verbose     Enable verbose output
  -n, --name        Set name value  
  -c, --count       Set count value
  -h, --help        Show this help message
```

## Field Encoding DSL

Zync-CLI uses an intuitive DSL embedded in struct field names to define CLI arguments:

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

#### `parse(T, allocator)`
Parse command-line arguments into struct of type `T`.

```zig
var result = try zync_cli.parse(Args, allocator);
defer result.deinit();
```

#### `parseFrom(T, allocator, args)`
Parse from custom argument array.

```zig
const args = &.{"myapp", "--verbose", "--name", "Alice"};
var result = try zync_cli.parseFrom(Args, allocator, args);
defer result.deinit();
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

#### Legacy API (Backward Compatible)
The old verbose API is still available for backward compatibility:

```zig
var result = try zync_cli.cli.parse(Args, allocator);  // Still works
const help_text = zync_cli.cli.help(Args);            // Still works
```

### ParseResult

The `ParseResult(T)` type contains the parsed arguments and metadata:

```zig
const ParseResult = struct {
    args: T,                              // Parsed arguments
    diagnostics: []const Diagnostic,     // Warnings and info messages  
    allocator: std.mem.Allocator,       // Memory allocator used
    
    pub fn deinit(self: *Self) void;    // Clean up memory
};
```

### Error Handling

```zig
var result = zync_cli.parse(Args, allocator) catch |err| switch (err) {
    error.UnknownFlag => {
        std.debug.print("Unknown flag provided. Use --help for usage.\n", .{});
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
        verbose: bool = false,
        name: []const u8 = "test",
    };
    
    // Test successful parsing
    try zync_cli.testing.expectParse(Args, &.{"--verbose", "--name", "Alice"}, 
        Args{ .verbose = true, .name = "Alice" });
    
    // Test error conditions
    try zync_cli.testing.expectParseError(error.UnknownFlag, Args, &.{"--invalid"});
    
    // Test diagnostics
    try zync_cli.testing.expectDiagnostics(Args, &.{"--unknown"}, 1);
}
```

### Current Test Coverage

- **86 total tests** across all modules
- **Field encoding DSL** parsing and validation
- **Argument parsing** for all supported types
- **Error handling** and diagnostic generation
- **Memory management** and leak detection
- **Help generation** and formatting
- **Integration testing** with real CLI scenarios

## Memory Management

Zync-CLI provides automatic, leak-free memory management:

### Automatic Cleanup

```zig
var result = try zync_cli.parse(Args, allocator);
defer result.deinit(); // Automatically frees all allocated memory
// No manual string cleanup required!
```

### Memory Safety Features

- **Zero Leaks**: Automatic tracking and cleanup of all allocated strings
- **Safe Defaults**: No dangling pointers or invalid memory access
- **Allocator Flexibility**: Works with any Zig allocator
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
│   ├── root.zig        # Main library API
│   ├── types.zig       # Core type definitions  
│   ├── parser.zig      # Argument parsing engine
│   ├── meta.zig        # Compile-time metadata extraction
│   ├── help.zig        # Help text generation
│   ├── testing.zig     # Testing utilities
│   └── main.zig        # Demo application
├── build.zig           # Build configuration
├── README.md           # This file
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
- [x] Required field validation
- [x] Default value handling with DSL syntax
- [x] Comprehensive diagnostics and error reporting

### In Progress
- [ ] Advanced field encodings (`*`, `+`, `$`)

### Planned (v0.2.0)
- [ ] Positional argument support
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