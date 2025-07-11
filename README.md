# Zync-CLI

[![Build Status](https://img.shields.io/badge/build-passing-brightgreen)](#testing)
[![Tests](https://img.shields.io/badge/tests-175%2F175%20passing-brightgreen)](#testing)
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
- **Handler Execution** - Direct command execution with automatic handler function support
- **Battle Tested** - 175 comprehensive tests covering all functionality
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

## Hierarchical Subcommand System

Zync-CLI v0.5.0 introduces a powerful subcommand system for building Git-style and Docker-style CLI tools with organized command hierarchies:

### Basic Subcommand Usage

```zig
const std = @import("std");
const cli = @import("zync-cli");

// Define Args for different commands
const ServeArgs = cli.Args(&.{
    cli.flag("daemon", .{ .short = 'd', .help = "Run as daemon", .env_var = "SERVER_DAEMON" }),
    cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on", .env_var = "SERVER_PORT" }),
});

const BuildArgs = cli.Args(&.{
    cli.flag("release", .{ .short = 'r', .help = "Build in release mode", .env_var = "BUILD_RELEASE" }),
    cli.option("target", []const u8, .{ .short = 't', .default = "native", .help = "Target platform", .env_var = "BUILD_TARGET" }),
});

// Create the command hierarchy
const AppCommands = cli.Commands(&.{
    cli.command("serve", ServeArgs, .{ .help = "Start the application server" }),
    cli.command("build", BuildArgs, .{ .help = "Build the application" }),
    cli.command("test", TestArgs, .{ .help = "Run the test suite" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // Single call handles all routing and parsing automatically
    try AppCommands.parse(arena.allocator());
}
```

### Multilevel Command Organization

Zync-CLI supports complex CLI patterns through descriptive command naming that simulates hierarchical structure:

```zig
// Current approach: Flat structure with descriptive naming
const AppCommands = cli.Commands(&.{
    // Database operations (simulating "db migrate up", "db migrate down", etc.)
    cli.command("db-migrate-up", DbMigrateUpArgs, .{ .help = "Run database migrations (up)" }),
    cli.command("db-migrate-down", DbMigrateDownArgs, .{ .help = "Rollback database migrations (down)" }),
    cli.command("db-seed", DbSeedArgs, .{ .help = "Seed database with data" }),
    cli.command("db-status", DbStatusArgs, .{ .help = "Show database status" }),
    
    // Git-style operations (simulating "git remote add", "git branch create", etc.)
    cli.command("git-remote-add", GitRemoteAddArgs, .{ .help = "Add a git remote" }),
    cli.command("git-remote-remove", GitRemoteRemoveArgs, .{ .help = "Remove a git remote" }),
    cli.command("git-branch-create", GitBranchCreateArgs, .{ .help = "Create a new git branch" }),
    cli.command("git-commit", GitCommitArgs, .{ .help = "Create a git commit" }),
    
    // Docker-style operations (simulating "docker container run", "docker image pull", etc.)
    cli.command("docker-run", DockerRunArgs, .{ .help = "Run a docker container" }),
    cli.command("docker-ps", DockerPsArgs, .{ .help = "List docker containers" }),
    cli.command("docker-images", DockerImagesArgs, .{ .help = "List docker images" }),
    cli.command("docker-pull", DockerPullArgs, .{ .help = "Pull docker images" }),
});
```

**Usage Examples:**
```bash
# Database operations
./myapp db-migrate-up --steps 5 --dry-run
./myapp db-seed --file production.sql --force
./myapp db-status --verbose --json

# Git-style operations  
./myapp git-remote-add --name origin --url https://github.com/user/repo.git --fetch
./myapp git-branch-create --name feature/auth --from develop
./myapp git-commit --message "Add user authentication" --all

# Docker-style operations
./myapp docker-run --image nginx --detach --name webserver --port 80:8080
./myapp docker-ps --all --quiet
./myapp docker-pull --image ubuntu:latest --all-tags
```

### Subcommand Features

- **Unified `command()` Function** - Single function for defining all commands
- **Descriptive Naming** - Use hyphens to create logical command groupings
- **Automatic Type Detection** - Distinguishes Args types at compile time
- **Colorized Help Output** - Beautiful, aligned command listings with smart color detection
- **Environment Variable Support** - Full integration with priority chain for all subcommands
- **Hidden Commands** - Support for internal commands that don't appear in help text
- **Zero Boilerplate** - Single `Commands.parse()` call handles everything

### Subcommand Help Output

```bash
$ ./myapp --help
myapp - Subcommand Interface

Usage: myapp <command> [options]

Available Commands:
  serve    Start the application server
  build    Build the application
  test     Run the test suite

Use 'myapp <command> --help' for more information about a specific command.

$ ./myapp serve --help
myapp - TODO: Add custom title using .title in Args config
TODO: Add description using .description in Args config

Usage: myapp serve [OPTIONS]

Options:
  -d, --daemon          Run as daemon [env: SERVER_DAEMON]
  -p, --port [value]    Port to listen on [env: SERVER_PORT] (default: 8080)
  -h, --help            Show this help message
```

### Command Organization Patterns

Zync-CLI enables professional CLI organization through strategic command naming:

#### Git-Style Pattern
```zig
// Organizes commands by resource and action
cli.command("remote-add", RemoteAddArgs, .{ .help = "Add a remote repository" }),
cli.command("remote-remove", RemoteRemoveArgs, .{ .help = "Remove a remote repository" }),
cli.command("remote-list", RemoteListArgs, .{ .help = "List remote repositories" }),
cli.command("branch-create", BranchCreateArgs, .{ .help = "Create a new branch" }),
cli.command("branch-delete", BranchDeleteArgs, .{ .help = "Delete a branch" }),
```

#### Docker-Style Pattern
```zig
// Organizes commands by component and operation
cli.command("container-run", ContainerRunArgs, .{ .help = "Run a new container" }),
cli.command("container-stop", ContainerStopArgs, .{ .help = "Stop running containers" }),
cli.command("container-list", ContainerListArgs, .{ .help = "List containers" }),
cli.command("image-pull", ImagePullArgs, .{ .help = "Pull an image" }),
cli.command("image-build", ImageBuildArgs, .{ .help = "Build an image" }),
```

#### Database-Style Pattern
```zig
// Organizes commands by subsystem and action
cli.command("db-migrate-up", DbMigrateUpArgs, .{ .help = "Apply database migrations" }),
cli.command("db-migrate-down", DbMigrateDownArgs, .{ .help = "Rollback database migrations" }),
cli.command("db-seed", DbSeedArgs, .{ .help = "Seed database with initial data" }),
cli.command("db-backup", DbBackupArgs, .{ .help = "Create database backup" }),
```

#### Best Practices

1. **Consistent Naming** - Use the same pattern throughout your application
2. **Logical Grouping** - Group related commands with prefixes (`db-`, `git-`, `docker-`)
3. **Clear Actions** - Use descriptive action words (`create`, `list`, `remove`, `up`, `down`)
4. **Avoid Deep Nesting** - Keep command names readable and not too long
5. **Environment Variables** - Use consistent env var naming (`MYAPP_DB_HOST`, `MYAPP_GIT_TOKEN`)

### Advanced Features

- **Environment Variables** - Each subcommand supports environment variable integration
- **Hidden Commands** - Use `.hidden = true` for internal commands
- **Compile-Time Safety** - All command definitions validated at compile time
- **Memory Safe** - Arena-based allocation with automatic cleanup
- **Backward Compatible** - Existing `Args()` API continues to work unchanged

### True Nested Subcommands (Available Now!)

Zync-CLI now supports true nested subcommand hierarchies with unlimited depth:

```zig
// True nested subcommands - working now!
const DatabaseCommands = cli.Commands(&.{
    cli.command("migrate", MigrateCommands, .{ .help = "Database migration operations" }),
    cli.command("seed", SeedArgs, .{ .help = "Seed database with data" }),
});

const MigrateCommands = cli.Commands(&.{
    cli.command("up", MigrateUpArgs, .{ .help = "Apply migrations" }),
    cli.command("down", MigrateDownArgs, .{ .help = "Rollback migrations" }),
});

const AppCommands = cli.Commands(&.{
    cli.command("db", DatabaseCommands, .{ .help = "Database operations" }),
    cli.command("git", GitCommands, .{ .help = "Git operations" }),
    cli.command("docker", DockerCommands, .{ .help = "Docker operations" }),
});

// Usage examples:
// myapp db migrate up --steps 5 --dry-run
// myapp git remote add --name origin --url https://github.com/user/repo.git
// myapp docker container run --image nginx --detach
```

**Key Features:**
- **Unlimited Depth** - Create hierarchies as deep as you need (db migrate up, git remote add, etc.)
- **Type Safety** - All nested command structures validated at compile time
- **Automatic Routing** - Commands automatically delegate to the appropriate subcommand handler
- **Contextual Help** - Help messages show the correct command path and usage at every level
- **Perfect Help Generation** - Usage lines show full command paths (e.g., `myapp git remote <command>`)
- **Zero Boilerplate** - Simple recursive structure with automatic parsing

**Help Examples:**
```bash
$ myapp git --help
myapp git - Subcommand Interface

Usage: myapp git <command> [options]

Available Commands:
  remote  Manage remote repositories
  branch  Manage git branches

$ myapp git remote --help  
myapp git remote - Subcommand Interface

Usage: myapp git remote <command> [options]

Available Commands:
  add     Add a new remote
  remove  Remove a remote

$ myapp git remote add --help
myapp git remote add - Configuration

Usage: myapp git remote add [OPTIONS]

Options:
  --name <value>    Remote name (required)
  --url <value>     Remote URL (required)  
  -f, --fetch       Fetch after adding remote
```

## Command Handler System

Zync-CLI v0.6.0 introduces a powerful command handler system that enables automatic execution of business logic after argument parsing:

### Handler Functions

Add handler functions directly to command configurations for automatic execution:

```zig
const std = @import("std");
const cli = @import("zync-cli");

// Define handler functions
fn serveHandler(args: ServeArgs.ArgsType, allocator: std.mem.Allocator) !void {
    std.debug.print("🚀 Starting server on port {d}...\n", .{args.port});
    
    if (args.daemon) {
        std.debug.print("   Running as daemon\n", .{});
    }
    
    // Your server logic here
    std.debug.print("✅ Server started successfully!\n", .{});
}

fn buildHandler(args: BuildArgs.ArgsType, allocator: std.mem.Allocator) !void {
    std.debug.print("🔨 Building project...\n", .{});
    
    if (args.release) {
        std.debug.print("   Release mode enabled\n", .{});
    }
    
    // Your build logic here
    std.debug.print("✅ Build completed!\n", .{});
}

// Define argument structures
const ServeArgs = cli.Args(&.{
    cli.flag("daemon", .{ .short = 'd', .help = "Run as daemon" }),
    cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on" }),
});

const BuildArgs = cli.Args(&.{
    cli.flag("release", .{ .short = 'r', .help = "Build in release mode" }),
    cli.option("target", []const u8, .{ .short = 't', .default = "native", .help = "Target platform" }),
});

// Create commands with handlers
const AppCommands = cli.Commands(&.{
    cli.command("serve", ServeArgs, .{ .help = "Start the server", .handler = serveHandler }),
    cli.command("build", BuildArgs, .{ .help = "Build the application", .handler = buildHandler }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // Commands automatically execute their handlers after parsing
    try AppCommands.parse(arena.allocator());
}
```

### Handler Features

- **Automatic Execution** - Handlers run automatically after successful argument parsing
- **Type Safety** - Handlers receive properly typed parsed arguments
- **Memory Management** - Allocator provided for handler memory needs
- **Error Handling** - Handler errors propagate naturally through the call stack
- **Zero Boilerplate** - Simple function assignment: `.handler = myFunction`
- **Nested Support** - Works seamlessly with nested subcommand hierarchies

### Usage Examples

```bash
# Handlers execute automatically after parsing
$ ./myapp serve --daemon --port 3000
🚀 Starting server on port 3000...
   Running as daemon
✅ Server started successfully!

$ ./myapp build --release --target x86_64-linux
🔨 Building project...
   Release mode enabled
✅ Build completed!

# Help still works normally
$ ./myapp serve --help
myapp serve - Start the server

Usage: myapp serve [OPTIONS]

Options:
  -d, --daemon          Run as daemon
  -p, --port [value]    Port to listen on (default: 8080)
  -h, --help            Show this help message
```

### Handler Function Signature

Handler functions must follow this signature:

```zig
fn handlerName(args: ArgsType.ArgsType, allocator: std.mem.Allocator) !void
```

Where:
- `args` contains the parsed command-line arguments
- `allocator` provides memory allocation for handler operations
- Return type can be `!void` for error-returning handlers or `void` for simple handlers

### Nested Command Handlers

Handlers work seamlessly with nested subcommand hierarchies:

```zig
const DbMigrateCommands = cli.Commands(&.{
    cli.command("up", DbMigrateUpArgs, .{ .help = "Apply migrations", .handler = migrateUpHandler }),
    cli.command("down", DbMigrateDownArgs, .{ .help = "Rollback migrations", .handler = migrateDownHandler }),
});

const DatabaseCommands = cli.Commands(&.{
    cli.command("migrate", DbMigrateCommands, .{ .help = "Migration operations" }),
    cli.command("seed", DbSeedArgs, .{ .help = "Seed database", .handler = seedHandler }),
});

// Usage: ./myapp db migrate up --steps 5
// Automatically executes migrateUpHandler with parsed arguments
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

### Subcommand API

#### `Commands(command_definitions)`
Create a hierarchical command structure with automatic depth validation.

```zig
const AppCommands = cli.Commands(&.{
    cli.command("serve", ServeArgs, .{ .help = "Start the server" }),
    cli.command("build", BuildArgs, .{ .help = "Build the project" }),
});
```

#### `command(name, args_or_subcommands, config)`
Create a unified command definition that automatically detects leaf vs category commands.

```zig
// Leaf command (with Args)
cli.command("serve", ServeArgs, .{ .help = "Start the server" })

// Leaf command with handler
cli.command("serve", ServeArgs, .{ .help = "Start the server", .handler = serveHandler })

// Category command (with subcommands)
cli.command("db", DatabaseCommands, .{ .help = "Database operations" })
```

#### `CommandConfig`
Configuration for command definitions.

```zig
.{
    .help = "Command description",
    .title = "Custom command title",
    .description = "Detailed command description",
    .hidden = false, // Set to true for internal commands
    .handler = myHandler, // Optional handler function for automatic execution
}
```

#### `Commands.parse(allocator)`
Parse and route to the appropriate subcommand automatically.

```zig
// Handles all routing, parsing, and help generation
try AppCommands.parse(arena.allocator());
```

#### `Commands.parseFrom(allocator, args)`
Parse from custom argument array with subcommand routing.

```zig
const test_args = &.{"serve", "--daemon", "--port", "3000"};
try AppCommands.parseFrom(arena.allocator(), test_args);
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

Zync-CLI automatically handles both help requests and parsing errors with no boilerplate required:

```zig
// Everything is handled automatically - no boilerplate needed!
const args = try Args.parse(arena.allocator());
```

**Automatic Error Handling:**
- **Clean error messages** - No stack traces or verbose output shown to users
- **Helpful suggestions** - Contextual hints for fixing issues  
- **Silent exit** - Process exits quietly (code 0) after displaying errors
- **No build noise** - Clean output even when used via build systems
- **Test-friendly** - Errors are re-thrown in test mode for proper testing

**Examples of clean error output:**
```bash
$ ./myapp
Error: Missing required argument ('config')

Suggestion: The --config flag is required

$ ./myapp --invalid-flag  
Error: Unknown flag ('invalid-flag')

Suggestion: Use --help to see available options
```

For advanced use cases where you need control over error handling, use `parseFromRaw`:

```zig
const args = Args.parseFromRaw(arena.allocator(), custom_args) catch |err| switch (err) {
    error.HelpRequested => {
        // Handle help manually if needed
        return;
    },
    error.MissingRequiredArgument => {
        // Handle missing required args manually
        return;
    },
    else => return err,
};
```

**Key Features:**
- **Automatic help processing** - Help flags processed before validation
- **Silent error handling** - Clean exit with no verbose output or build noise
- **Pre-validation help** - Help works even when required fields are missing
- **Standard conventions** - Supports both `--help` and `-h` flags
- **Environment variable support** - Integrates seamlessly with standard priority chain
- **Test compatibility** - Preserves error propagation in test environments

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

- **175 total tests** across all modules
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
- **Hierarchical subcommand system** with type detection and depth validation
- **Handler execution system** with automatic function calling and type safety
- **Subcommand help generation** with colorized output and alignment
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
│   ├── types.zig       # Core type definitions with ParseError and Location
│   ├── parser.zig      # Argument parsing engine with detailed errors
│   ├── meta.zig        # Compile-time metadata extraction
│   ├── cli.zig         # Function-based DSL and subcommand system with handlers
│   ├── help.zig        # Help text generation
│   ├── colors.zig      # Unified color API with smart detection and test-aware output
│   ├── testing.zig     # Testing utilities
│   ├── test_utils.zig  # Test mode handling utilities
│   ├── field_utils.zig # Struct field operation utilities
│   └── error_utils.zig # Unified error creation utilities
├── examples/
│   ├── simple.zig      # Minimal usage example
│   ├── basic.zig       # Complete example with custom banner
│   ├── environment.zig # Environment variable demonstration
│   └── commands.zig    # Comprehensive command system with handlers and nested subcommands
├── build.zig           # Build configuration
├── README.md           # This file
├── CLAUDE.md           # Project documentation
└── spec.md             # Library specification
```

## Development

### Building

```bash
# Build library only
zig build

# Run examples (use -- to separate build args from app args)
zig build run-simple -- --verbose --name Developer --count 2
zig build run-basic -- --help
zig build run-environment -- --debug --api-key secret
zig build run-commands -- --help
zig build run-commands -- serve --daemon --port 3000
zig build run-commands -- db migrate up --steps 5 --dry-run

# Install library
zig build install

# Install examples to zig-out/examples/
zig build install-simple
zig build install-basic
zig build install-environment
zig build install-commands

# Run installed executables directly (cleanest output)
./zig-out/examples/environment --help
./zig-out/examples/simple --verbose --count 3
./zig-out/examples/commands --help
./zig-out/examples/commands serve --daemon --port 3000
./zig-out/examples/commands db migrate up --steps 5
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

### Completed (v0.5.0)
- [x] **Hierarchical subcommand system** - Unified `command()` function for Git-style CLI tools
- [x] **Automatic type detection** - Distinguishes leaf commands from categories at compile time
- [x] **True nested subcommands** - Recursive command hierarchies with unlimited depth
- [x] **Perfect help generation** - Contextual help showing full command paths at every level
- [x] **Command path tracking** - Usage lines show correct nested command paths
- [x] **Colorized subcommand help** - Beautiful, aligned help output with smart color detection
- [x] **Zero boilerplate** - Single `Commands.parse()` call handles all routing and parsing

### Completed (v0.6.0)
- [x] **Handler execution system** - Direct command execution with automatic function calling
- [x] **Automatic type conversion** - Functions converted to handlers with zero boilerplate
- [x] **Type-safe handler functions** - Handlers receive properly typed arguments and allocator
- [x] **Error propagation** - Handler errors flow naturally through the call stack
- [x] **Nested handler support** - Handlers work seamlessly with subcommand hierarchies
- [x] **Code quality improvements** - Comprehensive redundancy elimination and utility modules
- [x] **Test reliability** - ANSI-aware testing with 175/175 tests passing consistently

### Planned (v0.7.0)
- [ ] Configuration file parsing (TOML/JSON integration)
- [ ] Multiple value support with array types (`*` encoding)
- [ ] Advanced field validation with custom validators

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