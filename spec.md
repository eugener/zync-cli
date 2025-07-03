# Zync-CLI: Complete CLI Library Specification

## 1. Core Design Philosophy

### 1.1 Zig-First Design
- **Compile-time everything**: All parsing logic resolved at compile time
- **Zero runtime overhead**: Generated code as efficient as hand-written parsing
- **Type-safe by design**: Impossible to access non-existent arguments
- **Memory conscious**: Zero heap allocations for parsing infrastructure
- **Leverage Zig's unique features**: Comptime, reflection, flexible field names

### 1.2 Progressive API Complexity
```zig
// Level 1: Simple struct (minimal ceremony)
const Args = struct { verbose: bool = false };

// Level 2: Struct + metadata (most common)
const Args = struct {
    verbose: bool = false,
    pub const cli = .{ .fields = .{ .verbose = .{ .short = 'v' } } };
};

// Level 3: Encoded field names (maximum ergonomics)
const Args = struct {
    @"verbose|v": bool = false,
    @"config|c!": []const u8,
    @"output|o=./out": []const u8,
};

// Level 4: Tagged unions (complex subcommands)
const Command = union(enum) {
    build: BuildArgs,
    test: TestArgs,
};
```

## 2. Field Name Encoding DSL

### 2.1 Encoding Syntax
```zig
const Args = struct {
    // Basic flag
    @"verbose": bool = false,

    // Short flag: |char
    @"verbose|v": bool = false,

    // Required: !
    @"config|c!": []const u8,

    // Default value: =value
    @"output|o=./out": []const u8,
    @"port|p=8080": u16,

    // Positional: #name
    @"#input": []const u8,
    @"#files": []const []const u8,

    // Multiple values: *
    @"include|I*": []const []const u8,

    // Counting: +
    @"verbose|v+": u8,

    // Environment variable: $VAR
    @"token|t$API_TOKEN": ?[]const u8,

    // Hidden from help: ~
    @"debug|d~": bool = false,

    // Combinations
    @"config|c!$CONFIG_FILE": []const u8,        // Required + env var
    @"output|o=./out$OUTPUT_DIR": []const u8,    // Default + env var
    @"verbose|v+~": u8,                          // Counting + hidden
};
```

### 2.2 Complex Field Encodings
```zig
const Args = struct {
    // Validation: @validator
    @"port|p=8080@range(1024,65535)": u16,
    @"email|e@email": []const u8,
    @"file|f@exists": []const u8,

    // Choices: %choice1,choice2
    @"format|f%json,yaml,toml": enum { json, yaml, toml },

    // Aliases: &alias1,alias2
    @"verbose|v&debug,trace": bool = false,

    // Help text: "description"
    @"config|c!\"Configuration file path\"": []const u8,

    // Complex combination
    @"output|o=./out$OUTPUT_DIR\"Output directory\"": []const u8,
};
```

## 3. Metadata Configuration

### 3.1 Application Metadata
```zig
const Args = struct {
    // ... fields ...

    pub const cli = .{
        .name = "myapp",
        .version = "1.0.0",
        .description = "My awesome CLI application",
        .author = "Your Name <you@example.com>",
        .license = "MIT",
        .about = "A longer description of what this app does...",
        .usage = "myapp [OPTIONS] <INPUT> [FILES]...",
        .examples = &.{
            .{ .desc = "Basic usage", .cmd = "myapp input.txt" },
            .{ .desc = "With options", .cmd = "myapp -v --config app.toml input.txt" },
        },
    };
};
```

### 3.2 Field-Level Metadata
```zig
const Args = struct {
    verbose: bool = false,
    config: ?[]const u8 = null,

    pub const cli = .{
        .fields = .{
            .verbose = .{
                .short = 'v',
                .help = "Enable verbose output",
                .long_help = "Enable verbose output with detailed logging information",
                .env = "VERBOSE",
                .hidden = false,
                .count = true,
            },
            .config = .{
                .short = 'c',
                .help = "Configuration file path",
                .required = true,
                .validator = .file_exists,
                .env = "CONFIG_FILE",
                .placeholder = "FILE",
            },
        },
    };
};
```

## 4. Subcommand System

