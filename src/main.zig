const std = @import("std");
const Io = std.Io;


fn print_map(fields: *const[19][*:0]const u8) void {
    const fmt_s = 
        \\      / \ / \ / \     
        \\     |{s:^3}|{s:^3}|{s:^3}|    
        \\    / \ / \ / \ / \   
        \\   |{s:^3}|{s:^3}|{s:^3}|{s:^3}|  
        \\  / \ / \ / \ / \ / \ 
        \\ |{s:^3}|{s:^3}|{s:^3}|{s:^3}|{s:^3}|
        \\  \ / \ / \ / \ / \ / 
        \\   |{s:^3}|{s:^3}|{s:^3}|{s:^3}|  
        \\    \ / \ / \ / \ /   
        \\     |{s:^3}|{s:^3}|{s:^3}|    
        \\      \ / \ / \ /     
        \\
        ;
    const fields_tuple =  .{ fields[0], fields[1], fields[2], fields[3],
        fields[4], fields[5], fields[6], fields[7], fields[8], fields[9],
        fields[10], fields[11], fields[12], fields[13], fields[14], fields[15],
        fields[16], fields[17], fields[18], 
    };
    std.debug.print(fmt_s, fields_tuple);
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

    const test_array: [19][*:0]const u8 = @splat("o");
    print_map(&test_array);
}

