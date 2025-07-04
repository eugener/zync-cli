# Zync-CLI Project Documentation

## Project Overview

Zync-CLI is a comprehensive command-line interface library for Zig that provides ergonomic argument parsing using compile-time features for zero runtime overhead. The library implements a field encoding DSL that allows developers to define CLI arguments using special syntax in struct field names.

## Current Project State

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
const args = try zync_cli.parseProcess(Args, arena.allocator());
```

### ✅ Completed Features

#### Core Library Architecture
- **Idiomatic Zig design** following best practices with clean, simple API
- **Zero runtime overhead** using Zig's compile-time metaprogramming
- **Type-safe argument parsing** with comprehensive error handling
- **Arena-based memory management** for leak-free operation
- **Type-specific parsers** with compile-time optimization

#### Field Encoding DSL
The library supports a comprehensive DSL for encoding CLI argument metadata in struct field names:

```zig
const Args = struct {
    @"verbose|v": bool = false,           // --verbose, -v (boolean flag)
    @"config|c!": []const u8,             // --config, -c (required)
    @"output|o=/tmp/out": []const u8,     // --output, -o (with default)
    @"#input": []const u8,                // positional argument
    @"count|n=1": u32,                    // --count, -n (integer with default)
    @"help|h": bool = false,              // --help, -h (help flag)
};
```

**Supported Encodings:**
- `|x` - Short flag (-x)
- `!` - Required field
- `=value` - Default value
- `#` - Positional argument
- `*` - Multiple values (planned)
- `+` - Counting flag (planned)
- `$VAR` - Environment variable (planned)

#### Implemented Modules

1. **`src/root.zig`** - Main library API (simplified, idiomatic)
   - `parse()` - Parse from custom argument array
   - `parseProcess()` - Parse command-line arguments
   - `Parser(T)` - Type-specific parser with compile-time optimization
   - `help()` - Generate help text
   - `validate()` - Compile-time validation

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
   - Struct field analysis
   - Type validation (simplified)
   - Metadata extraction for runtime use

5. **`src/help.zig`** - Help text generation
   - Static help generation (basic implementation)
   - Usage string generation (simplified)
   - Field documentation support (planned)

6. **`src/testing.zig`** - Testing utilities
   - `expectParse()` - Test successful parsing
   - `expectParseError()` - Test error conditions
   - `expectDiagnostics()` - Test warning/info messages
   - Type-aware value comparison

#### Working Demo Application
- **`src/main.zig`** - Functional CLI demo showing real-world usage
- Demonstrates arena-based memory management
- Shows new simplified API integration
- Includes comprehensive DSL feature demonstration

### 🧪 Testing Infrastructure

#### Comprehensive Test Coverage
- **89 total tests** across all modules (100% passing)
- **Individual module testing** with granular test commands
- **Integration tests** covering end-to-end functionality
- **Expanded coverage** including all DSL features and edge cases

#### Test Commands
```bash
# Run all tests (89 tests across 7 modules)
zig build test

# Run specific module tests
zig build test-parser    # Parser functionality
zig build test-types     # Type definitions
zig build test-meta      # Metadata extraction
zig build test-help      # Help generation
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
- ✅ Error handling for all error conditions
- ✅ Arena-based memory management (leak-free)
- ✅ Help text generation (basic)
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
│   ├── parser.zig      # Argument parsing logic
│   ├── meta.zig        # Compile-time metadata
│   ├── help.zig        # Help text generation
│   ├── testing.zig     # Test utilities
│   └── main.zig        # Demo application
├── build.zig           # Enhanced build configuration
├── spec.md             # Original library specification
└── CLAUDE.md           # This documentation file
```

## 🔧 Current Limitations & TODOs

### High Priority
1. **Dynamic help generation** - Replace static help with metadata-driven generation
2. **Advanced field encodings** - Implement `*`, `+`, `$` syntax

### Medium Priority
1. **Environment variable support** - `$VAR` encoding implementation
2. **Subcommand support** - Tagged union parsing for complex CLI tools
3. **Multiple value support** - `*` encoding for arrays

### Low Priority
1. **Documentation generation** - Auto-generate docs from field metadata
2. **Bash completion** - Generate shell completion scripts
3. **Configuration file support** - TOML/JSON config integration

## 🎯 Next Development Steps

### Immediate (Next Session)
1. Implement dynamic help generation from field metadata
2. Add environment variable support with `$VAR` syntax
3. Implement multiple value support with `*` syntax

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

- **Lines of Code**: ~1,200 (excluding tests)
- **Test Coverage**: 89 tests, 100% passing
- **Modules**: 6 core modules + demo app
- **Supported Types**: bool, int, float, []const u8, optional types
- **Field Encodings**: 4 implemented (`|`, `!`, `=`, `#`), 3 planned (`*`, `+`, `$`)
- **Build Time**: <2 seconds for full build + test
- **Memory Usage**: Arena-based allocation, zero leaks, automatic cleanup
- **API Design**: Idiomatic Zig patterns, simple and clean interface

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
- [x] **89 comprehensive tests** (expanded from 48)
- [x] **Arena-based memory management** (zero leaks)
- [x] **Bug fixes** for program name handling and field matching

### In Progress (v0.3.0)
- [ ] Dynamic help generation from field metadata
- [ ] Environment variable integration with `$VAR` syntax
- [ ] Multiple value support with `*` syntax

### Planned (v0.4.0)
- [ ] Counting flags with `+` syntax
- [ ] Subcommand system with tagged unions
- [ ] Enhanced error messages with suggestions

### Future (v1.0.0)
- [ ] Plugin system for custom types
- [ ] Shell completion generation
- [ ] Configuration file parsing
- [ ] Performance optimizations

---

*Last updated: After major architecture refactoring to idiomatic Zig patterns with arena-based memory management, simplified API, and expanded test coverage (89/89 tests passing)*