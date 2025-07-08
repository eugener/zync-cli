# Zync-CLI Project Documentation

## Project Overview

Zync-CLI is a comprehensive command-line interface library for Zig that provides ergonomic argument parsing using compile-time features for zero runtime overhead. The library implements a field encoding DSL that allows developers to define CLI arguments using special syntax in struct field names.

## Current Project State

### ✨ Colorized Output Enhancement (Latest)

Zync-CLI now features beautiful, intelligent terminal colors that enhance user experience:

#### Smart Color System
- **Automatic Detection** - Detects terminal color support via `std.posix.isatty()`
- **Environment Variables** - Respects `NO_COLOR` and `FORCE_COLOR` standards
- **Cross-Platform** - Works consistently across all platforms
- **Graceful Fallback** - Automatically falls back to plain text when needed

#### Visual Enhancements
- **Colorized Help** - Flags in green, titles in cyan, required fields in red
- **Enhanced Errors** - Red errors, bright red context, yellow suggestions
- **Smart Highlighting** - Default values in magenta, examples in cyan
- **Professional Appearance** - Clean, readable terminal output

#### Technical Implementation
- **New Module** - `src/colors.zig` with ANSI color support
- **Direct Printing** - Efficient color output without complex formatting
- **Zero Overhead** - Colors disabled add no performance cost
- **Memory Safe** - No additional allocations for color codes

### 🏗️ Major Architecture Refactoring (Completed)

The codebase underwent a comprehensive refactoring to follow idiomatic Zig patterns and best practices:

#### Before (Complex Architecture)
- Complex `ParseResult(T)` wrapper with manual cleanup
- Redundant `cli` namespace with duplicate APIs
- Complex memory management with potential leaks
- Scattered functions without clear ownership

#### After (Idiomatic Zig Architecture)
- **Simple direct return values** - Functions return `T` directly
- **Arena-based memory management** - Automatic cleanup with zero leaks
- **Type-specific parsers** - `Parser(T)` with compile-time optimization
- **Clean API surface** - Removed redundant namespaces and functions
- **Automatic help handling** - Built-in help flag processing with no user code
- **Inline compile-time loops** - Proper use of `inline for` for struct fields

#### API Simplification Examples

**Before:**
```zig
var result = try cli.parseFrom(Args, allocator, args);
defer result.deinit();
const parsed_args = result.value;
```

**After:**
```zig
var arena = std.heap.ArenaAllocator.init(allocator);
defer arena.deinit();
const args = zync_cli.parseProcess(Args, arena.allocator()) catch |err| switch (err) {
    error.HelpRequested => return, // Help automatically displayed
    else => return err,
};
```

### ✅ Completed Features

#### Core Library Architecture
- **Idiomatic Zig design** following best practices with clean, simple API
- **Zero runtime overhead** using Zig's compile-time metaprogramming
- **Type-safe argument parsing** with comprehensive error handling
- **Arena-based memory management** for leak-free operation
- **Type-specific parsers** with compile-time optimization

#### Dual DSL Support
The library supports both legacy field encoding DSL and modern function-based DSL:

**Legacy Field Encoding DSL (Still Supported):**
```zig
const Args = struct {
    @"verbose|v": bool = false,           // --verbose, -v (boolean flag)
    @"config|c!": []const u8,             // --config, -c (required)
    @"output|o=/tmp/out": []const u8,     // --output, -o (with default)
    @"#input": []const u8,                // positional argument
    @"count|n=1": u32,                    // --count, -n (integer with default)
};
```

