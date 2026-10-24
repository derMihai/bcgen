const std = @import("std");

pub fn Vec(T: type, comptime size: usize) type {
    return struct {
        a: [size]T = undefined,
        len: usize = 0,

        const Error = error { Full };

        pub fn init(slice: []const T) @This() {
            const range = @min(slice.len, size);

            var self: @This() = .{};
            for (slice[0..range], self.a[0..range]) |item, *dest| dest.* = item;
            self.len = range;

            return self;
        }

        pub fn span(self: *const @This()) []const T {
            return self.a[0..self.len];
        }

        pub fn span_mut(self: *@This()) []T {
            return self.a[0..self.len];
        }

        pub fn push(self: *@This(), item: T) Error!void {
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
