//! Nested Subcommand Example - Hierarchical CLI with unlimited depth
//!
//! This example demonstrates true nested subcommands using Commands types,
//! enabling complex CLI tools with deep hierarchies like Git and Docker:
//! 
//! Examples:
//! - nested serve --port 3000 --daemon
//! - nested db migrate up --steps 5 --dry-run
//! - nested db migrate down --steps 2
//! - nested db seed --file custom.sql --force
//! - nested git remote add origin https://github.com/user/repo.git --fetch
//! - nested git remote remove upstream
//! - nested git branch create feature/auth --from develop
//! - nested docker container run nginx --detach --name web-server
//! - nested docker image pull redis --all-tags
//!
//! This demonstrates the full power of the zync-cli subcommand system with
//! unlimited nesting depth and contextual help at every level.

const std = @import("std");
const cli = @import("zync-cli");

// === Database Command Hierarchy ===

const DbMigrateUpArgs = cli.Args(&.{
    cli.option("steps", u32, .{ .short = 's', .default = 1, .help = "Number of migration steps" }),
    cli.flag("dry-run", .{ .help = "Show what would be done without executing" }),
});

const DbMigrateDownArgs = cli.Args(&.{
    cli.option("steps", u32, .{ .short = 's', .default = 1, .help = "Number of migration steps to rollback" }),
    cli.flag("dry-run", .{ .help = "Show what would be done without executing" }),
});

const DbMigrateCommands = cli.Commands(&.{
    cli.command("up", DbMigrateUpArgs, .{ .help = "Apply database migrations" }),
    cli.command("down", DbMigrateDownArgs, .{ .help = "Rollback database migrations" }),
});

const DbSeedArgs = cli.Args(&.{
    cli.option("file", []const u8, .{ .short = 'f', .default = "seeds.sql", .help = "Seed file to use" }),
    cli.flag("force", .{ .help = "Force overwrite existing data" }),
    cli.option("table", []const u8, .{ .short = 't', .default = "", .help = "Seed specific table only" }),
});

const DbStatusArgs = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Show detailed status information" }),
    cli.flag("json", .{ .help = "Output status in JSON format" }),
});

const DatabaseCommands = cli.Commands(&.{
    cli.command("migrate", DbMigrateCommands, .{ .help = "Database migration operations" }),
    cli.command("seed", DbSeedArgs, .{ .help = "Seed database with initial data" }),
    cli.command("status", DbStatusArgs, .{ .help = "Show database status" }),
});

// === Git Command Hierarchy ===

const GitRemoteAddArgs = cli.Args(&.{
    cli.required("name", []const u8, .{ .help = "Remote name (e.g., origin)" }),
    cli.required("url", []const u8, .{ .help = "Remote URL" }),
    cli.flag("fetch", .{ .short = 'f', .help = "Fetch after adding remote" }),
});

const GitRemoteRemoveArgs = cli.Args(&.{
    cli.required("name", []const u8, .{ .help = "Remote name to remove" }),
});

const GitRemoteListArgs = cli.Args(&.{
    cli.flag("verbose", .{ .short = 'v', .help = "Show URLs" }),
});

const GitRemoteCommands = cli.Commands(&.{
    cli.command("add", GitRemoteAddArgs, .{ .help = "Add a new remote" }),
    cli.command("remove", GitRemoteRemoveArgs, .{ .help = "Remove a remote" }),
    cli.command("list", GitRemoteListArgs, .{ .help = "List remotes" }),
});

const GitBranchCreateArgs = cli.Args(&.{
    cli.required("name", []const u8, .{ .help = "New branch name" }),
    cli.option("from", []const u8, .{ .default = "HEAD", .help = "Create from branch/commit" }),
});

const GitBranchListArgs = cli.Args(&.{
    cli.flag("all", .{ .short = 'a', .help = "List all branches" }),
    cli.flag("remote", .{ .short = 'r', .help = "List remote branches" }),
});

