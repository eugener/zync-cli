//! Zync-CLI Automatic DSL - Zero Duplication, No Explicit Metadata
//!
//! This module implements a DSL where metadata is automatically extracted
//! from field definitions without requiring explicit dsl_metadata declarations.

const std = @import("std");
const FieldMetadata = @import("meta.zig").FieldMetadata;
const test_utils = @import("test_utils.zig");



/// Configuration for boolean flag arguments
pub const FlagConfig = struct {
    short: ?u8 = null,
    help: ?[]const u8 = null,
    default: ?bool = null,
    hidden: bool = false,
    env_var: ?[]const u8 = null,
};

/// Configuration for optional arguments with defaults
pub fn OptionConfig(comptime T: type) type {
    return struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        default: T,
        hidden: bool = false,
        env_var: ?[]const u8 = null,
    };
}

/// Configuration for required arguments
pub fn RequiredConfig(comptime T: type) type {
    _ = T;
    return struct {
        short: ?u8 = null,
        help: ?[]const u8 = null,
        hidden: bool = false,
        env_var: ?[]const u8 = null,
    };
}

/// Configuration for positional arguments
pub fn PositionalConfig(comptime T: type) type {
    return struct {
        help: ?[]const u8 = null,
        default: ?T = null,
        required: bool = true,
    };
}

/// Container that holds both a value and its metadata
pub fn FieldDef(comptime T: type) type {
    return struct {
        value: T,
        metadata: FieldMetadata,
        
        const Self = @This();
        
        /// Get the default value for this field
        pub fn getValue(self: Self) T {
            return self.value;
        }
        
        /// Get the metadata for this field
        pub fn getMeta(self: Self) FieldMetadata {
            return self.metadata;
        }
    };
}

/// Helper function to format default values as strings at compile time
fn formatDefaultValue(comptime T: type, default_val: T) ?[]const u8 {
    return blk: {
        if (T == []const u8) {
            break :blk default_val;
        } else if (@typeInfo(T) == .int) {
            break :blk std.fmt.comptimePrint("{}", .{default_val});
        } else if (@typeInfo(T) == .float) {
            break :blk std.fmt.comptimePrint("{d}", .{default_val});
        } else if (T == bool) {
            break :blk if (default_val) "true" else "false";
        } else {
            break :blk null;
        }
    };
}

/// Create a boolean flag field definition with metadata
pub fn flag(comptime field_name: []const u8, comptime config: FlagConfig) FieldDef(bool) {
    const metadata = FieldMetadata{
        .name = field_name,
        .short = config.short,
        .help = config.help,
        .hidden = config.hidden,
        .env_var = config.env_var,
    };
    
    return FieldDef(bool){
        .value = config.default orelse false,
        .metadata = metadata,
    };
}

/// Create an option field definition with metadata
pub fn option(comptime field_name: []const u8, comptime T: type, comptime config: OptionConfig(T)) FieldDef(T) {
    const default_str = formatDefaultValue(T, config.default);
    
    const metadata = FieldMetadata{
        .name = field_name,
        .short = config.short,
        .help = config.help,
        .default = default_str,
        .hidden = config.hidden,
        .env_var = config.env_var,
    };
    
    return FieldDef(T){
        .value = config.default,
        .metadata = metadata,
    };
}

/// Create a required field definition with metadata
pub fn required(comptime field_name: []const u8, comptime T: type, comptime config: RequiredConfig(T)) FieldDef(T) {
    const metadata = FieldMetadata{
        .name = field_name,
        .short = config.short,
        .help = config.help,
        .required = true,
        .hidden = config.hidden,
        .env_var = config.env_var,
    };
    
    return FieldDef(T){
        .value = @as(T, undefined), // Will be set during parsing
        .metadata = metadata,
    };
}

/// Create a positional field definition with metadata
pub fn positional(comptime field_name: []const u8, comptime T: type, comptime config: PositionalConfig(T)) FieldDef(T) {
    const default_str = if (config.default) |default_val| formatDefaultValue(T, default_val) else null;
    
    const metadata = FieldMetadata{
        .name = field_name,
        .help = config.help,
        .default = default_str,
        .required = config.required,
        .positional = true,
    };
    
    return FieldDef(T){
        .value = config.default orelse @as(T, undefined),
        .metadata = metadata,
    };
}

/// Configuration for the Args struct
pub const ArgsConfig = struct {
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
};

/// Handler function type that accepts any Args type and allocator
pub const GenericHandlerFn = *const fn(*const anyopaque, std.mem.Allocator) anyerror!void;

/// Configuration for command definitions
pub const CommandConfig = struct {
    help: ?[]const u8 = null,
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
    hidden: bool = false,
    handler: ?GenericHandlerFn = null,
};

/// Leaf command configuration with strongly-typed handler
pub fn LeafCommandConfig(comptime ArgsType: type) type {
    return struct {
        help: ?[]const u8 = null,
        title: ?[]const u8 = null,
        description: ?[]const u8 = null,
        hidden: bool = false,
        handler: ?HandlerFn(ArgsType) = null,
    };
}

/// Category command configuration (no handler allowed)
pub const CategoryCommandConfig = struct {
    help: ?[]const u8 = null,
    title: ?[]const u8 = null,
    description: ?[]const u8 = null,
    hidden: bool = false,
};

/// Convert leaf command config to generic CommandConfig
fn convertLeafConfig(comptime ArgsType: type, comptime config: LeafCommandConfig(ArgsType)) CommandConfig {
    const generic_handler = if (config.handler) |handler|
        struct {
            fn call(args_ptr: *const anyopaque, allocator: std.mem.Allocator) !void {
                const typed_args: *const ArgsType.ArgsType = @ptrCast(@alignCast(args_ptr));
                try handler(typed_args.*, allocator);
            }
        }.call
    else
        null;
    
    return CommandConfig{
        .help = config.help,
        .title = config.title,
        .description = config.description,
        .hidden = config.hidden,
        .handler = generic_handler,
    };
}

