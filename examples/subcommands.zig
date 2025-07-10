//! Subcommand System Example - Hierarchical CLI with unlimited depth
//!
//! This example demonstrates the new subcommand system in Zync-CLI,
//! showing how to create Git-style CLI tools with hierarchical commands.

const std = @import("std");
const cli = @import("zync-cli");

// Define Args for different commands
const ServeArgs = cli.Args(&.{
    cli.flag("daemon", .{ .short = 'd', .help = "Run as daemon", .env_var = "SERVER_DAEMON" }),
    cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on", .env_var = "SERVER_PORT" }),
    cli.option("host", []const u8, .{ .short = 'h', .default = "localhost", .help = "Host to bind to", .env_var = "SERVER_HOST" }),
});

const BuildArgs = cli.Args(&.{
    cli.flag("release", .{ .short = 'r', .help = "Build in release mode", .env_var = "BUILD_RELEASE" }),
    cli.option("target", []const u8, .{ .short = 't', .default = "native", .help = "Target platform", .env_var = "BUILD_TARGET" }),
    cli.flag("verbose", .{ .short = 'v', .help = "Verbose build output", .env_var = "BUILD_VERBOSE" }),
});

const TestArgs = cli.Args(&.{
    cli.flag("coverage", .{ .short = 'c', .help = "Generate coverage report", .env_var = "TEST_COVERAGE" }),
    cli.option("filter", []const u8, .{ .short = 'f', .default = "", .help = "Test filter pattern", .env_var = "TEST_FILTER" }),
    cli.flag("watch", .{ .short = 'w', .help = "Watch for changes and re-run tests", .env_var = "TEST_WATCH" }),
});

const DatabaseMigrateArgs = cli.Args(&.{
    cli.required("direction", []const u8, .{ .short = 'd', .help = "Migration direction (up/down)", .env_var = "DB_MIGRATE_DIRECTION" }),
    cli.option("steps", u32, .{ .short = 's', .default = 1, .help = "Number of steps to migrate", .env_var = "DB_MIGRATE_STEPS" }),
});

const DatabaseSeedArgs = cli.Args(&.{
    cli.option("file", []const u8, .{ .short = 'f', .default = "seeds.sql", .help = "Seed file to use", .env_var = "DB_SEED_FILE" }),
    cli.flag("force", .{ .help = "Force overwrite existing data", .env_var = "DB_SEED_FORCE" }),
});

// Create the command hierarchy
const AppCommands = cli.Commands(&.{
    cli.command("serve", ServeArgs, .{ 
        .help = "Start the application server",
        .description = "Launch the web server with the specified configuration"
    }),
    cli.command("build", BuildArgs, .{ 
        .help = "Build the application",
        .description = "Compile the application for the target platform"
    }),
    cli.command("test", TestArgs, .{ 
        .help = "Run the test suite",
        .description = "Execute all tests with optional coverage and filtering"
    }),
    
    // TODO: Hierarchical commands (db migrate, db seed) will be implemented
    // when we add support for category commands with subcommands
    cli.command("db-migrate", DatabaseMigrateArgs, .{ 
        .help = "Run database migrations",
        .description = "Apply or rollback database schema changes"
    }),
    cli.command("db-seed", DatabaseSeedArgs, .{ 
        .help = "Seed the database with initial data",
        .description = "Populate the database with test or initial data"
    }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // The subcommand system handles all parsing and routing automatically
    try AppCommands.parse(arena.allocator());
}