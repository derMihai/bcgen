const std = @import("std");
const Io = std.Io;

const fields_cnt = 19;
const res_fields_cnt = fields_cnt - 1;
const yield_space = 58;
const nbr_max = 6;
const max_zone_yield_diff = 4;
const max_res_yield_diff = 0.75;
const clumps_max_after_balance = 1;

fn Vec(T: type, comptime size: usize) type {
    return struct {
        a: [size]T = undefined,
        len: usize = 0,

        const Error = error { Full };

        fn init(slice: []const T) @This() {
            const range = @min(slice.len, size);

            var self: @This() = .{};
            for (slice[0..range], &self.a) |item, *dest| dest.* = item;
            self.len = range;

            return self;
        }

        fn span(self: *const @This()) []const T {
            return self.a[0..self.len];
        }

        fn span_mut(self: *@This()) []T {
            return self.a[0..self.len];
        }

        fn push(self: *@This(), item: T) Error!void {
            if (self.len == size) return Error.Full;
            self.a[self.len] = item;
            self.len += 1;
        }
    };
}

test "Vec" {
    var va = Vec(u8, 3){};

    try std.testing.expectEqual(va.len, 0);
    try std.testing.expectEqual(va.span().len, 0);
    try std.testing.expectEqual(va.a.len, 3);

    try va.push(1);
    try va.push(2);

    try std.testing.expectEqual(va.span().len, 2);

    try va.push(3);

    try std.testing.expectError(Vec(u8, 3).Error.Full, va.push(4));

    for (va.span(), 1..) |item, i| try std.testing.expectEqual(item, i);

    var vb = Vec(u8, 4).init(&[_]u8 {1, 2, 3, 4, 5});
    try std.testing.expectEqual(4, vb.span().len);

    try std.testing.expectEqual(vb.span().len, 4);
    for (vb.span(), 1..) |item, i| try std.testing.expectEqual(item, i);
}

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

    fn expected_yield(res: @This()) f32 {
        const yield: [enumLen]f32 = comptime blk: {
            var a: [enumLen]u8 = undefined;
            for (0..enumLen - 1) |i| {
                a[i] = (@as(f32, yield_space) / res_fields_cnt) * cnt(@enumFromInt(i));
            }
            a[enumLen - 1] = 0;
            break :blk a;
        };

        return yield[@intFromEnum(res)];
    }
};

const Yield = struct {
    no: u8 = undefined,
    // yield: u8 = undefined,
    cnt: u8 = undefined,
    const yield_vals_cnt: u8 = 10;

    fn yield(no: u8) u8 {
        return switch (no) {
             0 => @round(@as(f32, yield_space) / res_fields_cnt),
             2 => 1,
            12 => 1,
             3 => 2,
            11 => 2,
             4 => 3,
            10 => 3,
             5 => 4,
             9 => 4,
             6 => 5,
             8 => 5,
             else => unreachable,
        };
    }
};

const g_yields: [Yield.yield_vals_cnt]Yield = .{
    Yield{ .no =  2, .cnt = 1 },
    Yield{ .no = 12, .cnt = 1 },
    Yield{ .no =  3, .cnt = 2 },
    Yield{ .no = 11, .cnt = 2 },
    Yield{ .no =  4, .cnt = 2 },
    Yield{ .no = 10, .cnt = 2 },
    Yield{ .no =  5, .cnt = 2 },
    Yield{ .no =  9, .cnt = 2 },
    Yield{ .no =  6, .cnt = 2 },
    Yield{ .no =  8, .cnt = 2 },
};

const Field = struct {
    id: u8,
    yield_no: ?u8 = null,
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

    fn nbrs_common(self: *const Field, other: *const Field, storage: *[nbr_max]u8) []const u8 {
        var nbr_cnt: u8 = 0;
        for (self.nbrs()) |ni|  {
            for (other.nbrs()) |nj| {
                if (ni == nj) {
                    storage[nbr_cnt] = ni;
                    nbr_cnt += 1;
                    break;
                }
            }
        }

        if (self.isNbr(other)) {
            std.debug.assert(nbr_cnt <= 4);
            storage[nbr_cnt] = self.id; nbr_cnt +=1;
            storage[nbr_cnt] = other.id; nbr_cnt +=1;
        }

        return storage[0..nbr_cnt];
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
        return if (self.yield_no != null) Yield.yield(self.yield_no.?) else null;
    }
};

const g_fields: [fields_cnt]Field = blk: {
    var _fields: [fields_cnt]Field = undefined;
    for (0..fields_cnt) |i| _fields[i] = Field.init(i);
    break :blk _fields;
};

