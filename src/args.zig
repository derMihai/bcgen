const std = @import("std");
const errprint = std.debug.print;

pub fn Args(T: type) type {
    return struct {
        pub const ParseError = error { BadName, BadVal, NoName, NoVal, Help };

        // Zig doesn't allow to access type variables at runtime, so we map
        // supported types to an enum.
        const TypesEnum = enum {
            @"u8",
            @"u64",
            @"f32",
            @"switch",
        };

        const arg_names = @typeInfo(T).@"struct".field_names;

        const arg_types = blk: {
            const types = @typeInfo(T).@"struct".field_types;
            var types_i: [types.len]TypesEnum = undefined;
            for (types, &types_i) |t, *ti| switch (t) {
                u8 => ti.* = .@"u8",
                u64 => ti.* = .@"u64",
                f32 => ti.* = .@"f32",
                bool => ti.* = .@"switch",
                else => unreachable,
            };
            break :blk types_i;
        };

        const arg_offsets = blk: {
            var a: [arg_names.len]usize = undefined;
            for (arg_names, &a) |name, *ai| ai.* = @offsetOf(T, name);
            break :blk a;
        };

        fn print_arg_usage(name: [:0]const u8, ty: TypesEnum, inf: [:0]const u8) void {
            var desc_it = std.mem.tokenizeScalar(u8, inf, '\n');
            errprint(
                "--{s:<16} {s:<8} {s}\n", 
                .{
                    name, 
                    if (ty != .@"switch") @tagName(ty) else "", 
                    desc_it.next() orelse "",
                }
            );
            while (desc_it.next()) |desc_line| {
                errprint("{s:<34}{s}\n", .{ "", desc_line});
            }
        }

        fn print_usage(infos: []const[:0]const u8) void {
            errprint("{s:<18} {s:<8} Description\n", .{"Argument", "Value"});
            for (arg_names, arg_types, infos) |name, ty, inf| {
                print_arg_usage(name, ty, inf);
            }
            print_arg_usage("help", .@"switch", "Print help then exit.");
        }

        pub fn parse(pargs: std.process.Args, infos: []const[:0]const u8) ParseError!T {
            var parsed = T{};
            var argl = pargs.iterate();
            const prog = argl.next().?;

            errdefer { 
                errprint("Usage: {s} [--arg [val]]\n" , .{ prog });
                print_usage(infos);
            }

            while (true) {
                const arg = argl.next() orelse break;

                if (!std.mem.eql(u8, arg[0..2], "--")) {
                    errprint("argument '{s}' does not start with '--'\n", .{ arg }); 
                    return ParseError.BadName; 
                }
                if (std.mem.eql(u8, arg[2..], "help")) return ParseError.Help;

                const match_i: usize = for (arg_names, 0..) |name, i| {
                    if (std.mem.eql(u8, arg[2..], name)) break i; 
                } else {
                    errprint("argument '{s}' unknown\n", .{ arg }); 
                    return ParseError.NoName;
                };

                const arg_type = arg_types[match_i];
                const arg_addr = @intFromPtr(&parsed) + arg_offsets[match_i];
                const arg_val_s = if (arg_type != .@"switch") argl.next() orelse 
                {
                    errprint("argument '{s}' expects a value\n", .{ arg }); 
                    return ParseError.NoVal;
                } else null;

                _ = p: switch (arg_type) {
                    .@"u8" => {
                        const vp: *u8 = @ptrFromInt(arg_addr);
                        vp.* = std.fmt.parseInt(u8, arg_val_s.?, 10) catch |e| break :p e;
                    },
                    .@"u64" => {
                        const vp: *u64 = @ptrFromInt(arg_addr);
                        vp.* = std.fmt.parseInt(u64, arg_val_s.?, 10) catch |e| break :p e;
                    },
                    .@"f32" => {
                        const vp: *f32 = @ptrFromInt(arg_addr);
                        vp.* = std.fmt.parseFloat(f32, arg_val_s.?) catch |e| break :p e;
                    },
                    .@"switch" => {
                        const vp: *bool = @ptrFromInt(arg_addr);
                        vp.* = true;
                    },
                } catch |err| {
                    errprint("bad value for argument '{s}': {any}\n", .{ arg, err }); 
                    return ParseError.BadVal;
                };
            }

            return parsed;
        }
    };
}
