const std = @import("std");
const Io = std.Io;
const Vec = @import("vec.zig").Vec;
const Args = @import("args.zig").Args;

const doc = 
\\
\\bcgen - the balanced (and better) Catan map generator!
\\
\\Generates a randomized Catan board with balanced resource spread and yields.
\\Losing is now purely due to skill issues!
\\
\\TL;DR:
\\ Run this program, try again if it fails.
\\
\\Glossary:
\\ - Field: a hexagon tile that holds a resource
\\ - Zone: a cluster of three fields neighboring each other, i.e. any three
\\   fields that can be occupied by one settlement. There are 23 of them.
\\ - Yield number: the numbers (2 to 12) placed on a field
\\ - Field yield: the expected number of resources a yield number gives on a
\\   dice roll, i.e. the probability of rolling that number:
\\    2, 12:  1/30 ~ 0.033
\\    3, 11:  2/30 ~ 0.067
\\    4, 10:  3/30 ~ 0.1
\\    5,  9:  4/30 ~ 0.133
\\    6,  8:  5/30 ~ 0.167
\\   For internal calculations, the yield of the Desert field is 0.1.
\\ - Zone yield: the sum of the yields in a zone. Ranges between 4/30 (i.e. 
\\   2, 12, 3) and 15/30 (i.e. 6, 6, 8).
\\ - Resource yield: the sum of the yields of all the fields sharing the same
\\   resource, divided by the number of fields. E.g. for Clay with yield 
\\   numbers 2, 3, 10 this is (1 + 2 + 3) / 30 / 3 = 0.1;
\\ - Clump: a pair of neighboring fields sharing the same resource.
\\
\\How it works:
\\ The generation takes place in three steps:
\\  1. Field resource assignment with spread balancing. The resources are
\\     disitributed s.t. no clumps are formed (i.e. no neighboring fields share 
\\     the same resource.
\\  2. Field yield number assignment with zone yield balancing. The yield 
\\     numbers are distributed randomly, then they are swapped until the 
\\     difference between the lowest and the highest zone yields is less or
\\     equal to `--max-zdiff`. To avoid clustering of either high or low yields 
\\     around the Desert field, its yield is set to the fixed mean value of 3. 
\\     If this step fails, start over from 1.
\\  3. Resource yield balancing. Resources are swapped until the difference
\\     between the lowest and the highest resource yields is lower or equal
\\     to `--max-rdiff`. If this step fails, or if at the end the number of
\\     clumps is larger than `--max-clumps`, start over from 1.
\\ 
\\ The number of attempts is capped and the program will fail on exhaustion. Try 
\\ again with a different seed or relax the constraints.
;

pub const std_options: std.Options = .{
    .log_level = .debug,
    .logFn = stderr_print,
};

var log_level = std.log.Level.info;

pub fn stderr_print(
    comptime level: std.log.Level,
    comptime _: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(level) <= @intFromEnum(log_level)) {
        std.debug.print(format, args);
    }
}

const loge = std.log.err;
const logi = std.log.info;
const logd = std.log.debug;

const assert = std.debug.assert;

const Resource = enum(u8) {
    Clay,
    Sheep,
    Minerals,
    Grains,
    Wood,
    Desert,

    const enumLen: u8 = @intFromEnum(@This().Desert) + 1;

    fn letter(res: @This()) [:0]const u8 {
        // const letter_a = [enumLen][:0]const u8 { "C", "S", "M", "G", "W", "D" };
        const letter_a = [enumLen][:0]const u8 { "🧱", "🐑", "🪨", "🌾", "🌲", "🪾" };
        return letter_a[@intFromEnum(res)];
    }

    fn cnt(res: @This()) u8 {
        return .cnt_list()[@intFromEnum(res)];
    }
    
    fn cnt_list() [enumLen]u8 {
        return .{3, 4, 3, 4, 4, 1};
    }
};

