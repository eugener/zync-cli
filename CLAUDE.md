# Zync-CLI Project Documentation

## Project Overview

Zync-CLI is a comprehensive command-line interface library for Zig that provides ergonomic argument parsing using compile-time features for zero runtime overhead. The library implements a field encoding DSL that allows developers to define CLI arguments using special syntax in struct field names.

## Current Project State

### 🎯 Hierarchical Subcommand System (Latest - v0.5.0)

Zync-CLI now features a powerful hierarchical subcommand system for building Git-style CLI tools:

#### Core Features
- **Unified `command()` Function** - Single function creates both leaf commands and categories
- **Automatic Type Detection** - Distinguishes Args types from subcommand arrays at compile time
- **Compile-Time Depth Validation** - Maximum 5 levels enforced to prevent deep nesting
- **Colorized Help Output** - Beautiful, aligned command listings with smart color detection
- **Environment Variable Support** - Full integration with priority chain for all subcommands
- **Hidden Commands** - Support for internal commands that don't appear in help text
- **Zero Boilerplate** - Single `Commands.parse()` call handles everything

#### Hierarchical Subcommand API
```zig
const zync_cli = @import("zync-cli");

// Define Args for different commands
const ServeArgs = zync_cli.Args(&.{
    zync_cli.flag("daemon", .{ .short = 'd', .help = "Run as daemon", .env_var = "SERVER_DAEMON" }),
    zync_cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on", .env_var = "SERVER_PORT" }),
});

const BuildArgs = zync_cli.Args(&.{
    zync_cli.flag("release", .{ .short = 'r', .help = "Build in release mode", .env_var = "BUILD_RELEASE" }),
    zync_cli.option("target", []const u8, .{ .short = 't', .default = "native", .help = "Target platform", .env_var = "BUILD_TARGET" }),
});

// Create the command hierarchy
const AppCommands = zync_cli.Commands(&.{
    zync_cli.command("serve", ServeArgs, .{ .help = "Start the application server" }),
    zync_cli.command("build", BuildArgs, .{ .help = "Build the application" }),
    zync_cli.command("test", TestArgs, .{ .help = "Run the test suite" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // Single call handles all routing and parsing automatically
    try AppCommands.parse(arena.allocator());
}
```

#### Benefits
- **Git-Style CLI Tools** - Build hierarchical command interfaces like Git, Docker, or Kubectl
- **Type Safety** - All command definitions validated at compile time
- **Automatic Routing** - No manual parsing or routing logic required
- **Beautiful Help** - Colorized, aligned help output with smart terminal detection
- **Environment Variables** - Each subcommand supports environment variable integration
- **Memory Safe** - Arena-based allocation with automatic cleanup
- **Backward Compatible** - Existing `Args()` API continues to work unchanged

#### Technical Implementation
- **Unified Command Function** - `command()` automatically detects leaf vs category commands
- **Compile-Time Validation** - Depth limits and type checking enforced at compile time
- **160 Tests** - Comprehensive test coverage including subcommand system validation

### 🚀 Method-Style API (v0.4.0)

Zync-CLI provides an ergonomic method-style API that eliminates verbose namespaces while maintaining all existing functionality:

#### Core Features
- **Ergonomic Methods** - `Args.parse()`, `Args.parseFrom()`, `Args.help()`, `Args.validate()`
- **Method-Style API** - Clean, ergonomic `Args.parse()` interface
- **Zero Overhead** - Same compile-time optimization as before
- **Type Safety** - Methods are bound to the specific Args type for better IDE support
- **Arena Memory Management** - Integrated with arena allocation for automatic cleanup

#### Method-Style API
```zig
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .env_var = "APP_VERBOSE" }),
    cli.option("port", u16, .{ .default = 8080, .env_var = "APP_PORT" }),
    cli.required("config", []const u8, .{ .env_var = "APP_CONFIG" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    const args = Args.parse(arena.allocator()) catch |err| switch (err) {
        error.HelpRequested => return,
        else => std.process.exit(1),
    };
    
    if (args.verbose) {
        std.debug.print("Verbose mode enabled!\n", .{});
    }
}
```

#### Benefits
- **More Intuitive** - `Args.parse()` feels natural and discoverable
- **IDE-Friendly** - Auto-completion shows available methods
- **Type-Safe** - Methods are bound to the specific Args type
- **Less Verbose** - Saves 4 characters per function call
- **Better UX** - Follows common Zig library patterns

