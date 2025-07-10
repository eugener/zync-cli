# Zync-CLI Examples

This directory contains examples demonstrating different features and usage patterns of the Zync-CLI library.

## Available Examples

### `simple.zig` - Basic Usage
A minimal example showing the core functionality:
- Boolean flags (`--verbose`)
- Optional arguments with defaults (`--name`, `--count`)
- Clean, readable code structure

```bash
zig build run-simple -- --verbose --name Alice --count 3
```

### `basic.zig` - Complete Example  
A comprehensive example demonstrating:
- Custom title and description with ASCII banner
- Environment variable support
- All argument types (flags, options, required, positional)
- Professional help output

```bash
zig build run-basic -- --help
zig build run-basic -- --verbose --config /tmp/test.conf README.md
```

### `environment.zig` - Environment Variables
Focused demonstration of environment variable integration:
- Environment variable support for all argument types
- Standard priority chain (CLI → env vars → defaults)
- Required field satisfaction via environment variables

```bash
# Set environment variables
APP_DEBUG=true APP_HOST=api.example.com APP_API_KEY=secret zig build run-environment

# Mix CLI args and environment variables  
APP_PORT=3000 zig build run-environment -- --api-key mykey --debug
```

## Building Examples

```bash
# Build all examples
zig build

# Run specific examples
zig build run-simple
zig build run-basic
zig build run-environment

# Install examples to zig-out/examples/
zig build install-simple
zig build install-basic
zig build install-environment
```

## Using Examples as Templates

These examples are designed to be used as starting points for your own CLI applications:

1. Copy the example that best matches your needs
2. Modify the argument definitions in the `Args` structure
3. Update the help text and program logic
4. Add your application-specific functionality

## Example Patterns

### Basic Pattern (simple.zig)
```zig
const Args = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
    cli.option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
});
```

### Environment Variable Pattern (environment.zig)
```zig
const Args = cli.Args(&.{
    cli.flag("debug", .{ .short = 'd', .help = "Enable debug mode", .env_var = "APP_DEBUG" }),
    cli.option("host", []const u8, .{ .default = "localhost", .help = "Server host", .env_var = "APP_HOST" }),
    cli.required("api_key", []const u8, .{ .help = "API key", .env_var = "APP_API_KEY" }),
});
```

### Custom Title Pattern (basic.zig)
```zig
const Args = cli.Args(.{
    &.{
        cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        // ... other arguments
    },
    .{
        .title = "MyApp - Professional CLI Tool",
        .description = "A powerful command-line application with advanced features.",
    },
});
```