const YieldNo = struct {
    no: u8 = undefined,
    cnt: u8 = undefined,
    yield: u8 = undefined,
    
    const yields = [_]YieldNo {
        YieldNo{ .no =  2, .cnt = 1, .yield = 1 },
        YieldNo{ .no = 12, .cnt = 1, .yield = 1 },
        YieldNo{ .no =  3, .cnt = 2, .yield = 2 },
        YieldNo{ .no = 11, .cnt = 2, .yield = 2 },
        YieldNo{ .no =  4, .cnt = 2, .yield = 3 },
        YieldNo{ .no = 10, .cnt = 2, .yield = 3 },
        YieldNo{ .no =  5, .cnt = 2, .yield = 4 },
        YieldNo{ .no =  9, .cnt = 2, .yield = 4 },
        YieldNo{ .no =  6, .cnt = 2, .yield = 5 },
        YieldNo{ .no =  8, .cnt = 2, .yield = 5 },
    };
    const yieldno_cnt: u8 = yields.len;
    const yield_space = 30; // possible ways to roll two dices
    const yield_sum = blk: {
        var sum: u8 = 0;
        for (yields) |y| sum += y.cnt * y.yield;
        break :blk sum;
    };

    fn desert() @This() { 
        return @This(){ 
            .no = 0, 
            .cnt = 1, 
            .yield = @round(@as(f32, yield_sum) / FieldMap.res_fields_cnt),
        }; 
    }
};

const Field = struct {
    id: u8,
    yield_no: ?YieldNo = null,
    res: ?Resource = null,
    nbr: Vec(u8, nbr_max) = Vec(u8, nbr_max) {},
    
    const nbr_max = 6;

    fn init(id: u8, neighbors: []const u8) Field {
        return Field { .id = id, .nbr = Vec(u8, nbr_max).init(neighbors) };
    }

    fn nbrs(self: *const Field) []const u8 {
        return self.nbr.span();
    }

    pub fn format(self: *const @This(), writer: anytype) !void {
        try writer.print("{{ id = {d}, no = {?}, res = {?}, nbrs = {{ ", 
            .{self.id, self.yield_no, self.res});
        for (self.nbrs()) |n| {
            try writer.print("{d}, ", .{ n });
        }

        return writer.print("}}}}", .{});
    }

    fn yield(self: *const @This()) ?u8 {
        return if (self.yield_no != null) self.yield_no.?.yield else null;
    }
};

const FieldMap = struct {
    fields: [fields_cnt]Field,

    const fields_cnt = 19;
    const res_fields_cnt = fields_cnt - 1;
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
    // const Map = [fields_cnt]Field;
    const PMap = [fields_cnt]*Field;

    fn init(map: *FieldMap) void {
        const empty_fields = blk: {
            var _fields: [fields_cnt]Field = undefined;
            for (0..fields_cnt) |id| {
                var nbrs = Vec(u8, Field.nbr_max) {};
                for (0..fields_cnt) |ni| {
                    if (neighbors[id][ni]) { 
                        nbrs.push(@intCast(ni)) catch unreachable;
                    }
                }
                _fields[id] = Field.init(@intCast(id), nbrs.span());
            }
            break :blk _fields;
        };
        map.fields = empty_fields;
    }
    
    fn pointer_map(map: *@This()) PMap {
        var pmap: PMap = undefined;
        for (&map.fields, &pmap) |*f, *fp| fp.* = f;
        return pmap;
    }

    fn clumps(map: *const @This()) u8 {
        var c: u8 = 0;
        for (&map.fields) |*f| {
            for (f.nbrs()) |n| {
                const f_res = f.res orelse break;
                const n_res = map.fields[n].res orelse continue;
                if (f_res == n_res) c += 1;
            }
        }
        return c / 2;
    }

    fn center(map: *@This()) *Field {
        return &map.fields[9];
    }
};

const Zone = struct {
    fields: [zone_size]*Field = undefined,

    const zone_size = 3;

    fn yield(self: *const Zone) u8 {
        var sum: u8 = 0;
        for (self.fields) |f| sum += f.yield().?;
        return sum;
    }

    fn less_than(_: void, lhs: *const @This(), rhs: *const @This()) bool {
        return lhs.yield() < rhs.yield();
    }

    fn balance(za: *const @This(), zb: *const @This()) void {
        const lesser, const greater = 
            if (za.yield() <= zb.yield()) .{ za, zb } else .{ zb, za };

        var min: *Field = lesser.fields[0];
        if (min.res == .Desert) min = lesser.fields[1];
        var max: *Field = greater.fields[0];
        if (max.res == .Desert) max = greater.fields[1];

        for (lesser.fields[1..], greater.fields[1..]) |lf, gf| {
            if (lf.yield().? < min.yield().? and lf.res != .Desert) min = lf;
            if (gf.yield().? > max.yield().? and gf.res != .Desert) max = gf;
        }

        const tmp = min.yield_no;
        min.yield_no = max.yield_no;
        max.yield_no = tmp;
    }
};