#### Technical Implementation
- **Generated Methods** - Added to the struct returned by `cli.Args()`
- **Automatic Help** - Built-in help flag processing with `error.HelpRequested`
- **Memory Safety** - Arena-based allocation with automatic cleanup
- **146 Tests** - Comprehensive test coverage including method-style API validation

### ✨ Colorized Output Enhancement (v0.3.0)

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
// Clean and simple - no boilerplate needed!
const args = try Args.parse(arena.allocator());
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
   - Method-style API available on Args struct (parse, parseFrom, help, validate)
   - DSL exports (`Args`, `flag`, `option`, `required`, `positional`)
   - Configuration types (`FlagConfig`, `OptionConfig`, `RequiredConfig`, `PositionalConfig`)

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
- **175 total tests** across all modules (100% passing)
- **Individual module testing** with granular test commands
- **Integration tests** covering end-to-end functionality
- **Expanded coverage** including all DSL features and edge cases
- **Automatic help testing** with comprehensive help flag scenarios
- **ANSI-aware testing** with color code stripping for reliable cross-environment testing

#### Test Commands
```bash
# Run all tests (175 tests across 8 modules)
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
- ✅ Nested subcommand testing with unlimited depth
- ✅ Environment variable integration testing
- ✅ ANSI color code handling in tests

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
│   ├── cli.zig         # Function-based DSL and subcommand system
│   ├── help.zig        # Help text generation
│   ├── colors.zig      # Terminal color support
│   ├── testing.zig     # Test utilities
│   └── main.zig        # Demo application
├── examples/
│   ├── simple.zig      # Minimal usage example
│   ├── basic.zig       # Complete example with custom banner
│   ├── environment.zig # Environment variable demonstration
│   └── commands.zig    # Comprehensive command system with handlers and nested subcommands
├── build.zig           # Enhanced build configuration
├── spec.md             # Original library specification
├── README.md           # Comprehensive user documentation
└── CLAUDE.md           # This documentation file
```

## 🔧 Current Limitations & TODOs

### High Priority
1. **True nested subcommands** - Implement recursive category commands for deep hierarchies
2. **Multiple value support** - `*` encoding for arrays and repeated arguments

### Medium Priority
1. **Advanced field encodings** - Implement `+` syntax for counting flags
2. **Configuration file support** - TOML/JSON config integration
3. **Enhanced help formatting** - Improve help text layout and styling

### Low Priority
1. **Documentation generation** - Auto-generate docs from field metadata
2. **Bash completion** - Generate shell completion scripts
3. **Performance optimizations** - Benchmarking and optimization

## 🎯 Next Development Steps

### Immediate (Next Session)
1. Implement true nested subcommands with recursive category commands
2. Add support for multiple value support with `*` syntax 
3. Add counting flags with `+` syntax

### Short Term
1. Configuration file parsing (TOML/JSON integration)
2. Enhanced help formatting and layout improvements
3. Performance optimizations and benchmarking

### Long Term
1. Plugin system for custom field types
2. Shell completion generation (bash, zsh, fish)
3. Documentation generation from metadata

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

- **Lines of Code**: ~1,400 (excluding tests, optimized through cleanup and utility modules)
- **Test Coverage**: 175 tests, 100% passing, ANSI-aware, including handler system
- **Modules**: 10 core modules + demo app + 4 streamlined examples (added utility modules, consolidated examples)
- **Supported Types**: bool, int, float, []const u8, optional types
- **Environment Variables**: Full integration with priority chain support
- **Function-based DSL**: Zero-duplication metadata extraction
- **Handler System**: Automatic command execution with type-safe function calling
- **Subcommand System**: True nested commands with unlimited depth, recursive parsing, and handler support
- **Help System**: Dynamic generation with automatic flag processing and command path tracking
- **Build Time**: <2 seconds for full build + test
- **Memory Usage**: Arena-based allocation, zero leaks, automatic cleanup
- **API Design**: Idiomatic Zig patterns, simple and clean interface
- **Color Support**: Cross-platform ANSI colors with smart detection and test-aware stripping
- **Terminal Features**: Colorized help, enhanced error messages, environment awareness
- **Code Quality**: Unified utilities, consolidated error handling, comprehensive redundancy elimination

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