### 4.1 Tagged Union Subcommands
```zig
const Command = union(enum) {
    build: BuildCommand,
    test: TestCommand,
    deploy: DeployCommand,

    pub const cli = .{
        .name = "myapp",
        .version = "1.0.0",
        .description = "Multi-command CLI application",
        .commands = .{
            .build = .{ .about = "Build the project" },
            .test = .{ .about = "Run tests", .aliases = &.{"t"} },
            .deploy = .{ .about = "Deploy to production", .hidden = true },
        },
    };
};

const BuildCommand = struct {
    @"release|r": bool = false,
    @"target|t%debug,release": enum { debug, release } = .debug,
    @"jobs|j=0": u32,

    pub const cli = .{
        .about = "Build the project with specified options",
        .examples = &.{
            .{ .desc = "Debug build", .cmd = "myapp build" },
            .{ .desc = "Release build", .cmd = "myapp build --release" },
        },
    };
};
```

### 4.2 Nested Subcommands
```zig
const Command = union(enum) {
    git: GitCommand,
    docker: DockerCommand,
};

const GitCommand = union(enum) {
    clone: struct {
        @"#url": []const u8,
        @"#directory": ?[]const u8 = null,
        @"bare": bool = false,
    },
    remote: RemoteCommand,

    pub const cli = .{
        .about = "Git-like version control commands",
    };
};

const RemoteCommand = union(enum) {
    add: struct {
        @"#name": []const u8,
        @"#url": []const u8,
    },
    remove: struct {
        @"#name": []const u8,
    },
    list: struct {
        @"verbose|v": bool = false,
    },
};
```

## 5. Advanced Type System Integration

### 5.1 Custom Type Parsing
```zig
const Args = struct {
    // Custom types with Parse trait
    endpoint: Endpoint,
    duration: Duration,

    // Generic containers
    headers: std.StringHashMap([]const u8),

    // Optional and nullable types
    maybe_file: ?[]const u8 = null,

    pub const cli = .{
        .fields = .{
            .endpoint = .{ .help = "API endpoint URL" },
            .duration = .{ .help = "Timeout duration (e.g., 30s, 5m, 1h)" },
            .headers = .{ .help = "HTTP headers (key=value)", .multiple = true },
        },
    };
};

// Custom type implementation
const Endpoint = struct {
    scheme: []const u8,
    host: []const u8,
    port: u16,
    path: []const u8,

    pub fn parse(allocator: std.mem.Allocator, input: []const u8) !Endpoint {
        // Custom parsing logic
        return parseUrl(input);
    }

    pub fn deinit(self: *Endpoint, allocator: std.mem.Allocator) void {
        // Cleanup if needed
    }
};
```

### 5.2 Validation System
```zig
const Args = struct {
    @"port|p=8080": u16,
    @"email|e": []const u8,
    @"file|f": []const u8,

    pub const cli = .{
        .fields = .{
            .port = .{ .validator = .{ .range = .{ .min = 1024, .max = 65535 } } },
            .email = .{ .validator = .email },
            .file = .{ .validator = .{ .all_of = &.{ .file_exists, .readable } } },
        },
        .cross_validation = &.{
            .{ .mutually_exclusive = &.{ "json", "yaml" } },
            .{ .required_together = &.{ "username", "password" } },
            .{ .conditional = .{ .if_present = "ssl", .then_required = &.{"cert", "key"} } },
        },
    };
};

// Built-in validators
const Validators = struct {
    pub const range = struct {
        min: anytype,
        max: anytype,
    };

    pub const email = struct {};
    pub const url = struct {};
    pub const file_exists = struct {};
    pub const dir_exists = struct {};
    pub const readable = struct {};
    pub const writable = struct {};
    pub const executable = struct {};

    pub const all_of = []const Validator;
    pub const any_of = []const Validator;
    pub const not = Validator;

    pub const custom = fn (value: anytype) ValidationResult;
};
```

## 6. Configuration Integration

### 6.1 Configuration Sources
```zig
const Args = struct {
    @"config|c$CONFIG_FILE": ?[]const u8 = null,
    @"verbose|v$VERBOSE": bool = false,
    @"port|p$PORT": u16 = 8080,

    pub const cli = .{
        .config = .{
            .sources = &.{
                .{ .env_prefix = "MYAPP_" },
                .{ .config_file = .{
                    .formats = &.{ .json, .yaml, .toml },
                    .locations = &.{
                        "/etc/myapp/config.toml",
                        "~/.config/myapp/config.toml",
                        "./config.toml",
                    },
                }},
            },
            .precedence = .{ .cli, .env, .config_file, .default },
        },
    };
};
```