/// Convert category command config to generic CommandConfig
fn convertCategoryConfig(comptime config: CategoryCommandConfig) CommandConfig {
    return CommandConfig{
        .help = config.help,
        .title = config.title,
        .description = config.description,
        .hidden = config.hidden,
        .handler = null, // Categories cannot have handlers
    };
}

/// Convert any config struct to CommandConfig (legacy support)
fn convertConfig(comptime config: anytype) CommandConfig {
    // This function provides backward compatibility for anonymous config structs
    // New code should use LeafCommandConfig(ArgsType) or CategoryCommandConfig
    const ConfigType = @TypeOf(config);
    const config_info = @typeInfo(ConfigType);
    
    if (config_info != .@"struct") {
        @compileError("Config must be a struct");
    }
    
    var result = CommandConfig{};
    
    // Copy known fields (handler conversion is now type-unsafe for legacy support)
    inline for (config_info.@"struct".fields) |field| {
        const field_value = @field(config, field.name);
        
        if (std.mem.eql(u8, field.name, "help")) {
            result.help = field_value;
        } else if (std.mem.eql(u8, field.name, "title")) {
            result.title = field_value;
        } else if (std.mem.eql(u8, field.name, "description")) {
            result.description = field_value;
        } else if (std.mem.eql(u8, field.name, "hidden")) {
            result.hidden = field_value;
        } else if (std.mem.eql(u8, field.name, "handler")) {
            // Legacy handler conversion - preserved for backward compatibility
            // TODO: Migrate to LeafCommandConfig(ArgsType) and cli.leafCommand() for better type safety
            const handler_info = @typeInfo(@TypeOf(field_value));
            switch (handler_info) {
                .@"fn" => {
                    result.handler = @as(?GenericHandlerFn, @ptrCast(&field_value));
                },
                .pointer => |ptr_info| {
                    if (ptr_info.size == .One) {
                        const pointee_info = @typeInfo(ptr_info.child);
                        if (pointee_info == .@"fn") {
                            result.handler = @as(?GenericHandlerFn, @ptrCast(field_value));
                        } else {
                            result.handler = @as(?GenericHandlerFn, @ptrCast(field_value));
                        }
                    } else {
                        result.handler = @as(?GenericHandlerFn, @ptrCast(field_value));
                    }
                },
                .optional => |opt_info| {
                    if (field_value == null) {
                        result.handler = null;
                    } else {
                        const inner_info = @typeInfo(opt_info.child);
                        if (inner_info == .@"fn") {
                            result.handler = @as(?GenericHandlerFn, @ptrCast(&field_value.?));
                        } else {
                            result.handler = @as(?GenericHandlerFn, @ptrCast(field_value));
                        }
                    }
                },
                .@"null" => {
                    result.handler = null;
                },
                else => {
                    result.handler = @as(?GenericHandlerFn, @ptrCast(field_value));
                },
            }
        }
    }
    
    return result;
}

/// Handler function type for leaf commands
pub fn HandlerFn(comptime ArgsType: type) type {
    return *const fn(ArgsType.ArgsType, std.mem.Allocator) anyerror!void;
}

/// Create a leaf command with strongly-typed handler
pub fn leafCommand(comptime name: []const u8, comptime ArgsType: type, comptime config: LeafCommandConfig(ArgsType)) CommandDef(ArgsType) {
    return CommandDef(ArgsType){
        .command_name = name,
        .config = convertLeafConfig(ArgsType, config),
        .command_type = .leaf,
        .data = .{ .leaf = ArgsType },
        .handler = if (config.handler) |h| @as(*const anyopaque, @ptrCast(&h)) else null,
        .original_type = ArgsType,
    };
}

/// Create a category command (no handler allowed)
pub fn categoryCommand(comptime name: []const u8, comptime SubcommandType: type, comptime config: CategoryCommandConfig) CommandDef(SubcommandType) {
    return CommandDef(SubcommandType){
        .command_name = name,
        .config = convertCategoryConfig(config),
        .command_type = .category,
        .data = .{ .category = SubcommandType },
        .handler = null,
        .original_type = SubcommandType,
    };
}



/// Command definition - either a leaf command (with Args) or a category command (with subcommands)
pub fn CommandDef(comptime T: type) type {
    return struct {
        command_name: []const u8,
        config: CommandConfig,
        command_type: enum { leaf, category },
        
        // Union for command data
        data: union(enum) {
            leaf: type, // Args type
            category: type, // Array of subcommands
        },
        
        // Optional handler function for leaf commands
        handler: ?*const anyopaque = null,
        
        // Store the original type for reference
        original_type: type = T,
        
        const Self = @This();
        
        /// Get the command name
        pub fn getName(self: Self) []const u8 {
            return self.command_name;
        }
        
        /// Check if this is a leaf command
        pub fn isLeaf(self: Self) bool {
            return self.command_type == .leaf;
        }
        
        /// Check if this is a category command
        pub fn isCategory(self: Self) bool {
            return self.command_type == .category;
        }
        
        /// Get the Args type for leaf commands
        pub fn getArgsType(self: Self) type {
            if (self.command_type != .leaf) {
                @compileError("getArgsType() can only be called on leaf commands");
            }
            return self.data.leaf;
        }
        
        /// Get the subcommands array for category commands
        pub fn getSubcommands(self: Self) type {
            if (self.command_type != .category) {
                @compileError("getSubcommands() can only be called on category commands");
            }
            return self.data.category;
        }
        
        /// Check if this command has a handler function
        pub fn hasHandler(self: Self) bool {
            return self.handler != null;
        }
        
        /// Execute the handler function with parsed arguments
        pub fn executeHandler(self: Self, args: anytype, allocator: std.mem.Allocator) !void {
            if (self.handler == null) {
                return; // No handler to execute
            }
            
            if (self.command_type != .leaf) {
                @compileError("executeHandler() can only be called on leaf commands");
            }
            
            const ArgsType = self.data.leaf;
            const handler_fn = @as(HandlerFn(ArgsType), @ptrCast(@alignCast(self.handler.?)));
            try handler_fn(args, allocator);
        }
    };
}