**Modern Function-Based DSL (Recommended):**
```zig
const zync_cli = @import("zync-cli");

const Args = struct {
    verbose: bool = zync_cli.flag(.{ .short = 'v', .help = "Enable verbose output" }),
    config: []const u8 = zync_cli.required([]const u8, zync_cli.RequiredConfig([]const u8){ 
        .short = 'c', 
        .help = "Configuration file path" 
    }),
    output: []const u8 = zync_cli.option(zync_cli.OptionConfig([]const u8){ 
        .short = 'o', 
        .default = "/tmp/out", 
        .help = "Output directory" 
    }),
    input: []const u8 = zync_cli.positional([]const u8, zync_cli.PositionalConfig([]const u8){ 
        .help = "Input file" 
    }),
    count: u32 = zync_cli.option(zync_cli.Option(u32){ 
        .short = 'n', 
        .default = 1, 
        .help = "Number of iterations" 
    }),
    
    // Explicit metadata for function-based DSL
    pub const dsl_metadata = &[_]zync_cli.FieldMetadata{
        .{ .name = "verbose", .short = 'v', .help = "Enable verbose output" },
        .{ .name = "config", .short = 'c', .required = true, .help = "Configuration file path" },
        .{ .name = "output", .short = 'o', .default = "/tmp/out", .help = "Output directory" },
        .{ .name = "input", .positional = true, .help = "Input file" },
        .{ .name = "count", .short = 'n', .default = "1", .help = "Number of iterations" },
    };
};
```

**Function-Based DSL Features:**
- `flag()` - Boolean flags with optional short form
- `option()` - Optional arguments with defaults  
- `required()` - Required arguments
- `positional()` - Positional arguments
- Rich help text and descriptions
- IDE-friendly syntax with auto-completion
- Type safety at compile time
- Clean, readable field definitions

#### Implemented Modules

1. **`src/root.zig`** - Main library API (simplified, idiomatic)
   - `parse()` - Parse from custom argument array
   - `parseProcess()` - Parse command-line arguments
   - `Parser(T)` - Type-specific parser with compile-time optimization
   - `help()` - Generate help text
   - `validate()` - Compile-time validation
   - Function-based DSL exports (`flag`, `option`, `required`, `positional`)

2. **`src/types.zig`** - Core type definitions
   - `ParseError` - Comprehensive error types
   - Legacy `ParseResult(T)` stub for backward compatibility
   - `FieldMetadata` - Field encoding metadata

3. **`src/parser.zig`** - Argument parsing engine (completely rewritten)
   - Arena-based memory management
   - Long flag parsing (`--flag`, `--flag=value`)
   - Short flag parsing (`-f`, `-f value`)
   - Boolean flag detection
   - Type conversion (string → int, bool, etc.)
   - Required field validation with `!` syntax
   - Default value handling with `=value` syntax
   - Positional argument support with `#` syntax

4. **`src/meta.zig`** - Compile-time metadata extraction
   - Field encoding DSL parser
   - Function-based DSL metadata support
   - Struct field analysis
   - Type validation (simplified)
   - Metadata extraction for runtime use

5. **`src/dsl.zig`** - Function-based DSL implementation
   - `flag()` - Boolean flag definitions
   - `option()` - Optional arguments with defaults
   - `required()` - Required argument definitions
   - `positional()` - Positional argument definitions
   - Configuration types with compile-time markers
   - Metadata generation helpers

6. **`src/help.zig`** - Help text generation
   - Dynamic help generation with metadata
   - Unified `formatHelp()` function with color support
   - Automatic help option support

7. **`src/colors.zig`** - Terminal color support
   - `printError()` - Colorized error message output
   - `supportsColor()` - Smart color detection with caching
   - Environment variable support (`NO_COLOR`, `FORCE_COLOR`)
   - Cross-platform ANSI color codes

8. **`src/testing.zig`** - Testing utilities
   - `expectParse()` - Test successful parsing
   - `expectParseError()` - Test error conditions
   - `expectDiagnostics()` - Test warning/info messages
   - Type-aware value comparison

#### Automatic Help System (New Feature)
- **Built-in help processing** - No user code required for help flags
- **Pre-validation help** - Help works even when required fields are missing
- **Standard conventions** - Supports `--help`, `-h`, and custom help fields
- **HelpRequested error** - Clean error handling for program exit
- **Dynamic generation** - Help text generated from field metadata