const ZoneMap = struct {
    zones: [zones_cnt]Zone = undefined,

    const zone_mat = [_][Zone.zone_size]u8 {
        [_]u8{ 3, 0, 4 },
        [_]u8{ 0, 4, 1 },
        [_]u8{ 4, 1, 5 },
        [_]u8{ 1, 5, 2 },
        [_]u8{ 5, 2, 6 },
        [_]u8{ 7, 3, 8 },
        [_]u8{ 3, 8, 4 },
        [_]u8{ 8, 4, 9 },
        [_]u8{ 4, 9, 5 },
        [_]u8{ 9, 5, 10 },
        [_]u8{ 5, 10, 6 },
        [_]u8{ 10, 6, 11 },
        [_]u8{ 7, 12, 8 },
        [_]u8{ 12, 8, 13 },
        [_]u8{ 8, 13, 9 },
        [_]u8{ 13, 9, 14 },
        [_]u8{ 14, 10, 15 },
        [_]u8{ 10, 15, 11 },
        [_]u8{ 12, 16, 13 },
        [_]u8{ 16, 13, 17 },
        [_]u8{ 13, 17, 14 },
        [_]u8{ 17, 14, 18 },
        [_]u8{ 14, 18, 15 },
    };
    const zones_cnt = zone_mat.len;

    fn init(map: *@This(), fmap: *FieldMap) void {
        for (&map.zones, 0..) |*zone, i| {
            zone.* = Zone { 
                .fields = [_]*Field { 
                    &fmap.fields[zone_mat[i][0]],
                    &fmap.fields[zone_mat[i][1]],
                    &fmap.fields[zone_mat[i][2]]
                } 
            };
        }
    }
};

const ResYield = struct {
    res: Resource,
    flds: Vec(*Field, 4) = .{},

    fn init(res: Resource, fmap: *FieldMap) @This() {
        var self = @This() { .res = res };

        for (&fmap.fields) |*f| {
            if (f.res == res)  {
                self.flds.push(f) catch unreachable;
            }
        }

        return self;
    }

    fn yield(self: *const @This()) u8 {
        var y: u8 = 0;
        for (self.flds.span()) |f| y += f.yield().?;
        return y;
    }

    fn yield_norm(self: *const @This()) f32 {
        return @as(f32, self.yield()) / @as(u8, @intCast(self.flds.len));
    }

    fn less_than(_: void, lhs: *const @This(), rhs: *const @This()) bool {
        return lhs.yield_norm() < rhs.yield_norm();
    }

    fn balance(self: *@This(), other: *@This()) void {
        const greater, const lesser = if (self.yield_norm() >= other.yield_norm()) 
            .{self, other} else .{other, self};

        var gfp = &greater.flds.span_mut()[0];
        var lfp = &lesser.flds.span_mut()[0];
        for (greater.flds.span_mut()[1..]) |*f| {
            if (f.*.yield().? > gfp.*.yield().?) gfp = f;
        }
        for (lesser.flds.span_mut()[1..]) |*f| {
            if (f.*.yield().? < lfp.*.yield().?) lfp = f;
        }

        const tmp = gfp.*.res;
        gfp.*.res = lfp.*.res;
        lfp.*.res = tmp;

        const tmpp = gfp.*;
        gfp.* = lfp.*;
        lfp.* = tmpp;
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
        // in case of string it's UTF emojis. They render 1-char wide, but the 
        // formatter doesn't understand that.
        if (directive == 's') std.mem.replaceScalar(u8, &fmt_buf, '3', '5');
        break :blk fmt_buf;
    };
    // there's no way around this until std.meta.Tuple gets fixed
    const fields_tuple =  .{ f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7],
        f[8], f[9], f[10], f[11], f[12], f[13], f[14], f[15], f[16], f[17],
        f[18], };
    logi(&fmt, fields_tuple);
}

fn print_fields(fmap: *const FieldMap) void {
    var f_str: [FieldMap.fields_cnt][*:0]const u8 = undefined;
    for (&fmap.fields, 0..) |*f, i| {
        f_str[i] = if (f.res != null) f.res.?.letter() else ""; 
    }

    print_map(@TypeOf(f_str[0]), &f_str);

    var f_yield_no: [FieldMap.fields_cnt]u8 = undefined;
    for (&fmap.fields, 0..) |*f, i| {
        if ((f.res == null) or (f.res.? == Resource.Desert) or (f.yield_no == null)) {
            f_yield_no[i] = 0;
        }
        else {
            f_yield_no[i] = f.yield_no.?.no;
        }
    }

    print_map(@TypeOf(f_yield_no[0]), &f_yield_no);
}