/// Compile-time validation for command data types
fn validateCommandData(comptime command_data: anytype) void {
    const T = @TypeOf(command_data);
    const type_info = @typeInfo(T);
    
    // Validate the command data type
    if (type_info == .type) {
        // command_data is a type (like ServeArgs which is a type returned by Args())
        const target_type = command_data;
        const target_info = @typeInfo(target_type);
        
        if (target_info == .@"struct") {
            // For struct types, we'll allow any struct as it could be:
            // 1. Args type created with cli.Args() (has dsl_metadata and parse methods)
            // 2. Commands type created with cli.Commands() (has parse and commands field)
            // 3. A simple struct with CLI fields
            // The actual validation happens later in the command() function
        } else {
            @compileError("Type parameters must be struct types (Args or Commands)");
        }
    } else if (type_info == .pointer) {
        const ptr_info = type_info.pointer;
        if (ptr_info.size != .Slice) {
            @compileError("Pointer parameters must be slices of commands");
        }
    } else if (type_info == .array) {
        // Array of commands is valid
    } else {
        @compileError("Invalid command data type. Expected: Args type, Commands type, or array/slice of commands");
    }
}

/// Create a unified command definition that automatically detects leaf vs category commands
/// Usage: 
///   command("serve", Args(...), .{ .help = "Start the server" })  // Leaf command without handler
///   command("serve", Args(...), .{ .help = "Start the server", .handler = myHandler })  // Leaf command with handler (automatic conversion)
///   command("git", &.{ ... subcommands ... }, .{ .help = "Git operations" })  // Category command
pub fn command(comptime name: []const u8, comptime command_data: anytype, comptime config: anytype) CommandDef(@TypeOf(command_data)) {
    // Compile-time validation
    if (name.len == 0) {
        @compileError("Command name cannot be empty");
    }
    
    // Validate command name format (no spaces, special chars)
    comptime {
        for (name) |c| {
            if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
                @compileError("Command name cannot contain whitespace characters");
            }
            if (c == '-' and name[0] == '-') {
                @compileError("Command name cannot start with dashes (reserved for flags)");
            }
        }
    }
    
    validateCommandData(command_data);
    // Convert the config to proper CommandConfig, handling automatic function conversion
    const converted_config = convertConfig(config);
    const T = @TypeOf(command_data);
    const type_info = @typeInfo(T);
    
    // Auto-detect if this is an Args type (has dsl_metadata), Commands type, or subcommands array
    const command_type = blk: {
        if (type_info == .type) {
            // This is a type (likely Args type or Commands type)
            const target_type = command_data;
            const target_info = @typeInfo(target_type);
            if (target_info == .@"struct") {
                const struct_info = target_info.@"struct";
                // Check for Args type (has dsl_metadata)
                for (struct_info.decls) |decl| {
                    if (std.mem.eql(u8, decl.name, "dsl_metadata")) {
                        break :blk .leaf;
                    }
                }
                // Check for Commands type (has parse method and commands field)
                var has_parse = false;
                var has_commands = false;
                for (struct_info.decls) |decl| {
                    if (std.mem.eql(u8, decl.name, "parse") or std.mem.eql(u8, decl.name, "parseFrom")) {
                        has_parse = true;
                    }
                }
                for (struct_info.fields) |field| {
                    if (std.mem.eql(u8, field.name, "commands")) {
                        has_commands = true;
                    }
                }
                if (has_parse and has_commands) {
                    break :blk .category;
                }
            }
        } else if (type_info == .pointer) {
            // This is likely an array of subcommands (slice)
            break :blk .category;
        } else if (type_info == .array) {
            // This is an array of subcommands
            break :blk .category;
        }
        @compileError("command() expects either an Args type, Commands type, or an array of subcommands");
    };
    
    // Validate handler type and command type compatibility
    const handler_ptr = if (converted_config.handler == null) null else blk: {
        if (command_type != .leaf) {
            @compileError("Handlers can only be used with leaf commands (Args types). Category commands cannot have handlers.");
        }
        
        // Additional validation: ensure the command data is actually an Args type
        if (type_info == .type) {
            const target_type = command_data;
            const target_info = @typeInfo(target_type);
            if (target_info == .@"struct") {
                const struct_info = target_info.@"struct";
                var has_args_marker = false;
                for (struct_info.decls) |decl| {
                    if (std.mem.eql(u8, decl.name, "dsl_metadata") or 
                       std.mem.eql(u8, decl.name, "ArgsType")) {
                        has_args_marker = true;
                        break;
                    }
                }
                if (!has_args_marker) {
                    @compileError("Handlers can only be used with Args types created via cli.Args()");
                }
            }
        }
        
        // Handler is already converted to GenericHandlerFn, so we can use it directly
        break :blk converted_config.handler;
    };
    
    return CommandDef(T){
        .command_name = name,
        .config = converted_config,
        .command_type = command_type,
        .data = switch (command_type) {
            .leaf => .{ .leaf = command_data },
            .category => .{ .category = command_data },
            else => @compileError("Invalid command type detected"),
        },
        .handler = handler_ptr,
    };
}

/// Parse a category command by delegating to its Commands system
fn parseCategoryCommand(cmd: anytype, allocator: std.mem.Allocator, args: []const []const u8, command_name: []const u8) anyerror!void {
    return parseCategoryCommandWithPath(cmd, allocator, args, command_name);
}