const GitBranchCommands = cli.Commands(&.{
    cli.command("create", GitBranchCreateArgs, .{ .help = "Create a new branch" }),
    cli.command("list", GitBranchListArgs, .{ .help = "List branches" }),
});

const GitCommands = cli.Commands(&.{
    cli.command("remote", GitRemoteCommands, .{ .help = "Manage remote repositories" }),
    cli.command("branch", GitBranchCommands, .{ .help = "Manage git branches" }),
});

// === Docker Command Hierarchy ===

const DockerContainerRunArgs = cli.Args(&.{
    cli.required("image", []const u8, .{ .short = 'i', .help = "Container image to run" }),
    cli.flag("detach", .{ .short = 'd', .help = "Run in background" }),
    cli.option("name", []const u8, .{ .default = "", .help = "Container name" }),
});

const DockerContainerListArgs = cli.Args(&.{
    cli.flag("all", .{ .short = 'a', .help = "Show all containers" }),
    cli.flag("quiet", .{ .short = 'q', .help = "Only show container IDs" }),
});

const DockerContainerStopArgs = cli.Args(&.{
    cli.required("container", []const u8, .{ .short = 'c', .help = "Container name or ID" }),
    cli.option("time", u32, .{ .short = 't', .default = 10, .help = "Seconds to wait before killing" }),
});

const DockerContainerCommands = cli.Commands(&.{
    cli.command("run", DockerContainerRunArgs, .{ .help = "Run a new container" }),
    cli.command("list", DockerContainerListArgs, .{ .help = "List containers" }),
    cli.command("stop", DockerContainerStopArgs, .{ .help = "Stop containers" }),
});

const DockerImagePullArgs = cli.Args(&.{
    cli.required("image", []const u8, .{ .short = 'i', .help = "Image to pull" }),
    cli.flag("all-tags", .{ .short = 'a', .help = "Download all tagged images" }),
});

const DockerImageListArgs = cli.Args(&.{
    cli.flag("all", .{ .short = 'a', .help = "Show all images" }),
    cli.flag("digests", .{ .help = "Show digests" }),
});

const DockerImageCommands = cli.Commands(&.{
    cli.command("pull", DockerImagePullArgs, .{ .help = "Pull an image from registry" }),
    cli.command("list", DockerImageListArgs, .{ .help = "List images" }),
});

const DockerCommands = cli.Commands(&.{
    cli.command("container", DockerContainerCommands, .{ .help = "Container management" }),
    cli.command("image", DockerImageCommands, .{ .help = "Image management" }),
});

// === Simple Commands ===

const ServeArgs = cli.Args(&.{
    cli.flag("daemon", .{ .short = 'd', .help = "Run as daemon" }),
    cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on" }),
    cli.option("host", []const u8, .{ .short = 'h', .default = "localhost", .help = "Host to bind to" }),
});

const BuildArgs = cli.Args(&.{
    cli.flag("release", .{ .short = 'r', .help = "Build in release mode" }),
    cli.option("target", []const u8, .{ .short = 't', .default = "native", .help = "Target platform" }),
    cli.flag("verbose", .{ .short = 'v', .help = "Verbose build output" }),
});

// === Main Application Commands ===

const AppCommands = cli.Commands(&.{
    // Simple 1-level commands
    cli.command("serve", ServeArgs, .{ .help = "Start the application server" }),
    cli.command("build", BuildArgs, .{ .help = "Build the application" }),
    
    // Nested hierarchical commands demonstrating unlimited depth
    cli.command("db", DatabaseCommands, .{ .help = "Database operations" }),
    cli.command("git", GitCommands, .{ .help = "Git-style version control operations" }),
    cli.command("docker", DockerCommands, .{ .help = "Docker-style container operations" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // Handle unlimited depth nesting automatically
    try AppCommands.parse(arena.allocator());
}