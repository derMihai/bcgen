const std = @import("std");
const Io = std.Io;

const fields_cnt = 19;

const Resource = enum(u8) {
    Clay,
    Sheep,
    Limestone,
    Grains,
    Wood,
    Desert,
};

const Field = struct {
    id: u8,
    no: ?u8 = null,
    res: ?Resource = null,
    const neighbors: [fields_cnt][fields_cnt]bool = blk: {
        var nbr: [fields_cnt][fields_cnt]bool = @splat(false);
        const edges = [_][2]u8 {
            .{0, 1}, .{0, 4}, .{0, 3},
            .{1, 4}, .{1, 5}, .{1, 2},
            .{2, 5}, .{2, 6},
            .{3, 4}, .{3, 8}, .{3, 7},
            .{4, 5}, .{4, 9}, .{4, 8},
            .{5, 6}, .{5, 10}, .{5, 9},
            .{6, 11}, .{6, 10},
            .{7, 8}, .{7, 12}, .{7, 12},
            .{8, 9}, .{8, 13}, .{8, 12},
            .{9, 10}, .{9, 14}, .{9, 13},
            .{10, 11}, .{10, 15}, .{10, 14},
            .{11, 15},
            .{12, 13}, .{12, 16},
            .{13, 14}, .{13, 17}, .{13, 16},
            .{14, 15}, .{14, 18}, .{14, 17},
            .{15, 18},
            .{16, 17},
            .{17, 18},
        };

        for (edges) |edge| {
            nbr[edge[0]][edge[1]] = true;
            nbr[edge[1]][edge[0]] = true;
        }

        break :blk nbr;
    };

    fn isNbr(self: Field, other: Field) bool {
        std.debug.assert(self.id < fields_cnt);
        std.debug.assert(other.id < fields_cnt);

        return neighbors[self.id][other.id];
    }
};

var fields: [fields_cnt]Field = blk: {
    var _fields: [fields_cnt]Field = undefined;
    for (0..fields_cnt) |i| _fields[i] = Field { .id = i };
    break :blk _fields;
};

var random: std.Random.DefaultPrng = undefined;

fn print_map(T: type, f: *const[19]T) void {
    const fmt_proto = 
        \\      / \ / \ / \     
        \\     |{#:^3}|{#:^3}|{#:^3}|    
        \\    / \ / \ / \ / \   
        \\   |{#:^3}|{#:^3}|{#:^3}|{#:^3}|  
        \\  / \ / \ / \ / \ / \ 
        \\ |{#:^3}|{#:^3}|{#:^3}|{#:^3}|{#:^3}|
        \\  \ / \ / \ / \ / \ / 
        \\   |{#:^3}|{#:^3}|{#:^3}|{#:^3}|  
        \\    \ / \ / \ / \ /   
        \\     |{#:^3}|{#:^3}|{#:^3}|    
        \\      \ / \ / \ /     
        \\
        ;

    const fmt: [fmt_proto.len]u8 = comptime blk: {
        var fmt_buf: [fmt_proto.len]u8 = fmt_proto.*;
        const directive = switch (T) {
            u8 => 'd',
            [*:0]const u8 => 's',
            else => unreachable,
        };
        std.mem.replaceScalar(u8, &fmt_buf, '#', directive);

        break :blk fmt_buf;
    };
    // there's no way around this until std.meta.Tuple gets fixed
    const fields_tuple =  .{ 
        f[0], f[1], f[2], f[3], f[4], f[5],
        f[6], f[7], f[8], f[9], f[10], f[11],
        f[12], f[13], f[14], f[15], f[16], f[17],
        f[18], 
    };
    std.debug.print(&fmt, fields_tuple);
}

pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;
    var seed: u64 = undefined;
    io.random(@as(*[8]u8, @ptrCast(&seed)));
    random = std.Random.DefaultPrng.init(seed);

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush(); // Don't forget to flush!

    var fp = comptime blk: {
        var _fp: [fields_cnt]*Field = undefined;
        for (0..fields_cnt) |i| _fp[i] = &fields[i];
        break :blk _fp;
    };

    std.Random.shuffle(random, *Field, &fp);


    const test_array_s: [19][*:0]const u8 = @splat("o");
    const test_array_d: [19]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 };
    print_map(@TypeOf(test_array_s[0]), &test_array_s);
    print_map(@TypeOf(test_array_d[0]), &test_array_d);

    // const fmt = "{{{c}}}";
    // comptime var fmt_s_buf: [fmt.len + 1]u8 = undefined;
    // _ = comptime try std.mem.print(&fmt_s_buf, fmt, .{ '8' });
    // // fmt_s_buf[result.len] = 0;
    //
    // std.debug.print("{s}", .{ @as([*:0]const u8, fmt_s_buf)});
}