/// Parse a category command by delegating to its Commands system with command path tracking
fn parseCategoryCommandWithPath(cmd: anytype, allocator: std.mem.Allocator, args: []const []const u8, command_path: []const u8) anyerror!void {
    // Check if this is a help request for the category itself
    if (args.len > 0 and (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h"))) {
        // Show help for this category level
        const CategoryData = cmd.data.category;
        const category_info = @typeInfo(@TypeOf(CategoryData));
        
        if (category_info == .type) {
            // This is a Commands type - call showHelpWithPath on it
            return CategoryData.showHelpWithPath(allocator, command_path);
        } else {
            // For array types, we need to create a temporary Commands system to show help
            const TempCommands = if (category_info == .pointer) 
                Commands(CategoryData.*)
            else 
                Commands(CategoryData);
            return TempCommands.showHelpWithPath(allocator, command_path);
        }
    }
    
    const CategoryData = cmd.data.category;
    const category_info = @typeInfo(@TypeOf(CategoryData));
    
    if (category_info == .type) {
        // This is a Commands type - we can call parseFromWithPath directly on the type
        return CategoryData.parseFromWithPath(allocator, args, command_path);
    } else if (category_info == .pointer) {
        // This is a pointer to an array of subcommands
        // Create a Commands system from the actual command array
        const subcmds = CategoryData;
        const TempCommands = Commands(subcmds.*);
        const temp_system = TempCommands.init();
        return temp_system.parseFromWithPath(allocator, args, command_path);
    } else if (category_info == .array) {
        // This is an array of subcommands - create a temporary Commands system
        const TempCommands = Commands(CategoryData);
        const temp_system = TempCommands.init();
        return temp_system.parseFromWithPath(allocator, args, command_path);
    } else {
        std.debug.print("Error: Category command has unsupported category type: {}\n", .{category_info});
        return;
    }
}

/// Parse arguments for a subcommand with proper help context
fn parseSubcommandArgs(comptime ArgsType: type, allocator: std.mem.Allocator, args: []const []const u8, command_path: []const u8) anyerror!ArgsType.ArgsType {
    // Check for help flags first and handle them with subcommand context
    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            // Generate help with full command path context
            const help_gen = @import("help.zig");
            const program_name = help_gen.extractProgramName(allocator) catch "program";
            const full_command_path = try std.fmt.allocPrint(allocator, "{s} {s}", .{ program_name, command_path });
            const help_text = try help_gen.formatHelpWithSubcommand(ArgsType, allocator, full_command_path, ArgsType.args_config, null);
            std.debug.print("{s}\n", .{help_text});
            
            // In test mode, return error for test control
            try test_utils.errorIfTest(error.HelpRequested);
            // In normal mode, exit gracefully after displaying help
            std.process.exit(0);
        }
    }
    
    // Parse normally if no help requested
    return ArgsType.parseFrom(allocator, args);
}

/// Validate command hierarchy depth at compile time
fn validateCommandDepth(comptime commands: anytype, comptime current_depth: u32) void {
    if (current_depth > 5) {
        @compileError("Command hierarchy depth cannot exceed 5 levels");
    }
    
    // For now, just validate that we can iterate over the commands
    // Full depth validation will be implemented when we add recursive subcommand support
    inline for (commands) |cmd| {
        if (cmd.command_type == .category) {
            // TODO: Add recursive depth validation for category commands
            // This will be improved once we have proper recursive command definitions
        }
    }
}

