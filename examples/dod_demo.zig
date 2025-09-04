// Nen Cache Data-Oriented Design (DOD) Demo
// Demonstrates the performance benefits of DOD architecture for cache operations

const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    std.debug.print("🚀 Nen Cache Data-Oriented Design (DOD) Demo\n", .{});
    std.debug.print("==========================================\n\n", .{});

    // Initialize DOD Cache layout
    var cache_layout = nencache.dod_layout.DODCacheLayout.init();
    var prefetch_system = nencache.dod_prefetch.CachePrefetchSystem.init(nencache.dod_prefetch.CachePrefetchConfig{});

    // Demo 1: SoA vs AoS Performance for Cache Operations
    std.debug.print("📊 Demo 1: Struct of Arrays (SoA) Cache Performance\n", .{});
    std.debug.print("--------------------------------------------------\n", .{});

    const num_keys = 1000;
    const num_values = 500;
    const num_metadata = 200;

    // Add keys using SoA layout
    const start_time = std.time.nanoTimestamp();
    
    for (0..num_keys) |i| {
        const key = try std.fmt.allocPrint(gpa.allocator(), "key_{d}", .{i});
        defer gpa.allocator().free(key);
        _ = try cache_layout.addKey(key, @intCast(i % 4)); // Different tiers
    }
    
    for (0..num_values) |i| {
        const value = try std.fmt.allocPrint(gpa.allocator(), "value_{d}_data", .{i});
        defer gpa.allocator().free(value);
        _ = try cache_layout.addValue(value, @intCast(i % 4), i % 2 == 0); // Different tiers and compression
    }
    
    for (0..num_metadata) |i| {
        _ = try cache_layout.addMetadata(@intCast(i % 8), @intCast(i * 16), @intCast(i % 4), @intCast(i * 32));
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration_ns = end_time - start_time;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;

    std.debug.print("✅ Added {d} keys, {d} values, and {d} metadata entries in {d:.2}ms\n", .{ num_keys, num_values, num_metadata, duration_ms });
    std.debug.print("⚡ Performance: {d:.0} operations/second\n\n", .{ @as(f64, @floatFromInt(num_keys + num_values + num_metadata)) / (duration_ms / 1000.0) });

    // Demo 2: SIMD-Optimized Cache Operations
    std.debug.print("🔍 Demo 2: SIMD-Optimized Cache Operations\n", .{});
    std.debug.print("----------------------------------------\n", .{});

    var search_keys: [10][]const u8 = undefined;
    for (0..10) |i| {
        search_keys[i] = try std.fmt.allocPrint(gpa.allocator(), "key_{d}", .{i});
        defer gpa.allocator().free(search_keys[i]);
    }

    var found_indices: [10]u32 = undefined;
    
    const simd_start = std.time.nanoTimestamp();
    const found_count = try cache_layout.findKeysSIMD(&search_keys, &found_indices);
    const simd_end = std.time.nanoTimestamp();
    const simd_duration_ns = simd_end - simd_start;
    const simd_duration_ms = @as(f64, @floatFromInt(simd_duration_ns)) / 1_000_000.0;

    std.debug.print("✅ Found {d} keys using SIMD in {d:.3}ms\n", .{ found_count, simd_duration_ms });
    std.debug.print("⚡ SIMD cache performance: {d:.0} keys/second\n\n", .{ @as(f64, @floatFromInt(found_count)) / (simd_duration_ms / 1000.0) });

    // Demo 3: SIMD Value Operations
    std.debug.print("💾 Demo 3: SIMD Value Operations\n", .{});
    std.debug.print("--------------------------------\n", .{});

    var value_indices: [5]u32 = undefined;
    for (0..5) |i| {
        value_indices[i] = @intCast(i);
    }

    var value_data: [1024]u8 = undefined;
    
    const value_start = std.time.nanoTimestamp();
    const bytes_copied = try cache_layout.getValuesSIMD(&value_indices, &value_data);
    const value_end = std.time.nanoTimestamp();
    const value_duration_ns = value_end - value_start;
    const value_duration_ms = @as(f64, @floatFromInt(value_duration_ns)) / 1_000_000.0;

    std.debug.print("✅ Copied {d} bytes using SIMD in {d:.3}ms\n", .{ bytes_copied, value_duration_ms });
    std.debug.print("⚡ SIMD value performance: {d:.0} bytes/second\n\n", .{ @as(f64, @floatFromInt(bytes_copied)) / (value_duration_ms / 1000.0) });

    // Demo 4: Prefetching for Cache Operations
    std.debug.print("🎯 Demo 4: Cache Prefetching System\n", .{});
    std.debug.print("-----------------------------------\n", .{});

    const prefetch_start = std.time.nanoTimestamp();
    
    // Prefetch GPU data
    var gpu_indices: [10]u32 = undefined;
    for (0..10) |i| {
        gpu_indices[i] = @intCast(i);
    }
    prefetch_system.prefetchGPUData(&cache_layout, &gpu_indices, .sequential_access);
    
    // Prefetch CPU data
    var cpu_indices: [20]u32 = undefined;
    for (0..20) |i| {
        cpu_indices[i] = @intCast(i + 10);
    }
    prefetch_system.prefetchCPUData(&cache_layout, &cpu_indices, .temporal_locality);
    
    // Prefetch NVMe data
    var nvme_indices: [30]u32 = undefined;
    for (0..30) |i| {
        nvme_indices[i] = @intCast(i + 30);
    }
    prefetch_system.prefetchNVMEData(&cache_layout, &nvme_indices, .spatial_locality);
    
    const prefetch_end = std.time.nanoTimestamp();
    const prefetch_duration_ns = prefetch_end - prefetch_start;
    const prefetch_duration_ms = @as(f64, @floatFromInt(prefetch_duration_ns)) / 1_000_000.0;

    std.debug.print("✅ Prefetched {d} GPU, {d} CPU, and {d} NVMe entries in {d:.3}ms\n", .{ gpu_indices.len, cpu_indices.len, nvme_indices.len, prefetch_duration_ms });

    // Demo 5: SIMD Statistics and Aggregation
    std.debug.print("\n📈 Demo 5: SIMD Statistics and Aggregation\n", .{});
    std.debug.print("-----------------------------------------\n", .{});

    var stats_values: [50]u64 = undefined;
    var stats_types: [50]u8 = undefined;
    for (0..50) |i| {
        stats_values[i] = @intCast(i * 100);
        stats_types[i] = @intCast(i % 8);
    }

    var aggregated: [50]u64 = undefined;
    
    const stats_start = std.time.nanoTimestamp();
    const aggregated_count = nencache.dod_simd.DODSIMDOperations.aggregateStatsSIMD(&stats_values, &stats_types, &aggregated);
    const stats_end = std.time.nanoTimestamp();
    const stats_duration_ns = stats_end - stats_start;
    const stats_duration_ms = @as(f64, @floatFromInt(stats_duration_ns)) / 1_000_000.0;

    std.debug.print("✅ Aggregated {d} statistics using SIMD in {d:.3}ms\n", .{ aggregated_count, stats_duration_ms });

    // Demo 6: Cache Tier Management
    std.debug.print("\n🏗️ Demo 6: Cache Tier Management\n", .{});
    std.debug.print("--------------------------------\n", .{});

    // Update tier usage
    cache_layout.updateTierUsage(0, 256); // GPU tier
    cache_layout.updateTierUsage(1, 1024); // CPU tier
    cache_layout.updateTierUsage(2, 4096); // NVMe tier
    cache_layout.updateTierUsage(3, 16384); // Disk tier

    // Update tier latencies
    cache_layout.updateTierLatency(0, 1000); // 1μs
    cache_layout.updateTierLatency(1, 10000); // 10μs
    cache_layout.updateTierLatency(2, 100000); // 100μs
    cache_layout.updateTierLatency(3, 1000000); // 1ms

    // Update tier hit rates
    cache_layout.updateTierHitRate(0, 0.99); // 99%
    cache_layout.updateTierHitRate(1, 0.95); // 95%
    cache_layout.updateTierHitRate(2, 0.90); // 90%
    cache_layout.updateTierHitRate(3, 0.85); // 85%

    std.debug.print("✅ Updated tier usage, latencies, and hit rates\n", .{});

    // Demo 7: Cache Statistics
    std.debug.print("\n📊 Demo 7: DOD Cache Statistics\n", .{});
    std.debug.print("-------------------------------\n", .{});

    const stats = cache_layout.getStats();
    const prefetch_stats = prefetch_system.getStats();
    
    std.debug.print("📊 Cache Layout Statistics:\n", .{});
    std.debug.print("   Keys: {d}/{d} ({d:.1}% utilization)\n", .{ 
        stats.key_count, 
        stats.key_capacity, 
        stats.getKeyUtilization() * 100.0 
    });
    std.debug.print("   Values: {d}/{d} ({d:.1}% utilization)\n", .{ 
        stats.value_count, 
        stats.value_capacity, 
        stats.getValueUtilization() * 100.0 
    });
    std.debug.print("   Metadata: {d}/{d} ({d:.1}% utilization)\n", .{ 
        stats.metadata_count, 
        stats.metadata_capacity, 
        stats.getMetadataUtilization() * 100.0 
    });
    std.debug.print("   Overall utilization: {d:.1}%\n", .{stats.getOverallUtilization() * 100.0});

    std.debug.print("\n📊 Tier Statistics:\n", .{});
    for (0..4) |tier| {
        std.debug.print("   Tier {d}: {d} usage, {d}μs latency, {d:.1}% hit rate\n", .{
            tier,
            stats.tier_usage[tier],
            stats.tier_latencies[tier] / 1000, // Convert to microseconds
            stats.tier_hit_rates[tier] * 100.0
        });
    }

    std.debug.print("\n📊 Prefetch Statistics:\n", .{});
    std.debug.print("   Total prefetches: {d}\n", .{prefetch_stats.getTotalPrefetches()});
    std.debug.print("   Prefetch effectiveness: {d:.1}%\n", .{prefetch_stats.getPrefetchEffectiveness() * 100.0});
    std.debug.print("   Cache hit rate: {d:.1}%\n", .{prefetch_stats.getHitRate() * 100.0});

    // Demo 8: DOD Benefits Summary
    std.debug.print("\n🎯 DOD Benefits Demonstrated\n", .{});
    std.debug.print("----------------------------\n", .{});
    std.debug.print("✅ Struct of Arrays (SoA) layout for better cache locality\n", .{});
    std.debug.print("✅ SIMD-optimized cache operations for vectorized processing\n", .{});
    std.debug.print("✅ Advanced prefetching system for cache operations\n", .{});
    std.debug.print("✅ Static memory allocation for predictable performance\n", .{});
    std.debug.print("✅ Tier-based cache management with DOD optimization\n", .{});
    std.debug.print("✅ Component-based architecture for flexible cache modeling\n", .{});

    std.debug.print("\n🚀 Nen Cache DOD architecture delivers maximum cache performance!\n", .{});
}