const Zone = struct {
    id: u8 = undefined,
    fields: [zone_size]u8 = undefined,

    const zones = blk: {
        var a = [_]@This() {
            @This(){ .fields = .{ 3, 0, 4 } },
            @This(){ .fields = .{ 0, 4, 1 } },
            @This(){ .fields = .{ 4, 1, 5 } },
            @This(){ .fields = .{ 1, 5, 2 } },
            @This(){ .fields = .{ 5, 2, 6 } },
            @This(){ .fields = .{ 7, 3, 8 } },
            @This(){ .fields = .{ 3, 8, 4 } },
            @This(){ .fields = .{ 8, 4, 9 } },
            @This(){ .fields = .{ 4, 9, 5 } },
            @This(){ .fields = .{ 9, 5, 10 } },
            @This(){ .fields = .{ 5, 10, 6 } },
            @This(){ .fields = .{ 10, 6, 11 } },
            @This(){ .fields = .{ 7, 12, 8 } },
            @This(){ .fields = .{ 12, 8, 13 } },
            @This(){ .fields = .{ 8, 13, 9 } },
            @This(){ .fields = .{ 13, 9, 14 } },
            @This(){ .fields = .{ 14, 10, 15 } },
            @This(){ .fields = .{ 10, 15, 11 } },
            @This(){ .fields = .{ 12, 16, 13 } },
            @This(){ .fields = .{ 16, 13, 17 } },
            @This(){ .fields = .{ 13, 17, 14 } },
            @This(){ .fields = .{ 17, 14, 18 } },
            @This(){ .fields = .{ 14, 18, 15 } },
        };
        for (&a, 0..) |*z, i| z.id = i;
        break :blk a;
    };

    const zone_size = 3;
    const initErr = error {badNeighbors};
    const expected_yield: f32 = (@as(f32, yield_space) / res_fields_cnt) * zone_size;

    fn init(a: *const Field, b: *const Field) initErr!@This() {
        var nbr_a: [nbr_max]u8 = undefined;
        const nbr = a.nbrs_common(b, &nbr_a);
        return if (nbr.len == zone_size) Zone { .fields = nbr.* } else initErr.badNeighbors;
    }

    fn yield(self: *const Zone, fields: *const [fields_cnt]Field) u8 {
        var sum: u8 = 0;
        for (self.fields) |i| sum += Yield.yield(fields[i].yield_no.?);
        return sum;
    }

    fn less_than(fields: *const [fields_cnt]Field, lhs: *const @This(), rhs: *const @This()) bool {
        return lhs.yield(fields) < rhs.yield(fields);
    }

    fn balance(fields: *[fields_cnt]Field, za: *const @This(), zb: *const @This()) void {
        // std.debug.print("balancing {d}({d}) and {d}({d})\n", 
        //     .{za.id, za.yield(fields), zb.id, zb.yield(fields)});

        const lesser, const greater = 
            if (za.yield(fields) <= zb.yield(fields)) .{ za, zb } else .{ zb, za };

        var min: *Field = &fields[lesser.fields[0]];
        if (min.res == .Desert) min = &fields[lesser.fields[1]];
        var max: *Field = &fields[greater.fields[0]];
        if (max.res == .Desert) max = &fields[greater.fields[1]];

        for (lesser.fields[1..], greater.fields[1..]) |li, gi| {
            const lf = &fields[li]; const gf = &fields[gi];
            if (Yield.yield(lf.yield_no.?) < Yield.yield(min.yield_no.?) and lf.res != .Desert) min = lf;
            if (Yield.yield(gf.yield_no.?) > Yield.yield(max.yield_no.?) and gf.res != .Desert) max = gf;
        }

        const tmp = min.yield_no;
        min.yield_no = max.yield_no;
        max.yield_no = tmp;
    }

    fn overlap(za: *const @This(), zb: *const @This()) u8 {
        var cnt: u8 = 0;
        for (za.fields) |fa| for (zb.fields) |fb| {
            if (fa == fb) {
                cnt += 1;
                break;
            }
        };

        return cnt;
    }

    fn overlap2(za: *const @This(), zb: *const @This()) bool {
        @setEvalBranchQuota(10000);
        const overlap2_mat = comptime blk: {
            var mat: [zones.len][zones.len]bool = @splat(@splat(false));
            for (&zones, 0..) |*zai, i| for (zones[i + 1..]) |*zbi| {
                if (zai.overlap(zbi) == 2) {
                    mat[zai.id][zbi.id] = true;
                    mat[zbi.id][zai.id] = true;
                }
            };
            break :blk mat;
        };

        return overlap2_mat[za.id][zb.id];
    }
};