/// Create a command structure with automatic depth validation
pub fn Commands(comptime commands: anytype) type {
    // Validate depth at compile time
    validateCommandDepth(commands, 0);
    
    return struct {
        commands: @TypeOf(commands),
        
        const Self = @This();
        
        pub fn init() Self {
            return Self{
                .commands = commands,
            };
        }
        
        /// Parse command-line arguments and execute the appropriate command
        pub fn parse(allocator: std.mem.Allocator) !void {
            const args = try std.process.argsAlloc(allocator);
            defer std.process.argsFree(allocator, args);
            
            // Skip program name
            const cli_args = if (args.len > 0) args[1..] else args;
            return parseFrom(allocator, cli_args);
        }
        
        /// Parse from custom argument array
        pub fn parseFrom(allocator: std.mem.Allocator, args: []const []const u8) !void {
            return parseFromWithPath(allocator, args, "");
        }
        
        /// Parse from custom argument array with command path tracking
        fn parseFromWithPath(allocator: std.mem.Allocator, args: []const []const u8, command_path: []const u8) !void {
            if (args.len == 0) {
                // No subcommand provided, show help
                try showHelp(allocator);
                return;
            }
            
            // Check for help flags first
            if (std.mem.eql(u8, args[0], "--help") or std.mem.eql(u8, args[0], "-h")) {
                try showHelpWithPath(allocator, command_path);
                return;
            }
            
            const command_name = args[0];
            const remaining_args = args[1..];
            
            // Build the new command path
            const new_command_path = if (command_path.len == 0) 
                command_name 
            else 
                try std.fmt.allocPrint(allocator, "{s} {s}", .{ command_path, command_name });
            
            // Find matching command
            inline for (commands) |cmd| {
                if (std.mem.eql(u8, cmd.command_name, command_name)) {
                    if (cmd.command_type == .leaf) {
                        // Execute leaf command with full command path for help
                        const ArgsType = cmd.data.leaf;
                        const parsed_args = parseSubcommandArgs(ArgsType, allocator, remaining_args, new_command_path) catch |err| switch (err) {
                            error.HelpRequested => {
                                // Help was already displayed with subcommand context
                                return;
                            },
                            else => return err,
                        };
                        // Execute handler if present
                        if (cmd.hasHandler()) {
                            try cmd.executeHandler(parsed_args, allocator);
                        }
                        return;
                    } else {
                        // Navigate to category command - delegate to its Commands system with path
                        return parseCategoryCommandWithPath(cmd, allocator, remaining_args, new_command_path);
                    }
                }
            }
            
            // Command not found
            std.debug.print("Error: Unknown command '{s}'\n\n", .{command_name});
            try showHelp(allocator);
        }
        
        /// Show help for this command level
        pub fn showHelp(allocator: std.mem.Allocator) !void {
            return showHelpWithPath(allocator, "");
        }
        
        /// Show help for this command level with command path
        fn showHelpWithPath(allocator: std.mem.Allocator, command_path: []const u8) !void {
            const colors = @import("colors.zig");
            
            // Extract program name
            const help_gen = @import("help.zig");
            const program_name = help_gen.extractProgramName(allocator) catch "program";
            
            // Build full usage line
            const usage_line = if (command_path.len == 0)
                try std.fmt.allocPrint(allocator, "{s} <command> [options]", .{program_name})
            else
                try std.fmt.allocPrint(allocator, "{s} {s} <command> [options]", .{ program_name, command_path });
            
            // Print header
            if (colors.supportsColor()) {
                if (command_path.len == 0) {
                    std.debug.print("\x1b[1;36m{s}\x1b[0m - Subcommand Interface\n\n", .{program_name});
                } else {
                    std.debug.print("\x1b[1;36m{s} {s}\x1b[0m - Subcommand Interface\n\n", .{ program_name, command_path });
                }
                std.debug.print("\x1b[1mUsage:\x1b[0m {s}\n\n", .{usage_line});
                std.debug.print("\x1b[1mAvailable Commands:\x1b[0m\n", .{});
            } else {
                if (command_path.len == 0) {
                    std.debug.print("{s} - Subcommand Interface\n\n", .{program_name});
                } else {
                    std.debug.print("{s} {s} - Subcommand Interface\n\n", .{ program_name, command_path });
                }
                std.debug.print("Usage: {s}\n\n", .{usage_line});
                std.debug.print("Available Commands:\n", .{});
            }
            
            // Find the longest command name for alignment
            var max_name_len: usize = 0;
            inline for (commands) |cmd| {
                if (!cmd.config.hidden) {
                    if (cmd.command_name.len > max_name_len) {
                        max_name_len = cmd.command_name.len;
                    }
                }
            }
            
            // Print commands with proper alignment and colors
            inline for (commands) |cmd| {
                if (!cmd.config.hidden) {
                    const help_text = cmd.config.help orelse "No description available";
                    const padding = max_name_len - cmd.command_name.len + 2;
                    
                    if (colors.supportsColor()) {
                        std.debug.print("  \x1b[32m{s}\x1b[0m", .{cmd.command_name});
                        var i: usize = 0;
                        while (i < padding) : (i += 1) {
                            std.debug.print(" ", .{});
                        }
                        std.debug.print("{s}\n", .{help_text});
                    } else {
                        std.debug.print("  {s}", .{cmd.command_name});
                        var i: usize = 0;
                        while (i < padding) : (i += 1) {
                            std.debug.print(" ", .{});
                        }
                        std.debug.print("{s}\n", .{help_text});
                    }
                }
            }
            
            // Print footer
            if (colors.supportsColor()) {
                std.debug.print("\nUse '\x1b[32m{s} <command> --help\x1b[0m' for more information about a specific command.\n", .{program_name});
            } else {
                std.debug.print("\nUse '{s} <command> --help' for more information about a specific command.\n", .{program_name});
            }
        }
    };
}

/// Automatic struct generator that creates CLI argument structs
/// This creates a struct where metadata is automatically extracted from field definitions
/// Usage: Args(.{ field_definitions, config }) or Args(.{ field_definitions })
pub fn Args(args: anytype) type {
    const args_info = @typeInfo(@TypeOf(args));
    if (args_info == .@"struct" and args_info.@"struct".is_tuple) {
        const fields = args_info.@"struct".fields;
        if (fields.len == 2) {
            // Two arguments: field_definitions and config
            // Convert the anonymous struct to ArgsConfig
            const config = ArgsConfig{
                .title = if (@hasField(@TypeOf(args[1]), "title")) args[1].title else null,
                .description = if (@hasField(@TypeOf(args[1]), "description")) args[1].description else null,
            };
            return ArgsWithConfig(args[0], config);
        } else if (fields.len == 1) {
            // One argument: field_definitions only
            return ArgsWithConfig(args[0], ArgsConfig{});
        } else {
            @compileError("Args() expects 1 or 2 arguments");
        }
    } else {
        // Direct field definitions array
        return ArgsWithConfig(args, ArgsConfig{});
    }
}