### Completed (v0.3.0) - Advanced Color System & API Improvements
- [x] **Enhanced color API** with format support (`addTextf`, `addTextWriterf`)
- [x] **Writer interface support** for any output destination
- [x] **Function cleanup and optimization** - removed 12 redundant functions
- [x] **Improved error handling** with clean user-facing messages
- [x] **Simplified color detection** using stdlib TTY support
- [x] **Comprehensive function renaming** following Zig conventions
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

### Completed (v0.4.0) - Environment Variable Integration
- [x] **Environment variable support** with `.env_var = "VAR_NAME"` configuration
- [x] **Standard priority chain** - CLI args → env vars → defaults
- [x] **Type-safe environment variables** for all supported types (bool, int, float, string)
- [x] **Required field satisfaction** - Environment variables can fulfill required fields
- [x] **Seamless DSL integration** with existing function-based API
- [x] **Comprehensive testing** - 103 tests covering all environment variable scenarios
- [x] **Memory safety** - Integrated with arena allocation system
- [x] **Cross-platform support** - Works on all platforms with standard environment APIs

### Completed (v0.5.0) - Hierarchical Subcommand System
- [x] **Unified `command()` function** - Single function for both leaf commands and categories
- [x] **Automatic type detection** - Distinguishes Args types from subcommand arrays at compile time
- [x] **Compile-time depth validation** - Maximum 5 levels enforced to prevent deep nesting
- [x] **Colorized subcommand help** - Beautiful, aligned command listings with smart color detection
- [x] **Environment variable support** - Full integration with priority chain for all subcommands
- [x] **Hidden commands** - Support for internal commands that don't appear in help text
- [x] **Zero boilerplate** - Single `Commands.parse()` call handles all routing and parsing
- [x] **Comprehensive testing** - 160/160 tests covering all subcommand functionality
- [x] **Multilevel command organization** - Professional command patterns using descriptive naming
- [x] **Complete multilevel example** - Demonstrates Git-style, Docker-style, and database-style CLI patterns

### Completed (v0.6.0) - Handler System & Code Quality Improvements
- [x] **Handler execution system** - Direct command execution with automatic function calling and type safety
- [x] **Automatic type conversion** - Functions converted to handlers with zero boilerplate (`.handler = myFunction`)
- [x] **Type-safe handler functions** - Handlers receive properly typed arguments and allocator for memory management
- [x] **Error propagation** - Handler errors flow naturally through the call stack with proper error handling
- [x] **Nested handler support** - Handlers work seamlessly with subcommand hierarchies and automatic routing
- [x] **Comprehensive examples** - Streamlined `commands.zig` example demonstrating handlers, nested subcommands, and CLI patterns
- [x] **Dead code removal** - Eliminated unused `ParseResult(T)` type and redundant functions
- [x] **Parser logic consolidation** - Extracted `convertValueToType()` function, removed ~100 lines of duplication
- [x] **Error handling unification** - Added utility modules (`error_utils.zig`, `test_utils.zig`, `field_utils.zig`)
- [x] **Test reliability fixes** - Solved ANSI color code issues causing environment-dependent test failures
- [x] **ANSI-aware testing** - Added color code stripping for consistent cross-environment testing
- [x] **175 comprehensive tests** - Expanded from 160 tests with full coverage including handler system
- [x] **Comprehensive redundancy cleanup** - Consolidated duplicate code patterns and unified utilities

### Planned (v0.7.0)
- [ ] Configuration file parsing (TOML/JSON)
- [ ] Multiple value support with array types
- [ ] Advanced field validation

### Future (v1.0.0)
- [ ] Plugin system for custom types
- [ ] Shell completion generation
- [ ] Performance optimizations

---

*Last updated: After completing handler system implementation and comprehensive code quality improvements (v0.6.0). The library now features a powerful command handler system enabling automatic execution of business logic after argument parsing, with zero-boilerplate function assignment (`.handler = myFunction`) and full type safety. Additionally includes dead code removal, parser logic consolidation, unified error handling utilities, and ANSI-aware testing for reliable cross-environment operation. Test coverage expanded to 175/175 tests with full handler system coverage. The codebase is now optimized for both functionality and maintainability while preserving backward compatibility. Handler system works seamlessly with nested subcommand hierarchies for complete CLI application development.*