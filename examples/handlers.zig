//! Handler Example - Command execution with handler functions
//!
//! This example demonstrates how to use handler functions with zync-cli
//! commands to execute specific logic for each command. Handlers are specified
//! directly in the command configuration with automatic type conversion:
//! 
//! Syntax: cli.command("name", Args, .{ .help = "...", .handler = myFunction })
//!
//! Examples:
//! - handlers serve --port 3000 --daemon
//! - handlers build --release --target x86_64-linux
//! - handlers db migrate up --steps 5
//! - handlers db seed --file production.sql --force

const std = @import("std");
const cli = @import("zync-cli");

// === Command Handler Functions ===

fn serveHandler(args: ServeArgs.ArgsType, allocator: std.mem.Allocator) !void {
    _ = allocator; // Not used in this example

    std.debug.print("🚀 Starting server...\n", .{});
    std.debug.print("   Host: {s}\n", .{args.host});
    std.debug.print("   Port: {d}\n", .{args.port});

    if (args.daemon) {
        std.debug.print("   Mode: Daemon (background)\n", .{});
    } else {
        std.debug.print("   Mode: Foreground\n", .{});
    }

    std.debug.print("✅ Server started successfully!\n", .{});
}

fn buildHandler(args: BuildArgs.ArgsType, allocator: std.mem.Allocator) !void {
    _ = allocator; // Not used in this example

    std.debug.print("   Building project...\n", .{});
    std.debug.print("   Target: {s}\n", .{args.target});

    if (args.release) {
        std.debug.print("   Mode: Release (optimized)\n", .{});
    } else {
        std.debug.print("   Mode: Debug\n", .{});
    }

    if (args.verbose) {
        std.debug.print("   Verbose output enabled\n", .{});
        std.debug.print("   Compiling src/main.zig...\n", .{});
        std.debug.print("   Linking dependencies...\n", .{});
    }

    std.debug.print("✅ Build completed successfully!\n", .{});
}

fn migrateUpHandler(args: DbMigrateUpArgs.ArgsType, allocator: std.mem.Allocator) !void {
    _ = allocator; // Not used in this example

    std.debug.print("⬆️  Running database migrations...\n", .{});
    std.debug.print("   Steps: {d}\n", .{args.steps});

    if (args.dry_run) {
        std.debug.print("   Mode: Dry run (no changes will be made)\n", .{});
        std.debug.print("   Would apply {d} migration(s)\n", .{args.steps});
    } else {
        std.debug.print("   Applying {d} migration(s)...\n", .{args.steps});
        var i: u32 = 0;
        while (i < args.steps) : (i += 1) {
            std.debug.print("   ✓ Applied migration {d}\n", .{i + 1});
        }
    }

    std.debug.print("✅ Database migration completed!\n", .{});
}

fn seedHandler(args: DbSeedArgs.ArgsType, allocator: std.mem.Allocator) !void {
    _ = allocator; // Not used in this example

    std.debug.print("🌱 Seeding database...\n", .{});
    std.debug.print("   File: {s}\n", .{args.file});

    if (args.table.len > 0) {
        std.debug.print("   Table: {s}\n", .{args.table});
    } else {
        std.debug.print("   Table: All tables\n", .{});
    }

    if (args.force) {
        std.debug.print("   Mode: Force (overwrite existing data)\n", .{});
    } else {
        std.debug.print("   Mode: Safe (skip existing data)\n", .{});
    }

    std.debug.print("✅ Database seeding completed!\n", .{});
}

// === Argument Definitions ===

const ServeArgs = cli.Args(&.{
    cli.flag("daemon", .{ .short = 'd', .help = "Run as daemon in background" }),
    cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on" }),
    cli.option("host", []const u8, .{ .short = 'h', .default = "localhost", .help = "Host to bind to" }),
});

const BuildArgs = cli.Args(&.{
    cli.flag("release", .{ .short = 'r', .help = "Build in release mode" }),
    cli.option("target", []const u8, .{ .short = 't', .default = "native", .help = "Target platform" }),
    cli.flag("verbose", .{ .short = 'v', .help = "Enable verbose build output" }),
});

const DbMigrateUpArgs = cli.Args(&.{
    cli.option("steps", u32, .{ .short = 's', .default = 1, .help = "Number of migration steps" }),
    cli.flag("dry_run", .{ .help = "Show what would be done without executing" }),
});

const DbSeedArgs = cli.Args(&.{
    cli.option("file", []const u8, .{ .short = 'f', .default = "seeds.sql", .help = "Seed file to use" }),
    cli.flag("force", .{ .help = "Force overwrite existing data" }),
    cli.option("table", []const u8, .{ .short = 't', .default = "", .help = "Seed specific table only" }),
});

// === Database Commands (with handlers) ===

const DbMigrateCommands = cli.Commands(&.{
    cli.command("up", DbMigrateUpArgs, .{ .help = "Apply database migrations", .handler = migrateUpHandler }),
    // Note: migrate down would need its own handler - not implemented in this example
});

const DatabaseCommands = cli.Commands(&.{
    cli.command("migrate", DbMigrateCommands, .{ .help = "Database migration operations" }),
    cli.command("seed", DbSeedArgs, .{ .help = "Seed database with initial data", .handler = seedHandler }),
});

// === Main Application Commands ===

const AppCommands = cli.Commands(&.{
    // Simple commands with handlers
    cli.command("serve", ServeArgs, .{ .help = "Start the application server", .handler = serveHandler }),
    cli.command("build", BuildArgs, .{ .help = "Build the application", .handler = buildHandler }),

    // Nested commands with handlers
    cli.command("db", DatabaseCommands, .{ .help = "Database operations" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Commands will automatically execute their handlers after parsing
    try AppCommands.parse(arena.allocator());
}