/// Internal function that implements the Args generation logic
fn ArgsWithConfig(comptime field_definitions: anytype, comptime config: ArgsConfig) type {
    const field_count = field_definitions.len;
    
    // Extract metadata from field definitions
    const metadata_array = comptime blk: {
        var metadata: [field_count]FieldMetadata = undefined;
        for (field_definitions, 0..) |field_def, i| {
            metadata[i] = field_def.metadata;
        }
        break :blk metadata;
    };
    
    // Create struct fields for each definition using the actual field names from metadata
    const struct_fields = comptime blk: {
        var fields: [field_count]std.builtin.Type.StructField = undefined;
        for (field_definitions, 0..) |field_def, i| {
            // Create a null-terminated string for the field name
            const field_name = field_def.metadata.name;
            const field_name_z = field_name ++ [_]u8{0}; // Add null terminator
            
            fields[i] = std.builtin.Type.StructField{
                .name = field_name_z[0..field_name.len :0], // Create null-terminated slice
                .type = @TypeOf(field_def.value),
                .default_value_ptr = @as(?*const anyopaque, @ptrCast(&field_def.value)),
                .is_comptime = false,
                .alignment = @alignOf(@TypeOf(field_def.value)),
            };
        }
        break :blk fields;
    };
    
    // Generate the struct type using @Type
    const GeneratedStruct = @Type(std.builtin.Type{
        .@"struct" = std.builtin.Type.Struct{
            .layout = .auto,
            .fields = &struct_fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });
    
    // Return a wrapper struct that provides access to the generated struct
    return struct {
        pub const ArgsType = GeneratedStruct;
        
        // AUTOMATIC metadata - NO explicit declaration needed!
        pub const dsl_metadata = &metadata_array;
        
        // Store the configuration
        pub const args_config = config;
        
        // Initialize with defaults
        pub fn init() ArgsType {
            return ArgsType{};
        }
        
        // Direct struct access
        args: ArgsType,
        
        pub fn initFromStruct(s: ArgsType) @This() {
            return @This(){ .args = s };
        }
        
        
        // Method-style API for ergonomic parsing
        /// Parse command-line arguments from process argv
        /// Automatically handles help requests and exits gracefully
        /// NOTE: Use arena allocator for automatic cleanup
        pub fn parse(allocator: std.mem.Allocator) !ArgsType {
            const args = try std.process.argsAlloc(allocator);
            defer std.process.argsFree(allocator, args);
            // Skip the program name (first argument)
            const cli_args = if (args.len > 0) args[1..] else args;
            return parseFrom(allocator, cli_args) catch |err| switch (err) {
                error.HelpRequested => {
                    // In test mode, re-throw the error for test control
                    if (test_utils.isTestMode()) {
                        return err;
                    }
                    // In normal mode, help was already displayed, exit gracefully
                    std.process.exit(0);
                },
                else => {
                    // In test mode, return error for testing
                    if (test_utils.isTestMode()) {
                        return err;
                    }
                    // In normal mode, parser already exited, this should never be reached
                    unreachable;
                },
            };
        }
        
        /// Parse command-line arguments from custom argument array
        /// Automatically handles help requests and exits gracefully
        /// NOTE: Use arena allocator for automatic cleanup
        pub fn parseFrom(allocator: std.mem.Allocator, args: []const []const u8) !ArgsType {
            return parseFromRaw(allocator, args) catch |err| switch (err) {
                error.HelpRequested => {
                    // In test mode, re-throw the error for test control
                    if (test_utils.isTestMode()) {
                        return err;
                    }
                    // In normal mode, help was already displayed, exit gracefully
                    std.process.exit(0);
                },
                else => {
                    // In test mode, return error for testing
                    if (test_utils.isTestMode()) {
                        return err;
                    }
                    // In normal mode, parser already exited, this should never be reached
                    unreachable;
                },
            };
        }
        
        /// Parse command-line arguments from custom argument array (raw version)
        /// Returns HelpRequested error for manual handling - use this only when you need
        /// full control over help behavior (e.g., custom help handlers)
        /// NOTE: Use arena allocator for automatic cleanup
        pub fn parseFromRaw(allocator: std.mem.Allocator, args: []const []const u8) !ArgsType {
            const parser = @import("parser.zig");
            return parser.parseFromWithMeta(ArgsType, @This(), allocator, args);
        }
        
        /// Generate formatted help text for this argument structure
        pub fn help(allocator: std.mem.Allocator) ![]const u8 {
            const help_gen = @import("help.zig");
            // Extract the actual program name from process arguments
            const program_name = help_gen.extractProgramName(allocator) catch "program";
            return help_gen.formatHelpWithConfig(@This(), allocator, program_name, @This().args_config);
        }
        
        /// Validate arguments structure at compile time
        pub fn validate() void {
            const meta = @import("meta.zig");
            return meta.validate(@This());
        }
    };
}


test "automatic DSL" {
    // Automatic DSL: NO explicit metadata declarations needed!
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
        option("count", u32, .{ .short = 'c', .default = 1, .help = "Number of iterations" }),
        required("config", []const u8, .{ .short = 'f', .help = "Configuration file path" }),
    });
    
    // Verify automatic metadata extraction
    const metadata = TestArgs.dsl_metadata;
    try std.testing.expect(metadata.len == 4);
    
    // Verify the metadata is correct
    try std.testing.expectEqualStrings(metadata[0].name, "verbose");
    try std.testing.expect(metadata[0].short.? == 'v');
    try std.testing.expectEqualStrings(metadata[0].help.?, "Enable verbose output");
    
    try std.testing.expectEqualStrings(metadata[1].name, "name");
    try std.testing.expect(metadata[1].short.? == 'n');
    try std.testing.expectEqualStrings(metadata[1].default.?, "World");
    
    try std.testing.expectEqualStrings(metadata[2].name, "count");
    try std.testing.expect(metadata[2].short.? == 'c');
    try std.testing.expectEqualStrings(metadata[2].default.?, "1");
    
    try std.testing.expectEqualStrings(metadata[3].name, "config");
    try std.testing.expect(metadata[3].short.? == 'f');
    try std.testing.expect(metadata[3].required == true);
    
    // Test that the struct works normally
    const args = TestArgs.init();
    // The generated struct has the right type
    try std.testing.expect(@TypeOf(args) == TestArgs.ArgsType);
    
    // We can access fields through the actual struct
    // Note: In practice, the parser would return TestArgs.ArgsType
    const struct_info = @typeInfo(TestArgs.ArgsType).@"struct";
    try std.testing.expect(struct_info.fields.len == 4);
    
    // Test that field names match what we expect
    try std.testing.expectEqualStrings(struct_info.fields[0].name, "verbose");
    try std.testing.expectEqualStrings(struct_info.fields[1].name, "name");
    try std.testing.expectEqualStrings(struct_info.fields[2].name, "count");
    try std.testing.expectEqualStrings(struct_info.fields[3].name, "config");
}

