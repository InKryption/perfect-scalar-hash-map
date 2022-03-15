const std = @import("std");

pub fn PerfectScalarHashMap(comptime K: type, comptime V: type, comptime key_list: []const K) type {
    return PerfectScalarHashMapImpl(K, V, key_list[0..key_list.len].*);
}

fn PerfectScalarHashMapImpl(comptime K: type, comptime V: type, comptime key_list: anytype) type {
    std.debug.assert(@typeInfo(@TypeOf(key_list)).Array.child == K);
    const keys_vec: @Vector(key_list.len, K) = key_list;

    for (key_list) |k, i| {
        @setEvalBranchQuota(std.math.min(std.math.maxInt(u32), 1000 + key_list.len * 1000));
        const occurences = @reduce(.Add, @bitCast(@Vector(key_list.len, u1), @splat(key_list.len, k) == keys_vec));
        if (occurences != 1) {
            @compileError(std.fmt.comptimePrint("Duplicate key '{}' at index {}.", .{ k, i }));
        }
    }

    return struct {
        const Self = @This();
        values: [keys.len]V = undefined,

        pub const keys: [key_list.len]K = key_list;
        pub const KeyIndex = std.math.IntFittingRange(0, keys.len - 1);

        pub fn get(self: Self, key: K) ?V {
            var copy = self;
            return if (copy.getPtr(key)) |val|
                val.*
            else
                null;
        }

        pub fn getPtr(self: *Self, key: K) ?*V {
            return if (keyToIndex(key)) |i|
                &self.values[i]
            else
                null;
        }

        pub fn iterator(self: *Self) Iterator {
            return Iterator{
                .hm = self,
                .i = 0,
            };
        }

        pub const Iterator = struct {
            hm: *Self,
            i: KeyIndex,

            pub fn reset(self: *Iterator) void {
                self.* = self.hm.iterator();
            }

            pub const Entry = struct { key: K, value_ptr: *V };
            pub fn next(self: *Iterator) ?Entry {
                if (self.i == Self.keys.len) return null;
                const key = Self.keys[self.i];
                const value_ptr = self.hm.getPtr(key).?;
                self.i += 1;
                return Entry{
                    .key = key,
                    .value_ptr = value_ptr,
                };
            }
        };

        fn keyToIndex(key: K) ?KeyIndex {
            const splat = @splat(keys.len, key);

            const occurences = @reduce(.Add, @bitCast(@Vector(keys.len, u1), splat == keys_vec));
            return if (occurences < 1)
                null
            else if (occurences == 1) blk: {
                const cmp = @bitCast(@Vector(keys.len, u1), splat < keys_vec);
                break :blk @reduce(.Add, cmp);
            } else unreachable; // duplicate keys
        }
    };
}