const ResYield = struct {
    res: Resource,
    flds: Vec(*Field, 4) = .{},

    fn init(res: Resource, fields2: *[fields_cnt]Field) @This() {
        var self = @This() { .res = res };

        for (fields2) |*f| {
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

    // fn more_than(yield_fn: *const fn(*const @This()) f32 , lhs: *const @This(), rhs: *const @This()) bool {
    //     return yield_fn(lhs) > yield_fn(rhs);
    // }
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
        f_str[i] = if (f.res != null) f.res.?.letter() else ""; 
    }

    print_map(@TypeOf(f_str[0]), &f_str);

    var f_yield_no: [fields_cnt]u8 = undefined;
    for (flds, 0..) |*f, i| {
        if ((f.res == null) or (f.res.? == Resource.Desert)) {
            f_yield_no[i] = 0;
        }
        else {
            f_yield_no[i] = f.yield_no orelse 0;
        }
    }

    print_map(@TypeOf(f_yield_no[0]), &f_yield_no);

    var f_yield: [fields_cnt]u8 = undefined;
    for (flds, 0..) |*f, i| {
        if ((f.res == null) or (f.res.? == Resource.Desert) or (f.yield_no == null)) {
            f_yield[i] = 0;
        }
        else {
            f_yield[i] = Yield.yield(f.yield_no.?);
        }
    }

    print_map(@TypeOf(f_yield[0]), &f_yield);

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

fn assign_yields(fields: *[fields_cnt]Field, 
                 yields: *const [Yield.yield_vals_cnt]Yield,
                 zones: *const [Zone.zones.len]Zone) u8 {
    const Outliers = struct {
        fn non_overlap2(zl: [Zone.zones.len]*const Zone, flds: *[fields_cnt]Field ) struct {*const Zone, *const Zone} {
            const minl = for (1..zl.len) |i| {
                if (zl[i].yield(flds) > zl[0].yield(flds)) break zl[0..i];
            } else {
                unreachable;
            };
            const maxl = for (1..zl.len) |i| {
                if (zl[i].yield(flds) == zl[zl.len - 1].yield(flds)) break zl[i..zl.len];
            } else {
                unreachable;
            };
            for (minl) |min| { 
                for (maxl) |max| {
                    if (!min.overlap2(max)) return .{min, max};
                }
            } 
            else return .{zl[0],  zl[zl.len - 1]};
        }
    };
    const yields_nos = blk: {
        var a: [res_fields_cnt]u8 = undefined;
        var i: u8 = 0;
        for (yields) |yield| {
            for (0..yield.cnt) |_| {
                a[i] = yield.no;
                i += 1;
            }
        }
        break :blk a;
    };

    var diff: u8 = 0;

    for (0..1024) |_| shuffle: {
        const fp = blk: {
            var _fp: [fields_cnt]*Field = undefined;
            for (0..fields_cnt) |i| _fp[i] = &fields[i];
            std.Random.shuffle(random.random(), *Field, &_fp);
            break :blk _fp;
        };

        var yi: u8 = 0;
        for (fp) |field| {
            std.debug.assert(field.res != null);
            if (field.res == Resource.Desert) {
                // field.yield = @round(@as(f32, yield_space) / res_fields_cnt);
                field.yield_no = 0;
                continue;
            }
            field.yield_no = yields_nos[yi];
            yi += 1;
        }

        // std.debug.print("---\n", .{});
        for (0..16) |_| {
            var zp = blk: {
                var a: [Zone.zones.len]*const Zone = undefined;
                for (zones, &a) |*p, *ap| ap.* = p;
                break :blk a;
            };

            std.sort.block(*const Zone, &zp, fields, Zone.less_than);

            // for (zp) |z| std.debug.print("{d}, ", .{ z.yield(fields) });
            // std.debug.print("\n", .{});
            var zmin = zp[0];
            var zmax = zp[zp.len - 1];

            diff = @intCast(@as(i16, zmax.yield(fields)) - zmin.yield(fields));
            if (diff <= max_zone_yield_diff) {
                break :shuffle;
            }

            if (zmin.overlap2(zmax)) std.debug.print("zones {d} and {d} overlap\n",
                .{zmin.id, zmax.id});

            zmin, zmax = Outliers.non_overlap2(zp, fields);

            Zone.balance(fields, zmin, zmax);
        }
    } 

    return diff;
}

fn balance_res_yields(fields: *[fields_cnt]Field) f32 {
    var res_yields = blk: {
        var a: [Resource.enumLen - 1]ResYield = undefined;
        for (0..Resource.enumLen - 1) |ri| a[ri] = ResYield.init(@enumFromInt(ri), fields);
        break :blk a;
    };

    var ryp = blk: {
        var a: [Resource.enumLen - 1]*ResYield = undefined;
        for (&res_yields, &a) |*res, *dest| dest.* = res;
        break :blk a;
    };
    std.sort.block(*ResYield, &ryp, {}, ResYield.less_than);

    const attempts: u8 = 10;
    for (0..attempts) |_| {
        std.sort.block(*ResYield, &ryp, {}, ResYield.less_than);

        // for (ryp) |r| {
        //     std.debug.print("{any} {d},", .{r.res, r.yield_norm()});
        // }
        // std.debug.print("\n", .{});

        // std.debug.print("Resource yield:\n", .{});
        // std.debug.print("  {s:<10} {s:>5} {s:>10}\n", .{"res", "yield", "norm yield"});
        // for (@typeInfo(Resource).@"enum".field_names[0..Resource.enumLen - 1], 0..) |n, i| {
        //     std.debug.print("  {s:<10} {d:>5} {d:>10.2}\n ", .{ n, res_yields[i].yield(), res_yields[i].yield_norm() });
        // }

        const diff = ryp[ryp.len - 1].yield_norm() - ryp[0].yield_norm();
        if (diff <= max_res_yield_diff) {
            break;
        }
        ryp[0].balance(ryp[ryp.len - 1]);
        std.sort.block(*ResYield, &ryp, {}, ResYield.less_than);
    }
    // std.debug.print("Sum: {d}\n", .{ sum });
    return ryp[ryp.len - 1].yield_norm() - ryp[0].yield_norm();
}

pub fn main(init: std.process.Init) !void {
    // In order to do I/O operations need an `Io` instance.
    const io = init.io;
    var seed: u64 = undefined;
    io.random(@as(*[8]u8, @ptrCast(&seed)));
    random = std.Random.DefaultPrng.init(seed);

    // std.debug.print("{any}\n", .{ zones });
    // const test_array_d: [19]u8 = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 };
    // print_map(@TypeOf(test_array_d[0]), &test_array_d);

    const res_assign_attempts = 64;
    const map_attempts = 32;
    for (0..map_attempts) |_|{
        var res_available: [Resource.enumLen]i8  = undefined;
        var fields_copy: [fields_cnt]Field = undefined;
        for (0..res_assign_attempts) |_| {
            res_available= @as(*const [Resource.enumLen]i8, @ptrCast(&Resource.cnt_list())).*;
            fields_copy = g_fields;
            const clumps = assign_resources(&fields_copy, &res_available);
            if (clumps == 0) break;
        } else {
            continue;
        }

        // for (res_available) |cnt| std.debug.assert(cnt == 0);

        const diff = assign_yields(&fields_copy, &g_yields, &Zone.zones);
        if (diff > max_zone_yield_diff) continue;

        const bal_diff = balance_res_yields(&fields_copy);
        if (bal_diff > max_res_yield_diff) continue;

        const clumps = blk: {
            var c: u8 = 0;
            for (fields_copy) |f| {
                for (f.nbrs()) |n| {
                    if (f.res.? == fields_copy[n].res.?) c += 1;
                }
            }
            break :blk c / 2;
        };

        if (clumps > clumps_max_after_balance) continue;

        var res_yields = blk: {
            var a: [Resource.enumLen - 1]ResYield = undefined;
            for (0..Resource.enumLen - 1) |ri| a[ri] = ResYield.init(@enumFromInt(ri), &fields_copy);
            break :blk a;
        };

        std.debug.print("Resource yield:\n", .{});
        std.debug.print("  {s:<10} {s:>5} {s:>11}\n", .{"res", "yield", "norm yield"});
        for (@typeInfo(Resource).@"enum".field_names[0..Resource.enumLen - 1], 0..) |n, i| {
            std.debug.print("  {s:<10} {d:>5} {d:>11.2}\n", .{ n, res_yields[i].yield(), res_yields[i].yield_norm() });
        }

        std.debug.print("clumps = {d}\n", .{ clumps });
        std.debug.print("zone diff = {d}\n", .{ diff });
        std.debug.print("resource diff (normalized) = {d}\n", .{ bal_diff });
        print_fields(&fields_copy);

        break;
        // if (diff <= max_zone_yield_diff) break;
    } else {
        std.debug.print("Cannot create map with seed {d}\n", .{ seed });
    }
}