### 6.2 Configuration File Format
```toml
# config.toml
[global]
verbose = true
port = 9000

[build]
release = true
target = "release"

[deploy]
environment = "staging"
```

## 7. Help System

### 7.1 Automatic Help Generation
```zig
const Args = struct {
    @"verbose|v+\"Enable verbose output (use multiple times for more verbosity)\"": u8,
    @"config|c$CONFIG_FILE\"Configuration file path\"": ?[]const u8 = null,

    pub const cli = .{
        .name = "myapp",
        .version = "1.0.0",
        .description = "A comprehensive CLI application",
        .help = .{
            .width = 80,
            .colors = .auto,
            .template = .default,
            .sections = &.{
                .usage,
                .description,
                .arguments,
                .options,
                .examples,
                .environment,
                .footer,
            },
        },
    };
};
```

### 7.2 Custom Help Templates
```zig
const Args = struct {
    // ... fields ...

    pub const cli = .{
        .help = .{
            .template =
                \\{name} {version}
                \\{description}
                \\
                \\USAGE:
                \\    {usage}
                \\
                \\ARGUMENTS:
                \\{arguments}
                \\
                \\OPTIONS:
                \\{options}
                \\
                \\EXAMPLES:
                \\{examples}
                \\
                \\For more information, visit: https://example.com
            ,
            .colors = .{
                .header = .bold_blue,
                .usage = .green,
                .option = .yellow,
                .description = .white,
            },
        },
    };
};
```

## 8. Shell Integration

### 8.1 Completion Generation
```zig
const Args = struct {
    @"file|f": []const u8,
    @"format|F%json,yaml,toml": Format,

    pub const cli = .{
        .completion = .{
            .shells = &.{ .bash, .zsh, .fish, .powershell },
            .fields = .{
                .file = .{ .complete = .files },
                .format = .{ .complete = .choices },
            },
            .dynamic = .{
                .file = completePaths,
                .custom = completeCustom,
            },
        },
    };
};

fn completePaths(allocator: std.mem.Allocator, partial: []const u8) ![]const []const u8 {
    // Custom completion logic
    return &.{ "file1.txt", "file2.txt" };
}
```

### 8.2 Man Page Generation
```zig
const Args = struct {
    // ... fields ...

    pub const cli = .{
        .man = .{
            .section = 1,
            .author = "Your Name <you@example.com>",
            .date = "2024-01-01",
            .see_also = &.{"git(1)", "docker(1)"},
            .bugs = "Report bugs at https://github.com/user/repo/issues",
        },
    };
};
```

## 9. Error Handling and Diagnostics

### 9.1 Rich Error Messages
```zig
const ErrorConfig = struct {
    colors: bool = true,
    suggestions: bool = true,
    context: bool = true,
    max_suggestions: u8 = 3,

    pub const templates = .{
        .unknown_flag = "Unknown flag '{flag}'. {suggestions}",
        .missing_value = "Flag '{flag}' requires a value",
        .invalid_value = "Invalid value '{value}' for '{flag}': {reason}",
        .missing_required = "Missing required argument: {arg}",
        .mutually_exclusive = "Cannot use {arg1} and {arg2} together",
    };
};
```

### 9.2 Diagnostic Information
```zig
const ParseResult = struct {
    args: Args,
    diagnostics: []const Diagnostic,

    pub const Diagnostic = struct {
        level: Level,
        message: []const u8,
        suggestion: ?[]const u8 = null,
        location: ?Location = null,

        pub const Level = enum { error, warning, info, hint };
        pub const Location = struct { arg_index: usize, char_index: usize };
    };
};
```

## 10. Testing and Debugging

### 10.1 Test Utilities
```zig
const testing = @import("zync-cli/testing.zig");

test "basic argument parsing" {
    const Args = struct {
        @"verbose|v": bool = false,
        @"#input": []const u8,
    };

    const result = try testing.parse(Args, &.{ "myapp", "-v", "input.txt" });
    try testing.expect(result.verbose == true);
    try testing.expectEqualStrings(result.input, "input.txt");
}

test "error handling" {
    const Args = struct {
        @"required|r!": []const u8,
    };

    const result = testing.parse(Args, &.{"myapp"});
    try testing.expectError(error.MissingRequiredArgument, result);
}
```

