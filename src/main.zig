const std = @import("std");
const Io = std.Io;

const FieldsCnt = 19;

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
    no: u8,
    res: ?Resource,
};


const Neighbors: [FieldsCnt][FieldsCnt]bool = blk: {
    var nbr: [FieldsCnt][FieldsCnt]bool = @splat(false);
    const Fnc = struct {
        fn add_nbr(edges: [][2]usize) void {
            for 

            nbr[a][b] = true;
            nbr[b][a] = true;
        }
    };

    Fnc.add_nbr(0, 1);
    Fnc.add_nbr(0, 3);
    Fnc.add_nbr(0, 4);

    break :blk nbr;
};

fn print_map(T: type, fields: *const[19]T) void {
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
        fields[0], fields[1], fields[2], fields[3], fields[4], fields[5],
        fields[6], fields[7], fields[8], fields[9], fields[10], fields[11],
        fields[12], fields[13], fields[14], fields[15], fields[16], fields[17],
        fields[18], 
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

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try stdout_writer.flush(); // Don't forget to flush!

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