fn print_stats(fmap: *FieldMap, zdiff: f32, rdiff: f32) void {
    var res_yields = blk: {
        var a: [Resource.enumLen - 1]ResYield = undefined;
        for (0..Resource.enumLen - 1) |ri| a[ri] = ResYield.init(@enumFromInt(ri), fmap);
        break :blk a;
    };

    logi("clumps               = {d}\n", .{ fmap.clumps() });
    logi("zone diff            = {d:.3}\n", .{ zdiff });
    logi("resource diff (norm) = {d:.3}\n", .{ rdiff });

    logi("Resource yield:\n", .{});
    logi("  {s:<10} {s:>5} {s:>11}\n", .{"res", "yield", "norm yield"});
    for (@typeInfo(Resource).@"enum".field_names[0..Resource.enumLen - 1], 0..) |n, i| {
        logi("  {s:<10} {d:>5.2} {d:>11.3}\n", .{ 
            n, 
            @as(f32, res_yields[i].yield()) / YieldNo.yield_space, 
            res_yields[i].yield_norm() / YieldNo.yield_space,
        });
    }

    logi("Field yields (nominator):\n", .{});
    var f_yield: [FieldMap.fields_cnt]u8 = undefined;
    for (&fmap.fields, 0..) |*f, i| {
        if ((f.res == null) or (f.yield_no == null)) {
            f_yield[i] = 0;
        }
        else {
            f_yield[i] = f.yield_no.?.yield;
        }
    }

    print_map(@TypeOf(f_yield[0]), &f_yield);
}

fn pick_resource(available: *const [Resource.enumLen]i8) ?Resource {
    const ResOpt = struct { res: Resource, cnt: u8, };
    var opts = Vec(ResOpt, Resource.enumLen){};

    for (available, 0..) |cnt, i| if (cnt > 0) {
         opts.push(ResOpt{ .cnt = @intCast(cnt), .res = @enumFromInt(i) }) 
             catch unreachable;
    };

    if (opts.len == 0) return null;

    return opts.span()[
        std.Random.uintAtMost(random.random(), usize, opts.len - 1)
    ].res;
}

fn set_resource(field: *Field, res_available: *[Resource.enumLen]i8, res: Resource) void
{
    field.res = res;
    res_available[@intFromEnum(res)] -= 1;
    assert(res_available[@intFromEnum(res)] >= 0);
}

fn assign_resource(fmap: *FieldMap, field: *Field, 
                   res_available: *[Resource.enumLen]i8) u32 {
    var clumps: u32 = 0;
    var res_candidates: [Resource.enumLen]i8 = res_available.*;

    for (field.nbrs()) |ni| {
        const nbr = fmap.fields[ni];
        if (nbr.res != null) res_candidates[@intFromEnum(nbr.res.?)] = 0;
    }

    const res = pick_resource(&res_candidates) orelse blk: {
        clumps += 1;
        break :blk pick_resource(res_available).?;
    };

    set_resource(field, res_available, res);

    return clumps;
}

fn assign_resources(fmap: *FieldMap, res_available: *[Resource.enumLen]i8) u32 {
    var fp = fmap.pointer_map();
    std.Random.shuffle(random.random(), *Field, &fp);

    var clumps: u32 = 0;
    for (fp) |field| {
        if (field.res != null) continue;
        clumps += assign_resource(fmap, field , res_available);
    }

    return clumps;
}

fn assign_yields(fmap: *FieldMap, max_diff: f32) f32 {
    const yields_nos = blk: {
        var a: [FieldMap.res_fields_cnt]YieldNo = undefined;
        var i: u8 = 0;
        for (YieldNo.yields) |yield| {
            for (0..yield.cnt) |_| {
                a[i] = yield;
                i += 1;
            }
        }
        break :blk a;
    };

    var zone_map: ZoneMap = undefined;
    zone_map.init(fmap);

    var diff: f32 = 0;

    for (0..1024) |_| {
        var fp = fmap.pointer_map();
        std.Random.shuffle(random.random(), *Field, &fp);

        var yi: u8 = 0;
        for (fp) |field| {
            assert(field.res != null);
            if (field.res == Resource.Desert) {
                field.yield_no = YieldNo.desert();
                continue;
            }
            field.yield_no = yields_nos[yi];
            yi += 1;
        }

        var zp = blk: {
            var a: [ZoneMap.zones_cnt]*const Zone = undefined;
            for (&zone_map.zones, &a) |*p, *ap| ap.* = p;
            break :blk a;
        };
        for (0..16) |_| {
            const zmin = std.sort.min(*const Zone, &zp, {}, Zone.less_than).?;
            const zmax = std.sort.max(*const Zone, &zp, {}, Zone.less_than).?;

            diff = @as(f32, zmax.yield() - zmin.yield()) / YieldNo.yield_space;
            if (diff <= max_diff) {
                return diff;
            }

            Zone.balance(zmin, zmax);
        }
    } 

    return diff;
}

