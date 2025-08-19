// NenCache Basic Usage Example
// Shows how to use the enhanced KV cache

const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.writeAll("🚀 NenCache Basic Usage Example\n");
    try stdout.writeAll("================================\n\n");
    
    // Initialize the enhanced KV cache
    var cache = try nencache.EnhancedKVCache.init(std.heap.page_allocator);
    defer cache.deinit();
    
    try stdout.writeAll("✅ Cache initialized successfully\n\n");
    
    // Example 1: Basic set/get operations
    try stdout.writeAll("📝 Example 1: Basic Operations\n");
    try stdout.writeAll("-------------------------------\n");
    
    const user_key = "user:123:preferences";
    const user_prefs = "{\"theme\": \"dark\", \"language\": \"en\"}";
    
    try cache.set(user_key, user_prefs);
    try stdout.writeAll("   Set user preferences\n");
    
    if (cache.get(user_key)) |retrieved_prefs| {
        try stdout.print("   Retrieved: {s}\n", .{retrieved_prefs});
    } else {
        try stdout.writeAll("   ❌ Failed to retrieve preferences\n");
    }
    
    // Example 2: Different data sizes for tier selection
    try stdout.writeAll("\n📊 Example 2: Tier Selection\n");
    try stdout.writeAll("----------------------------\n");
    
    // Small data (likely goes to GPU/CPU)
    const small_key = "config:small";
    const small_data = "small_config_value";
    try cache.set(small_key, small_data);
    try stdout.writeAll("   Set small config (likely GPU/CPU tier)\n");
    
    // Large data (likely goes to NVMe/Disk)
    var large_data: [50000]u8 = undefined;
    for (0..50000) |i| {
        large_data[i] = @as(u8, @intCast(i % 256));
    }
    const large_key = "data:large";
    try cache.set(large_key, &large_data);
    try stdout.writeAll("   Set large data (likely NVMe/Disk tier)\n");
    
    // Example 3: Cache statistics
    try stdout.writeAll("\n📈 Example 3: Cache Statistics\n");
    try stdout.writeAll("-------------------------------\n");
    
    try stdout.print("   Total sets: {d}\n", .{cache.stats.total_sets});
    try stdout.print("   Total gets: {d}\n", .{cache.stats.total_gets});
    try stdout.print("   Hit rate: {d:.1}%\n", .{cache.stats.getHitRate() * 100.0});
    
    // Example 4: Intelligent prefetching
    try stdout.writeAll("\n🧠 Example 4: Intelligent Prefetching\n");
    try stdout.writeAll("------------------------------------\n");
    
    try cache.intelligentPrefetch("user:123:context");
    try stdout.writeAll("   Triggered intelligent prefetch for user context\n");
    
    // Example 5: Adaptive compression
    try stdout.writeAll("\n🗜️  Example 5: Adaptive Compression\n");
    try stdout.writeAll("----------------------------------\n");
    
    const compressible_data = "This is very repetitive data. " ** 100; // Repeat 100 times
    const compressed = try cache.adaptiveCompression(compressible_data);
    
    try stdout.print("   Original size: {d} bytes\n", .{compressible_data.len});
    try stdout.print("   Compressed size: {d} bytes\n", .{compressed.data.len});
    try stdout.print("   Compression ratio: {d:.1}%\n", .{@as(f64, @floatFromInt(compressed.data.len)) / @as(f64, @floatFromInt(compressible_data.len)) * 100.0});
    try stdout.print("   Algorithm: {s}\n", .{@tagName(compressed.algorithm)});
    
    // Example 6: P2P sharing
    try stdout.writeAll("\n🌐 Example 6: P2P Sharing\n");
    try stdout.writeAll("------------------------\n");
    
    const shared_data: nencache.CacheData = .{
        .key = "shared:cache:data",
        .value = "This data is shared across instances",
        .metadata = .{
            .timestamp = @as(i64, @intCast(std.time.nanoTimestamp())),
            .access_count = 0,
            .compression = .none,
            .tier = .cpu,
        },
    };
    
    try cache.shareWithInstance("instance-2", shared_data);
    try stdout.writeAll("   Shared cache data with instance-2\n");
    
    // Example 7: Performance demonstration
    try stdout.writeAll("\n⚡ Example 7: Performance Demo\n");
    try stdout.writeAll("-------------------------------\n");
    
    const iterations = 10000;
    const start_time = std.time.nanoTimestamp();
    
    // Perform many operations to demonstrate performance
    for (0..iterations) |i| {
        const key = try std.fmt.allocPrint(std.heap.page_allocator, "perf:key:{d}", .{i});
        defer std.heap.page_allocator.free(key);
        
        const value = try std.fmt.allocPrint(std.heap.page_allocator, "value:{d}:data", .{i});
        defer std.heap.page_allocator.free(value);
        
        try cache.set(key, value);
        _ = cache.get(key);
    }
    
    const end_time = std.time.nanoTimestamp();
    const total_time_ns = end_time - start_time;
    const total_time_ms = @as(f64, @floatFromInt(total_time_ns)) / 1_000_000.0;
    const ops_per_second = @as(f64, @floatFromInt(iterations * 2)) / (total_time_ms / 1000.0);
    
    try stdout.print("   Performed {d} operations in {d:.2} ms\n", .{iterations * 2, total_time_ms});
    try stdout.print("   Performance: {d:.0} ops/sec\n", .{ops_per_second});
    
    // Final statistics
    try stdout.writeAll("\n🏁 Final Cache Statistics\n");
    try stdout.writeAll("=========================\n");
    
    try stdout.print("   Total sets: {d}\n", .{cache.stats.total_sets});
    try stdout.print("   Total gets: {d}\n", .{cache.stats.total_gets});
    try stdout.print("   Total misses: {d}\n", .{cache.stats.misses});
    try stdout.print("   Hit rate: {d:.1}%\n", .{cache.stats.getHitRate() * 100.0});
    
    // Tier-specific statistics
    try stdout.print("   GPU hits: {d}\n", .{cache.stats.gpu_hits});
    try stdout.print("   CPU hits: {d}\n", .{cache.stats.cpu_hits});
    try stdout.print("   Disk hits: {d}\n", .{cache.stats.disk_hits});
    
    try stdout.writeAll("\n✅ NenCache example completed successfully!\n");
    try stdout.writeAll("   This demonstrates the enhanced KV cache capabilities\n");
    try stdout.writeAll("   that will beat LMCache's performance claims.\n");
}