test "method-style API" {
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
        required("config", []const u8, .{ .short = 'c', .help = "Configuration file path" }),
    });
    
    // Test that the method-style API exists and has the right type
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const test_args = &.{"--verbose", "--name", "Alice", "--config", "test.conf"};
    
    // Test parseFrom method with arena allocator (automatic cleanup)
    const result = try TestArgs.parseFrom(allocator, test_args);
    
    // Verify the parsing worked
    try std.testing.expect(result.verbose == true);
    try std.testing.expectEqualStrings(result.name, "Alice");
    try std.testing.expectEqualStrings(result.config, "test.conf");
    
    // Test help method exists
    const help_text = try TestArgs.help(allocator);
    try std.testing.expect(help_text.len > 0);
    
    // Test validate method exists (compile-time check)
    TestArgs.validate();
}

test "help handling API" {
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
    });
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Test parseFromRaw returns HelpRequested error for manual handling
    const help_args = &.{"--help"};
    try std.testing.expectError(error.HelpRequested, TestArgs.parseFromRaw(allocator, help_args));
    
    // Test parseFrom returns HelpRequested error in test mode 
    // (automatic help handling is disabled in tests)
    try std.testing.expectError(error.HelpRequested, TestArgs.parseFrom(allocator, help_args));
    
    // Test normal args work fine
    const normal_args = &.{"--verbose", "--name", "Alice"};
    const result = try TestArgs.parseFrom(allocator, normal_args);
    try std.testing.expect(result.verbose == true);
    try std.testing.expectEqualStrings(result.name, "Alice");
}

test "title and description API" {
    const TestArgs = Args(.{
        &.{
            flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
            option("name", []const u8, .{ .short = 'n', .default = "World", .help = "Name to greet" }),
        },
        .{
            .title = "🚀 Test Application 🚀",
            .description = "A test application with custom title and description.",
        },
    });
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    // Test that the configuration is stored
    try std.testing.expectEqualStrings(TestArgs.args_config.title.?, "🚀 Test Application 🚀");
    try std.testing.expectEqualStrings(TestArgs.args_config.description.?, "A test application with custom title and description.");
    
    // Test help generation includes the custom title and description
    const help_text = try TestArgs.help(allocator);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "🚀 Test Application 🚀") != null);
    try std.testing.expect(std.mem.indexOf(u8, help_text, "A test application with custom title and description.") != null);
}

test "basic subcommand system" {
    // Define some Args types for leaf commands
    const ServeArgs = Args(&.{
        flag("daemon", .{ .short = 'd', .help = "Run as daemon" }),
        option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on" }),
    });
    
    const BuildArgs = Args(&.{
        flag("release", .{ .short = 'r', .help = "Build in release mode" }),
        option("target", []const u8, .{ .short = 't', .default = "native", .help = "Target platform" }),
    });
    
    // Create command definitions
    const serve_cmd = command("serve", ServeArgs, .{ .help = "Start the server" });
    const build_cmd = command("build", BuildArgs, .{ .help = "Build the project" });
    
    // Test command properties
    try std.testing.expectEqualStrings(serve_cmd.command_name, "serve");
    try std.testing.expect(serve_cmd.command_type == .leaf);
    try std.testing.expect(serve_cmd.data.leaf == ServeArgs);
    
    try std.testing.expectEqualStrings(build_cmd.command_name, "build");
    try std.testing.expect(build_cmd.command_type == .leaf);
    try std.testing.expect(build_cmd.data.leaf == BuildArgs);
    
    // Create a Commands system
    const TestCommands = Commands(&.{ serve_cmd, build_cmd });
    
    // Test that the commands system compiles and initializes
    const cmd_system = TestCommands.init();
    try std.testing.expect(cmd_system.commands.len == 2);
}

test "command depth validation" {
    // This should compile fine (depth 0)
    const ServeArgs = Args(&.{
        flag("daemon", .{ .help = "Run as daemon" }),
    });
    
    const cmd = command("serve", ServeArgs, .{ .help = "Start server" });
    const TestCommands = Commands(&.{cmd});
    
    // Should compile without issues
    const cmd_system = TestCommands.init();
    try std.testing.expect(cmd_system.commands.len == 1);
}

test "subcommand help generation" {
    const ServeArgs = Args(&.{
        flag("daemon", .{ .short = 'd', .help = "Run as daemon" }),
        option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on" }),
    });
    
    const BuildArgs = Args(&.{
        flag("release", .{ .short = 'r', .help = "Build in release mode" }),
    });
    
    const serve_cmd = command("serve", ServeArgs, .{ .help = "Start the server" });
    const build_cmd = command("build", BuildArgs, .{ .help = "Build the project" });
    const hidden_cmd = command("internal", ServeArgs, .{ .help = "Internal command", .hidden = true });
    
    const TestCommands = Commands(&.{ serve_cmd, build_cmd, hidden_cmd });
    const cmd_system = TestCommands.init();
    
    // Test that hidden commands are not counted in visible commands
    var visible_count: u32 = 0;
    inline for (cmd_system.commands) |cmd| {
        if (!cmd.config.hidden) {
            visible_count += 1;
        }
    }
    try std.testing.expect(visible_count == 2); // serve and build, not internal
}

test "subcommand parsing simulation" {
    const ServeArgs = Args(&.{
        flag("daemon", .{ .short = 'd', .help = "Run as daemon" }),
        option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on" }),
    });
    
    const serve_cmd = command("serve", ServeArgs, .{ .help = "Start the server" });
    const TestCommands = Commands(&.{serve_cmd});
    
    // Test command detection
    const cmd_system = TestCommands.init();
    const test_command = cmd_system.commands[0];
    
    try std.testing.expectEqualStrings(test_command.command_name, "serve");
    try std.testing.expect(test_command.command_type == .leaf);
    try std.testing.expect(test_command.data.leaf == ServeArgs);
    try std.testing.expectEqualStrings(test_command.config.help.?, "Start the server");
}

