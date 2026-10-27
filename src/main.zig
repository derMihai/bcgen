const std = @import("std");
const Io = std.Io;

const fields_cnt = 19;
const nbr_max = 6;

var arena: std.mem.Allocator = undefined;

const Resource = enum(u8) {
    Clay,
    Sheep,
    Limestone,
    Grains,
    Wood,
    Desert,

    const enumLen: u8 = @intFromEnum(@This().Desert) + 1;

    fn letter(res: @This()) [*:0]const u8 {
        return @as([enumLen][*:0]const u8, .{ "C", "S", "L", "G", "W", "D" })[@intFromEnum(res)];
    }

    fn cnt(res: @This()) u8 {
        return .cnt_list()[@intFromEnum(res)];
    }
    
    fn cnt_list() [enumLen]u8 {
        return .{3, 4, 3, 4, 4, 1};
    }
};

const Field = struct {
    id: u8,
    no: ?u8 = null,
    res: ?Resource = null,
    nbr: [nbr_max]u8 = undefined,
    nbr_cnt: u8 = undefined,
    const neighbors: [fields_cnt][fields_cnt]bool = blk: {
        var nbr: [fields_cnt][fields_cnt]bool = @splat(@splat(false));
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

    fn init(id: u8) Field {
        var self = Field { .id = id, .nbr_cnt = 0 };
        for (0..fields_cnt) |i| {
            if (neighbors[id][i]) {
                std.debug.assert(self.nbr_cnt < nbr_max);
                self.nbr[self.nbr_cnt] = i;
                self.nbr_cnt += 1;
            }
        }

        return self;
    }

    fn isNbr(self: *const Field, other: *const Field) bool {
        std.debug.assert(self.id < fields_cnt);
        std.debug.assert(other.id < fields_cnt);

        return neighbors[self.id][other.id];
    }

    fn nbrs(self: *const Field) []const u8 {
        return self.nbr[0..self.nbr_cnt];
    }

    pub fn format(self: *const Field, writer: anytype) !void {
        try writer.print("{{ id = {d}, no = {?}, res = {?}, nbrs = {{ ", 
            .{self.id, self.no, self.res});
        for (self.nbrs()) |n| {
            try writer.print("{d}, ", .{ n });
        }

        return writer.print("}}}}", .{});
    }
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
    const fields_tuple =  .{ f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7],
        f[8], f[9], f[10], f[11], f[12], f[13], f[14], f[15], f[16], f[17],
        f[18], };
    std.debug.print(&fmt, fields_tuple);
}

fn print_fields(flds: *[fields_cnt]Field) void {
    var f_str: [fields_cnt][*:0]const u8 = undefined;
    for (flds, 0..) |*f, i| {
        if (f.res == null) {
            f_str[i] = "";
        }
        else {
            f_str[i] = f.res.?.letter();
        }
    }

    print_map(@TypeOf(f_str[0]), &f_str);
}

fn pick_resource(available: *const [Resource.enumLen]i8) ?Resource {
    const ResOpt = struct {
        res: Resource,
        cnt: u8,

        fn more_than(_: void, lhs: @This(), rhs: @This()) bool {
            return lhs.cnt > rhs.cnt;
        }
    };
    var opt_a: [Resource.enumLen]ResOpt = undefined;
    var opts = std.ArrayListUnmanaged(ResOpt).initBuffer(&opt_a);

    for (available, 0..) |cnt, i| {
        if (cnt <= 0) continue;
        (opts.addOneBounded() catch unreachable).* = 
            ResOpt{ .cnt = @intCast(cnt), .res = @enumFromInt(i) };
    }

    if (opts.items.len == 0) return null;

    std.Random.shuffle(random.random(), ResOpt, opts.items);
    // block is stable
    // std.sort.block(ResOpt, opts.items, {}, ResOpt.more_than);
    // std.debug.print("{any}\n", .{opts.items});
    return opts.items[0].res;
}

fn set_resource(field: *Field, res_available: *[Resource.enumLen]i8, res: Resource) void
{
    field.res = res;
    res_available[@intFromEnum(res)] -= 1;
    std.debug.assert(res_available[@intFromEnum(res)] >= 0);
}

fn assign_resource(fields: *[fields_cnt]Field, field: u8, res_available: *[Resource.enumLen]i8) u32 {
    var clumps: u32 = 0;
    var f = &fields[field];
    var res_candidates: [Resource.enumLen]i8 = res_available.*;

    // std.debug.print("Field {d}:\n", .{f.id});
    // std.debug.print("{any}\n", .{f.nbrs()});
    for (f.nbrs()) |ni| {
        const nbr = fields[ni];
        // std.debug.print("nbr has {?}\n", .{nbr.res});
        if (nbr.res != null) res_candidates[@intFromEnum(nbr.res.?)] = 0;
    }

    const res = pick_resource(&res_candidates) orelse blk: {
        // std.debug.print("field {d}, no unique resources left!\n", .{ f.id });
        clumps += 1;
        break :blk pick_resource(res_available).?;
    };

    set_resource(f, res_available, res);

    return clumps;
}

fn assign_resources(fields: *[fields_cnt]Field, res_available: *[Resource.enumLen]i8) u32 {
    const fp = blk: {
        var _fp: [fields_cnt]*Field = undefined;
        for (0..fields_cnt) |i| _fp[i] = &fields[i];
        std.Random.shuffle(random.random(), *Field, &_fp);
        break :blk _fp;
    };

    var clumps: u32 = 0;
    for (fp) |field| {
        if (field.res != null) continue;
        clumps += assign_resource(fields, field.id , res_available);
    }

    return clumps;
}


pub fn main(init: std.process.Init) !void {
    // This is appropriate for anything that lives as long as the process.
    arena = init.arena.allocator();

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

    const fields: [fields_cnt]Field = comptime blk: {
        var _fields: [fields_cnt]Field = undefined;
        for (0..fields_cnt) |i| _fields[i] = Field.init(i);
        break :blk _fields;
    };

    const res_assign_attempts = 16;

    for (0..res_assign_attempts) |_|{
        var res_available: [Resource.enumLen]i8 = 
            @as(*const [Resource.enumLen]i8, @ptrCast(&Resource.cnt_list())).*;
        var fields_copy = fields;

        const clumps = assign_resources(&fields_copy, &res_available);
        for (res_available) |cnt| std.debug.assert(cnt == 0);
        if (clumps == 0) {
            print_fields(&fields_copy);
            std.debug.print("clumps = {d}\n", .{ clumps });
            break;
        }
    } else {
        std.debug.print("Cannot create map with seed {d}\n", .{ seed });
    }
}