### 10.2 Debug Features
```zig
const Args = struct {
    @"verbose|v": bool = false,

    pub const cli = .{
        .debug = .{
            .trace_parsing = true,
            .dump_config = true,
            .show_memory_usage = true,
        },
    };
};
```

## 11. Performance Optimizations

### 11.1 Compile-Time Optimizations
```zig
const Args = struct {
    // ... fields ...

    pub const cli = .{
        .optimize = .{
            // Pre-compute lookup tables
            .use_lookup_tables = true,
            // Aggressive inlining
            .inline_small_functions = true,
            // Generate specialized parsers
            .specialize_parsers = true,
            // Optimize for size vs speed
            .optimize_for = .speed,
        },
    };
};
```

### 11.2 Memory Management
```zig
const Args = struct {
    // ... fields ...

    pub const cli = .{
        .memory = .{
            // Stack allocation size
            .stack_size = 4096,
            // Use arena allocator for temporary allocations
            .arena_allocator = true,
            // String interning
            .intern_strings = true,
        },
    };
};
```

## 12. Platform-Specific Features

### 12.1 Cross-Platform Support
```zig
const Args = struct {
    @"config|c": ?[]const u8 = null,

    pub const cli = .{
        .platform = .{
            .windows = .{
                .style = .windows, // Support /flag style
                .registry = true,
            },
            .unix = .{
                .xdg_config = true,
                .posix_signals = true,
            },
            .macos = .{
                .app_support = true,
            },
        },
    };
};
```

## 13. Security Features

### 13.1 Input Sanitization
```zig
const Args = struct {
    @"file|f": []const u8,

    pub const cli = .{
        .security = .{
            .sanitize_paths = true,
            .prevent_traversal = true,
            .max_arg_length = 4096,
            .validate_urls = true,
        },
    };
};
```

## 14. Usage Examples

### 14.1 Simple CLI
```zig
const Args = struct {
    @"verbose|v": bool = false,
    @"#input": []const u8,
};

pub fn main() !void {
    const args = try cli.parse(Args, std.heap.page_allocator);
    defer args.deinit();

    if (args.verbose) {
        std.log.info("Processing file: {s}", .{args.input});
    }
}
```

### 14.2 Complex Multi-Command CLI
```zig
const Command = union(enum) {
    build: struct {
        @"release|r": bool = false,
        @"target|t%debug,release": enum { debug, release } = .debug,
    },
    test: struct {
        @"coverage": bool = false,
        @"filter|f": ?[]const u8 = null,
    },

    pub const cli = .{
        .name = "myapp",
        .version = "1.0.0",
        .description = "A comprehensive build tool",
    };
};

pub fn main() !void {
    const cmd = try cli.parse(Command, std.heap.page_allocator);
    defer cmd.deinit();

    switch (cmd) {
        .build => |build_args| {
            std.log.info("Building in {} mode", .{build_args.target});
        },
        .test => |test_args| {
            if (test_args.coverage) {
                std.log.info("Running tests with coverage");
            }
        },
    }
}
```

## 15. API Reference

### 15.1 Core Functions
```zig
pub const cli = struct {
    /// Parse command-line arguments into the specified type
    pub fn parse(comptime T: type, allocator: std.mem.Allocator) !ParseResult(T);

    /// Parse from custom argument array
    pub fn parseFrom(comptime T: type, allocator: std.mem.Allocator, args: []const []const u8) !ParseResult(T);

    /// Generate help text
    pub fn help(comptime T: type) []const u8;

    /// Generate completion script
    pub fn completion(comptime T: type, shell: Shell) []const u8;

    /// Generate man page
    pub fn manPage(comptime T: type) []const u8;

    /// Validate arguments at compile time
    pub fn validate(comptime T: type) void;
};
```

### 15.2 Result Types
```zig
pub fn ParseResult(comptime T: type) type {
    return struct {
        args: T,
        diagnostics: []const Diagnostic,

        pub fn deinit(self: *@This()) void;
    };
}
```

This specification provides a complete, feature-rich CLI library that leverages Zig's unique strengths while providing an ergonomic and powerful API for building command-line applications of any complexity.