#### Working Demo Application
- **`src/main.zig`** - Functional CLI demo showing real-world usage
- Demonstrates arena-based memory management
- Shows new simplified API integration
- Includes automatic help flag handling
- Includes comprehensive DSL feature demonstration

### 🧪 Testing Infrastructure

#### Comprehensive Test Coverage
- **119 total tests** across all modules (100% passing)
- **Individual module testing** with granular test commands
- **Integration tests** covering end-to-end functionality
- **Expanded coverage** including all DSL features and edge cases
- **Automatic help testing** with comprehensive help flag scenarios

#### Test Commands
```bash
# Run all tests (119 tests across 8 modules)
zig build test

# Run specific module tests
zig build test-parser    # Parser functionality
zig build test-types     # Type definitions
zig build test-meta      # Metadata extraction
zig build test-help      # Help generation
zig build test-colors    # Color system testing
zig build test-testing   # Testing utilities

# Run with detailed output
zig build test --summary all
```

#### Test Coverage Areas
- ✅ Field encoding DSL parsing (`#input`, `verbose|v`, `config|c!`, `name=default`)
- ✅ Argument parsing (long flags, short flags, values, embedded values)
- ✅ Boolean flag detection and handling
- ✅ Type conversion (string → int, bool, float)
- ✅ Required field validation with `!` syntax
- ✅ Default value handling with `=value` syntax
- ✅ Positional argument support with `#` syntax
- ✅ Automatic help flag processing (`--help`, `-h`)
- ✅ Error handling for all error conditions
- ✅ Arena-based memory management (leak-free)
- ✅ Help text generation (dynamic)
- ✅ Colorized output with smart terminal detection
- ✅ Color environment variable support (`NO_COLOR`, `FORCE_COLOR`)
- ✅ Cross-platform ANSI color compatibility
- ✅ Enhanced error messages with contextual highlighting
- ✅ Integration testing with comprehensive scenarios

### 🚀 Build System

#### Build Commands
```bash
# Build library and executable
zig build

# Run the demo application
zig build run -- --verbose --name Alice --count 3

# Install artifacts
zig build install

# Development workflow
zig build test && zig build run
```

### 📁 Project Structure

```
zync-cli/
├── src/
│   ├── root.zig        # Main library API
│   ├── types.zig       # Core type definitions
│   ├── parser.zig      # Argument parsing with detailed errors
│   ├── meta.zig        # Compile-time metadata
│   ├── help.zig        # Help text generation
│   ├── colors.zig      # Terminal color support
│   ├── testing.zig     # Test utilities
│   └── main.zig        # Demo application
├── build.zig           # Enhanced build configuration
├── spec.md             # Original library specification
└── CLAUDE.md           # This documentation file
```

## 🔧 Current Limitations & TODOs

### High Priority
1. **Advanced field encodings** - Implement `*`, `+`, `$` syntax
2. **Environment variable support** - `$VAR` encoding implementation

### Medium Priority
1. **Subcommand support** - Tagged union parsing for complex CLI tools
2. **Multiple value support** - `*` encoding for arrays
3. **Enhanced help formatting** - Improve help text layout and styling

### Low Priority
1. **Documentation generation** - Auto-generate docs from field metadata
2. **Bash completion** - Generate shell completion scripts
3. **Configuration file support** - TOML/JSON config integration

## 🎯 Next Development Steps

### Immediate (Next Session)
1. Add environment variable support with `$VAR` syntax
2. Implement multiple value support with `*` syntax
3. Add counting flags with `+` syntax

### Short Term
1. Implement counting flags with `+` syntax
2. Add subcommand support using tagged unions
3. Enhance error messages with suggestions for unknown flags

### Long Term
1. Subcommand system using tagged unions
2. Plugin system for custom field types
3. Performance optimization and benchmarking

## 🔄 Development Guidelines

### Testing Requirements
- **All changes must pass existing tests** - Run `zig build test` before commits
- **New features require tests** - Maintain comprehensive test coverage
- **Test-driven development** - Write tests first when possible

