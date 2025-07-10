//! Multi-Level Subcommand Example - Demonstrating Hierarchical CLI Patterns
//!
//! This example shows how to organize complex CLIs using the current subcommand system.
//! While full nesting support is planned for future versions, this demonstrates
//! practical patterns for organizing complex CLI tools:
//! - myapp db-migrate up --steps 1
//! - myapp git-remote-add origin https://github.com/user/repo.git
//! - myapp docker-run --detach nginx

const std = @import("std");
const cli = @import("zync-cli");

// === Database Commands (demonstrating complex CLI organization) ===

const DbMigrateUpArgs = cli.Args(&.{
    cli.option("steps", u32, .{ .short = 's', .default = 1, .help = "Number of migration steps" }),
    cli.flag("dry-run", .{ .help = "Show what would be done without executing" }),
});

const DbMigrateDownArgs = cli.Args(&.{
    cli.option("steps", u32, .{ .short = 's', .default = 1, .help = "Number of migration steps to rollback" }),
    cli.flag("dry-run", .{ .help = "Show what would be done without executing" }),
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

// === Git-Style Commands (demonstrating command naming patterns) ===

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

const GitBranchListArgs = cli.Args(&.{
    cli.flag("all", .{ .short = 'a', .help = "List all branches" }),
    cli.flag("remote", .{ .short = 'r', .help = "List remote branches" }),
});

const GitBranchCreateArgs = cli.Args(&.{
    cli.required("name", []const u8, .{ .help = "New branch name" }),
    cli.option("from", []const u8, .{ .default = "HEAD", .help = "Create from branch/commit" }),
});

const GitCommitArgs = cli.Args(&.{
    cli.required("message", []const u8, .{ .short = 'm', .help = "Commit message" }),
    cli.flag("all", .{ .short = 'a', .help = "Commit all changes" }),
    cli.flag("amend", .{ .help = "Amend previous commit" }),
});

// === Docker-Style Commands (demonstrating component organization) ===

const DockerRunArgs = cli.Args(&.{
    cli.required("image", []const u8, .{ .short = 'i', .help = "Container image to run" }),
    cli.flag("detach", .{ .short = 'd', .help = "Run in background" }),
    cli.option("name", []const u8, .{ .default = "", .help = "Container name" }),
    cli.option("port", []const u8, .{ .short = 'p', .default = "", .help = "Port mapping (host:container)" }),
});

const DockerPsArgs = cli.Args(&.{
    cli.flag("all", .{ .short = 'a', .help = "Show all containers" }),
    cli.flag("quiet", .{ .short = 'q', .help = "Only show container IDs" }),
});

const DockerStopArgs = cli.Args(&.{
    cli.required("container", []const u8, .{ .short = 'c', .help = "Container name or ID" }),
    cli.option("time", u32, .{ .short = 't', .default = 10, .help = "Seconds to wait before killing" }),
});

const DockerImagesArgs = cli.Args(&.{
    cli.flag("all", .{ .short = 'a', .help = "Show all images" }),
    cli.flag("digests", .{ .help = "Show digests" }),
});

const DockerPullArgs = cli.Args(&.{
    cli.required("image", []const u8, .{ .short = 'i', .help = "Image to pull" }),
    cli.flag("all-tags", .{ .short = 'a', .help = "Download all tagged images" }),
});

// === Simple Commands (1-level) ===

const ServeArgs = cli.Args(&.{
    cli.flag("daemon", .{ .short = 'd', .help = "Run as daemon" }),
    cli.option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on" }),
});

const BuildArgs = cli.Args(&.{
    cli.flag("release", .{ .short = 'r', .help = "Build in release mode" }),
    cli.option("target", []const u8, .{ .short = 't', .default = "native", .help = "Target platform" }),
});

// === Main Application Commands ===

const AppCommands = cli.Commands(&.{
    // Simple 1-level commands
    cli.command("serve", ServeArgs, .{ .help = "Start the application server" }),
    cli.command("build", BuildArgs, .{ .help = "Build the application" }),
    
    // Database operations (using descriptive names)
    cli.command("db-migrate-up", DbMigrateUpArgs, .{ .help = "Run database migrations (up)" }),
    cli.command("db-migrate-down", DbMigrateDownArgs, .{ .help = "Rollback database migrations (down)" }),
    cli.command("db-seed", DbSeedArgs, .{ .help = "Seed database with data" }),
    cli.command("db-status", DbStatusArgs, .{ .help = "Show database status" }),
    
    // Git-style operations (demonstrating complex CLI patterns)
    cli.command("git-remote-add", GitRemoteAddArgs, .{ .help = "Add a git remote" }),
    cli.command("git-remote-remove", GitRemoteRemoveArgs, .{ .help = "Remove a git remote" }),
    cli.command("git-remote-list", GitRemoteListArgs, .{ .help = "List git remotes" }),
    cli.command("git-branch-list", GitBranchListArgs, .{ .help = "List git branches" }),
    cli.command("git-branch-create", GitBranchCreateArgs, .{ .help = "Create a new git branch" }),
    cli.command("git-commit", GitCommitArgs, .{ .help = "Create a git commit" }),
    
    // Docker-style operations (showing container management patterns)
    cli.command("docker-run", DockerRunArgs, .{ .help = "Run a docker container" }),
    cli.command("docker-ps", DockerPsArgs, .{ .help = "List docker containers" }),
    cli.command("docker-stop", DockerStopArgs, .{ .help = "Stop docker containers" }),
    cli.command("docker-images", DockerImagesArgs, .{ .help = "List docker images" }),
    cli.command("docker-pull", DockerPullArgs, .{ .help = "Pull docker images" }),
});

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    
    // Handle all levels of nesting automatically
    try AppCommands.parse(arena.allocator());
}