fn balance_res_yields(fmap: *FieldMap, max_diff: f32) f32 {
    var res_yields = blk: {
        var a: [Resource.enumLen - 1]ResYield = undefined;
        for (0..Resource.enumLen - 1) |ri| a[ri] = ResYield.init(@enumFromInt(ri), fmap);
        break :blk a;
    };

    var ryp = blk: {
        var a: [Resource.enumLen - 1]*ResYield = undefined;
        for (&res_yields, &a) |*res, *dest| dest.* = res;
        break :blk a;
    };
    std.sort.block(*ResYield, &ryp, {}, ResYield.less_than);

    const attempts: u8 = 10;
    var diff: f32 = undefined;
    for (0..attempts) |_| {
        std.sort.block(*ResYield, &ryp, {}, ResYield.less_than);

        diff = (ryp[ryp.len - 1].yield_norm() - ryp[0].yield_norm()) / 
            YieldNo.yield_space;
        if (diff <= max_diff) {
            break;
        }
        ryp[0].balance(ryp[ryp.len - 1]);
        std.sort.block(*ResYield, &ryp, {}, ResYield.less_than);
    }

    return diff;
}

pub fn main(init: std.process.Init) !void {
    const BcgenArgs = struct {
        @"max-clumps": u8 = 1,
        @"mid-desert": bool = false,
        seed: u64 = 0,
        @"max-zdiff": f32 = 0.1,
        @"max-rdiff": f32 = 0.02,
        stats: bool = false,
        verbose: bool = false,
    };
    const infos = [_][:0]const u8 {
        \\Max clumps allowed, default 1.
        ,
        \\Desert is always in the middle.
        ,
        \\Use a fixed seed value.
        ,
        \\Max difference between the lowest and highest 
        \\zone yield. Default 0.1. 
        ,
        \\Max difference between the lowest and highest
        \\resource yield (normalized). Default 0.02.
        ,
        \\Print stats.
        ,
        \\Print debug logs.
        ,
    };

    const args = Args(BcgenArgs).parse(init.minimal.args, &infos) catch |err| {
        if (err == Args(BcgenArgs).ParseError.Help) logi("{s}\n", .{ doc });
        return {};
    };
    if (args.verbose) log_level = std.log.Level.debug;

    const io = init.io;
    var seed: u64 = args.seed;
    if (seed == 0) io.random(@as(*[8]u8, @ptrCast(&seed)));

    logi("generating with seed {d}...\n", .{ seed });

    random = std.Random.DefaultPrng.init(seed);

    const res_assign_attempts = 64;
    const map_attempts = 64;

    for (0..map_attempts) |_|{
        var res_available: [Resource.enumLen]i8  = undefined;
        var fmap: FieldMap = undefined;
        for (0..res_assign_attempts) |_| {
            res_available = @as(*const [Resource.enumLen]i8, @ptrCast(&Resource.cnt_list())).*;
            fmap.init();

            if (args.@"mid-desert") {
                set_resource(fmap.center(), &res_available, .Desert);
            }

            const clumps = assign_resources(&fmap, &res_available);
            if (clumps == 0) break;
        } else {
            logd("Can't assign rssources: clumps = {d}\n", .{fmap.clumps()});
            continue;
        }

        for (res_available) |cnt| assert(cnt == 0);

        const zdiff = assign_yields(&fmap, args.@"max-zdiff");
        if (zdiff > args.@"max-zdiff") { 
            logd("Can't assign yields: diff = {d}\n", .{ zdiff });
            continue;
        }

        const rdiff = balance_res_yields(&fmap, args.@"max-rdiff");
        if (rdiff > args.@"max-rdiff") {
            logd("Can't balance res yields: bal_diff = {d}\n", .{ rdiff });
            continue;
        }

        const clumps = fmap.clumps();
        if (clumps > args.@"max-clumps") {
            logd("clumps too high after balancing = {d}\n", .{ clumps });
            continue;
        }

        print_fields(&fmap);
        if (args.stats) print_stats(&fmap, zdiff, rdiff);

        break;
    } else {
        logi("Cannot create map! Try relaxing the constraints or with another seed!\n", .{});
    }
}
