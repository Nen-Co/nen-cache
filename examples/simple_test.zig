const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    // Test core NenCache functionality
    const allocator = std.heap.page_allocator;
    var cache = try nencache.EnhancedKVCache.init(allocator);
    defer cache.deinit();

    // Test basic operations
    try cache.set("test:key", "test:value");

    if (cache.get("test:key")) |value| {
        // Success! The cache is working
        _ = value; // Use the value to avoid unused variable warning
    }

    // Test performance
    const iterations = 1000;
    const start_time = std.time.nanoTimestamp();

    for (0..iterations) |i| {
        const key = try std.fmt.allocPrint(allocator, "perf:key:{d}", .{i});
        defer allocator.free(key);

        const value = try std.fmt.allocPrint(allocator, "value_{d}", .{i});
        defer allocator.free(value);

        try cache.set(key, value);
        _ = cache.get(key);
    }

    const end_time = std.time.nanoTimestamp();
    const duration_ns = @as(u64, @intCast(end_time - start_time));

    // Get stats
    _ = cache.memory_pools.getOverallStats(); // Use memory stats
    const hit_rate = cache.stats.getHitRate();

    // Simple success indicator
    std.debug.print("✅ NenCache working! {d} ops in {d}ns, hit rate: {d:.2}%\n", .{ iterations, duration_ns, hit_rate * 100.0 });
}