### Code Quality Standards
- **Follow Zig conventions** - Use existing patterns in codebase
- **Compile-time safety** - Leverage Zig's compile-time features
- **Zero runtime overhead** - Maintain performance goals
- **Clear error messages** - Provide helpful diagnostics

### Memory Management
- **Use arena allocators** - Automatic cleanup with single `deinit()` call
- **No manual cleanup** - Arena handles all string allocation
- **Test memory leaks** - Use testing allocator in tests
- **Zero leaks guarantee** - Arena-based allocation ensures no memory leaks

### API Stability
- **Maintain backward compatibility** - Don't break existing user code
- **Document breaking changes** - Update this file with any API changes
- **Version semantic changes** - Follow semver principles

## 📊 Project Metrics

- **Lines of Code**: ~1,400 (excluding tests)
- **Test Coverage**: 119 tests, 100% passing
- **Modules**: 7 core modules + demo app
- **Supported Types**: bool, int, float, []const u8, optional types
- **Field Encodings**: 4 implemented (`|`, `!`, `=`, `#`), 3 planned (`*`, `+`, `$`)
- **Help System**: Dynamic generation with automatic flag processing
- **Build Time**: <2 seconds for full build + test
- **Memory Usage**: Arena-based allocation, zero leaks, automatic cleanup
- **API Design**: Idiomatic Zig patterns, simple and clean interface
- **Color Support**: Cross-platform ANSI colors with smart detection
- **Terminal Features**: Colorized help, enhanced error messages, environment awareness

## 🗺️ Development Roadmap

### Completed (v0.1.0)
- [x] Core argument parsing engine
- [x] Field encoding DSL (`|`, `!`, `=`, `#`)
- [x] Memory-safe string handling
- [x] Comprehensive test suite
- [x] Help text generation
- [x] Error handling with diagnostics

### Completed (v0.2.0) - Major Architecture Refactoring
- [x] **Idiomatic Zig architecture** with arena allocation
- [x] **Simplified API** removing redundant cli namespace
- [x] **Type-specific parsers** with compile-time optimization
- [x] **Required field validation** with `!` syntax
- [x] **Default value handling** with `=value` syntax
- [x] **Positional argument support** with `#` syntax
- [x] **Comprehensive error handling** for all edge cases
- [x] **Dynamic help generation** from field metadata
- [x] **Automatic help flag processing** (no user code required)
- [x] **117 comprehensive tests** (expanded from 48)
- [x] **Arena-based memory management** (zero leaks)
- [x] **Bug fixes** for program name handling and field matching

### Completed (v0.3.0) - Colorized Output & Enhanced UX
- [x] **Colorized terminal output** with smart detection
- [x] **Enhanced error messages** with detailed context and suggestions
- [x] **Cross-platform color support** with ANSI escape codes
- [x] **Environment variable controls** (`NO_COLOR`, `FORCE_COLOR`)
- [x] **Visual hierarchy** in help text (colors for flags, required fields, etc.)
- [x] **Professional appearance** for CLI applications
- [x] **Zero performance overhead** when colors are disabled
- [x] **Graceful fallback** to plain text when colors aren't supported

### In Progress (v0.4.0)
- [ ] Environment variable integration with `$VAR` syntax
- [ ] Multiple value support with `*` syntax
- [ ] Counting flags with `+` syntax

### Planned (v0.5.0)
- [ ] Subcommand system with tagged unions
- [ ] Configuration file parsing

### Future (v1.0.0)
- [ ] Plugin system for custom types
- [ ] Shell completion generation
- [ ] Configuration file parsing
- [ ] Performance optimizations

---

*Last updated: After implementing colorized terminal output with smart detection and enhanced error messages, and fixing the hanging test issue. The CLI now features beautiful colors, detailed error context with suggestions, cross-platform support, and graceful fallback. Test coverage expanded to 119/119 tests passing with comprehensive color system testing and test-safe I/O handling. Architecture maintains idiomatic Zig patterns with arena-based memory management and zero performance overhead.*