test "subcommand help with proper usage line" {
    const ServeArgs = Args(&.{
        flag("daemon", .{ .short = 'd', .help = "Run as daemon" }),
        option("port", u16, .{ .short = 'p', .default = 8080, .help = "Port to listen on" }),
    });
    
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    // Helper function to strip ANSI color codes for testing
    const stripAnsiCodes = struct {
        fn strip(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
            var result = std.ArrayList(u8).init(allocator);
            var i: usize = 0;
            while (i < text.len) {
                if (text[i] == '\x1b' and i + 1 < text.len and text[i + 1] == '[') {
                    // Skip ANSI escape sequence
                    i += 2;
                    while (i < text.len and text[i] != 'm') {
                        i += 1;
                    }
                    if (i < text.len) i += 1; // Skip the 'm'
                } else {
                    try result.append(text[i]);
                    i += 1;
                }
            }
            return result.toOwnedSlice();
        }
    }.strip;
    
    // Test that subcommand help generation includes subcommand name in usage
    const help_gen = @import("help.zig");
    
    // Generate help text with explicit error handling
    const help_text_raw = help_gen.formatHelpWithSubcommand(ServeArgs, arena.allocator(), "testapp", ServeArgs.args_config, "serve") catch |err| {
        std.debug.print("Error generating help with subcommand: {}\n", .{err});
        return err;
    };
    
    // Strip ANSI color codes for testing
    const help_text = try stripAnsiCodes(arena.allocator(), help_text_raw);
    
    // More robust string matching
    const expected_usage = "Usage: testapp serve [OPTIONS]";
    const found_usage = std.mem.indexOf(u8, help_text, expected_usage) != null;
    if (!found_usage) {
        std.debug.print("Expected usage line not found!\n", .{});
        std.debug.print("Looking for: '{s}'\n", .{expected_usage});
        std.debug.print("In text:\n{s}\n", .{help_text});
        if (std.mem.indexOf(u8, help_text, "Usage:")) |usage_idx| {
            const line_start = usage_idx;
            var line_end = line_start;
            while (line_end < help_text.len and help_text[line_end] != '\n') line_end += 1;
            std.debug.print("Actual usage line: '{s}'\n", .{help_text[line_start..line_end]});
        }
    }
    try std.testing.expect(found_usage);
    
    // Test without subcommand context for comparison
    const help_text_normal_raw = help_gen.formatHelpWithSubcommand(ServeArgs, arena.allocator(), "testapp", ServeArgs.args_config, null) catch |err| {
        std.debug.print("Error generating normal help: {}\n", .{err});
        return err;
    };
    
    // Strip ANSI color codes for testing
    const help_text_normal = try stripAnsiCodes(arena.allocator(), help_text_normal_raw);
    
    const expected_normal = "Usage: testapp [OPTIONS]";
    const found_normal = std.mem.indexOf(u8, help_text_normal, expected_normal) != null;
    if (!found_normal) {
        std.debug.print("Expected normal usage line not found!\n", .{});
        std.debug.print("Looking for: '{s}'\n", .{expected_normal});
        std.debug.print("In text:\n{s}\n", .{help_text_normal});
    }
    try std.testing.expect(found_normal);
}

test "command handler functionality" {
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
        option("name", []const u8, .{ .short = 'n', .default = "test", .help = "Name to use" }),
    });
    
    // Create a test handler that sets a flag (using a global variable for testing)
    const TestState = struct {
        var handler_called: bool = false;
        
        fn handle(args: TestArgs.ArgsType, allocator: std.mem.Allocator) !void {
            _ = allocator;
            _ = args;
            handler_called = true;
        }
    };
    
    // Reset the test state
    TestState.handler_called = false;
    
    // Create a command with handler
    const test_cmd = command("test", TestArgs, .{ .help = "Test command", .handler = TestState.handle });
    
    // Test command properties
    try std.testing.expectEqualStrings(test_cmd.command_name, "test");
    try std.testing.expect(test_cmd.command_type == .leaf);
    try std.testing.expect(test_cmd.hasHandler() == true);
    try std.testing.expect(test_cmd.data.leaf == TestArgs);
    
    // Test handler execution
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = TestArgs.ArgsType{ .verbose = true, .name = "Alice" };
    try test_cmd.executeHandler(test_args, arena.allocator());
    
    try std.testing.expect(TestState.handler_called == true);
}

test "command without handler" {
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
    });
    
    // Create a command without handler (using regular command function)
    const test_cmd = command("test", TestArgs, .{ .help = "Test command without handler" });
    
    // Test command properties
    try std.testing.expectEqualStrings(test_cmd.command_name, "test");
    try std.testing.expect(test_cmd.command_type == .leaf);
    try std.testing.expect(test_cmd.hasHandler() == false);
    try std.testing.expect(test_cmd.data.leaf == TestArgs);
    
    // Test that executeHandler does nothing when no handler is present
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    
    const test_args = TestArgs.ArgsType{ .verbose = true };
    // This should not error and should do nothing
    try test_cmd.executeHandler(test_args, arena.allocator());
}

test "handler function type validation" {
    const TestArgs = Args(&.{
        flag("verbose", .{ .short = 'v', .help = "Enable verbose output" }),
    });
    
    // Valid handler function
    const validHandler = struct {
        fn handle(args: TestArgs.ArgsType, allocator: std.mem.Allocator) !void {
            _ = args;
            _ = allocator;
        }
    }.handle;
    
    // This should compile successfully
    const test_cmd = command("test", TestArgs, .{ .help = "Test command", .handler = validHandler });
    try std.testing.expect(test_cmd.hasHandler() == true);
}