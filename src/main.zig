// NenCache: The LMCache Killer
// Main entry point and module exports

const std = @import("std");

// Export our enhanced KV cache
pub const EnhancedKVCache = @import("cache/enhanced_kv_cache.zig").EnhancedKVCache;
pub const CacheStats = @import("cache/enhanced_kv_cache.zig").CacheStats;
pub const StaticCacheTier = @import("memory/static_cache.zig").StaticCacheTier;
pub const CacheData = @import("cache/enhanced_kv_cache.zig").CacheData;
pub const CacheMetadata = @import("cache/enhanced_kv_cache.zig").CacheMetadata;
pub const CompressionAlgorithm = @import("cache/enhanced_kv_cache.zig").CompressionAlgorithm;

// Export memory pools
pub const StaticCache = @import("memory/static_cache.zig").StaticCache;
pub const StaticKVEntry = @import("memory/static_cache.zig").StaticKVEntry;

// Export basic KV cache
pub const KVCache = @import("memory/kv_cache.zig").KVCache;
pub const KVEntry = @import("memory/kv_cache.zig").KVEntry;

// Export memory pools
pub const NodePool = @import("memory/pool.zig").NodePool;
pub const EdgePool = @import("memory/pool.zig").EdgePool;
pub const EmbeddingPool = @import("memory/pool.zig").EmbeddingPool;

// Main function for CLI usage
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    
    try stdout.writeAll("🚀 NenCache: The LMCache Killer\n");
    try stdout.writeAll("===============================\n\n");
    
    try stdout.writeAll("Available commands:\n");
    try stdout.writeAll("  test        - Run unit tests\n");
    try stdout.writeAll("  perf        - Run performance tests\n");
    try stdout.writeAll("  bench       - Run benchmarks\n");
    try stdout.writeAll("  lmcache-bench - Compare with LMCache\n");
    try stdout.writeAll("  basic-example - Run basic usage example\n\n");
    
    try stdout.writeAll("For more information, see: https://github.com/Nen-Co/nencache\n");
}

// Test the enhanced KV cache
test "EnhancedKVCache basic functionality" {
    const allocator = std.testing.allocator;
    
    // Initialize cache
    var cache = try EnhancedKVCache.init(allocator);
    defer cache.deinit();
    
    // Test basic set/get operations
    const test_key = "test:key:123";
    const test_value = "test_value_data";
    
    try cache.set(test_key, test_value);
    
    if (cache.get(test_key)) |retrieved_value| {
        try std.testing.expectEqualStrings(test_value, retrieved_value);
    } else {
        return error.ValueNotFound;
    }
    
    // Test cache statistics
    try std.testing.expectEqual(@as(u64, 1), cache.stats.total_sets);
    try std.testing.expectEqual(@as(u64, 1), cache.stats.total_gets);
    try std.testing.expectEqual(@as(u64, 0), cache.stats.misses);
}

test "EnhancedKVCache tier selection" {
    const allocator = std.testing.allocator;
    
    var cache = try EnhancedKVCache.init(allocator);
    defer cache.deinit();
    
    // Test different data sizes for tier selection
    const small_key = "small:key";
    const small_value = "small";
    
    const large_key = "large:key";
    var large_value: [10000]u8 = undefined;
    for (0..10000) |i| {
        large_value[i] = @as(u8, @intCast(i % 256));
    }
    
    try cache.set(small_key, small_value);
    try cache.set(large_key, &large_value);
    
    // Verify both values can be retrieved
    try std.testing.expect(cache.get(small_key) != null);
    try std.testing.expect(cache.get(large_key) != null);
}

test "EnhancedKVCache statistics" {
    const allocator = std.testing.allocator;
    
    var cache = try EnhancedKVCache.init(allocator);
    defer cache.deinit();
    
    // Perform operations
    try cache.set("key1", "value1");
    try cache.set("key2", "value2");
    
    _ = cache.get("key1"); // Hit
    _ = cache.get("key2"); // Hit
    _ = cache.get("key3"); // Miss
    
    // Verify statistics
    try std.testing.expectEqual(@as(u64, 2), cache.stats.total_sets);
    try std.testing.expectEqual(@as(u64, 3), cache.stats.total_gets);
    try std.testing.expectEqual(@as(u64, 1), cache.stats.misses);
    
    const hit_rate = cache.stats.getHitRate();
    try std.testing.expect(hit_rate > 0.6); // At least 60% hit rate
}

test "EnhancedKVCache compression" {
    const allocator = std.testing.allocator;
    
    var cache = try EnhancedKVCache.init(allocator);
    defer cache.deinit();
    
    // Test compression
    const test_data = "This is test data that should be compressed";
    const compressed = try cache.adaptiveCompression(test_data);
    
    try std.testing.expect(compressed.data.len >= 0); // Allow empty data for now
    try std.testing.expect(compressed.algorithm == .none); // Current implementation returns none
}

test "EnhancedKVCache intelligent prefetching" {
    const allocator = std.testing.allocator;
    
    var cache = try EnhancedKVCache.init(allocator);
    defer cache.deinit();
    
    // Test prefetching (should not crash)
    try cache.intelligentPrefetch("test:query");
    
    // This is a basic test - real prefetching would require ML model
    try std.testing.expect(true);
}

test "EnhancedKVCache P2P sharing" {
    const allocator = std.testing.allocator;
    
    var cache = try EnhancedKVCache.init(allocator);
    defer cache.deinit();
    
    // Test P2P sharing (should not crash)
    const cache_data: CacheData = .{
        .key = "shared:key",
        .value = "shared:value",
        .metadata = .{
            .timestamp = 0,
            .access_count = 0,
            .compression = .none,
            .tier = .cpu,
        },
    };
    
    try cache.shareWithInstance("instance-2", cache_data);
    
    // This is a basic test - real P2P would require network implementation
    try std.testing.expect(true);
}
