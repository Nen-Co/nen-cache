// Nen Cache Data-Oriented Design (DOD) Layout
// Implements Struct of Arrays (SoA) for high-performance cache operations

const std = @import("std");
const dod_config = @import("dod_config.zig");

// DOD Cache data structures using Struct of Arrays (SoA) layout
pub const DODCacheLayout = struct {
    // Key operations in SoA format
    key_data: [dod_config.DOD_CONSTANTS.MAX_KEYS][dod_config.DOD_CONSTANTS.CACHE_SIZE_MEDIUM]u8 align(dod_config.DOD_CONSTANTS.SIMD_ALIGNMENT),
    key_sizes: [dod_config.DOD_CONSTANTS.MAX_KEYS]u32 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    key_hashes: [dod_config.DOD_CONSTANTS.MAX_KEYS]u64 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    key_active: [dod_config.DOD_CONSTANTS.MAX_KEYS]bool align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    key_tiers: [dod_config.DOD_CONSTANTS.MAX_KEYS]u8 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    key_timestamps: [dod_config.DOD_CONSTANTS.MAX_KEYS]u64 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    key_access_counts: [dod_config.DOD_CONSTANTS.MAX_KEYS]u32 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    
    // Value operations in SoA format
    value_data: [dod_config.DOD_CONSTANTS.MAX_VALUES][dod_config.DOD_CONSTANTS.CACHE_SIZE_LARGE]u8 align(dod_config.DOD_CONSTANTS.SIMD_ALIGNMENT),
    value_sizes: [dod_config.DOD_CONSTANTS.MAX_VALUES]u32 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    value_compressed: [dod_config.DOD_CONSTANTS.MAX_VALUES]bool align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    value_active: [dod_config.DOD_CONSTANTS.MAX_VALUES]bool align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    value_tiers: [dod_config.DOD_CONSTANTS.MAX_VALUES]u8 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    value_timestamps: [dod_config.DOD_CONSTANTS.MAX_VALUES]u64 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    value_access_counts: [dod_config.DOD_CONSTANTS.MAX_VALUES]u32 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    
    // Metadata operations in SoA format
    metadata_types: [dod_config.DOD_CONSTANTS.MAX_METADATA]u8 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    metadata_sizes: [dod_config.DOD_CONSTANTS.MAX_METADATA]u32 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    metadata_active: [dod_config.DOD_CONSTANTS.MAX_METADATA]bool align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    metadata_tiers: [dod_config.DOD_CONSTANTS.MAX_METADATA]u8 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    metadata_timestamps: [dod_config.DOD_CONSTANTS.MAX_METADATA]u64 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    metadata_flags: [dod_config.DOD_CONSTANTS.MAX_METADATA]u32 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    
    // Statistics operations in SoA format
    stats_operation_types: [dod_config.DOD_CONSTANTS.MAX_STATS]u8 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    stats_values: [dod_config.DOD_CONSTANTS.MAX_STATS]u64 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    stats_timestamps: [dod_config.DOD_CONSTANTS.MAX_STATS]u64 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    stats_active: [dod_config.DOD_CONSTANTS.MAX_STATS]bool align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    stats_tiers: [dod_config.DOD_CONSTANTS.MAX_STATS]u8 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    stats_flags: [dod_config.DOD_CONSTANTS.MAX_STATS]u32 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    
    // Prefetch operations in SoA format
    prefetch_keys: [dod_config.DOD_CONSTANTS.MAX_PREFETCH][dod_config.DOD_CONSTANTS.CACHE_SIZE_MEDIUM]u8 align(dod_config.DOD_CONSTANTS.SIMD_ALIGNMENT),
    prefetch_tiers: [dod_config.DOD_CONSTANTS.MAX_PREFETCH]u8 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    prefetch_priorities: [dod_config.DOD_CONSTANTS.MAX_PREFETCH]u8 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    prefetch_active: [dod_config.DOD_CONSTANTS.MAX_PREFETCH]bool align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    prefetch_timestamps: [dod_config.DOD_CONSTANTS.MAX_PREFETCH]u64 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    prefetch_hints: [dod_config.DOD_CONSTANTS.MAX_PREFETCH]u8 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    
    // Tier-specific data
    tier_capacities: [4]u32 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    tier_usage: [4]u32 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    tier_latencies: [4]u64 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    tier_hit_rates: [4]f64 align(dod_config.DOD_CONSTANTS.CACHE_LINE_SIZE),
    
    // Statistics
    key_count: u32 = 0,
    value_count: u32 = 0,
    metadata_count: u32 = 0,
    stats_count: u32 = 0,
    prefetch_count: u32 = 0,
    
    pub fn init() DODCacheLayout {
        return DODCacheLayout{
            .key_data = [_][dod_config.DOD_CONSTANTS.CACHE_SIZE_MEDIUM]u8{[_]u8{0} ** dod_config.DOD_CONSTANTS.CACHE_SIZE_MEDIUM} ** dod_config.DOD_CONSTANTS.MAX_KEYS,
            .key_sizes = [_]u32{0} ** dod_config.DOD_CONSTANTS.MAX_KEYS,
            .key_hashes = [_]u64{0} ** dod_config.DOD_CONSTANTS.MAX_KEYS,
            .key_active = [_]bool{false} ** dod_config.DOD_CONSTANTS.MAX_KEYS,
            .key_tiers = [_]u8{0} ** dod_config.DOD_CONSTANTS.MAX_KEYS,
            .key_timestamps = [_]u64{0} ** dod_config.DOD_CONSTANTS.MAX_KEYS,
            .key_access_counts = [_]u32{0} ** dod_config.DOD_CONSTANTS.MAX_KEYS,
            .value_data = [_][dod_config.DOD_CONSTANTS.CACHE_SIZE_LARGE]u8{[_]u8{0} ** dod_config.DOD_CONSTANTS.CACHE_SIZE_LARGE} ** dod_config.DOD_CONSTANTS.MAX_VALUES,
            .value_sizes = [_]u32{0} ** dod_config.DOD_CONSTANTS.MAX_VALUES,
            .value_compressed = [_]bool{false} ** dod_config.DOD_CONSTANTS.MAX_VALUES,
            .value_active = [_]bool{false} ** dod_config.DOD_CONSTANTS.MAX_VALUES,
            .value_tiers = [_]u8{0} ** dod_config.DOD_CONSTANTS.MAX_VALUES,
            .value_timestamps = [_]u64{0} ** dod_config.DOD_CONSTANTS.MAX_VALUES,
            .value_access_counts = [_]u32{0} ** dod_config.DOD_CONSTANTS.MAX_VALUES,
            .metadata_types = [_]u8{0} ** dod_config.DOD_CONSTANTS.MAX_METADATA,
            .metadata_sizes = [_]u32{0} ** dod_config.DOD_CONSTANTS.MAX_METADATA,
            .metadata_active = [_]bool{false} ** dod_config.DOD_CONSTANTS.MAX_METADATA,
            .metadata_tiers = [_]u8{0} ** dod_config.DOD_CONSTANTS.MAX_METADATA,
            .metadata_timestamps = [_]u64{0} ** dod_config.DOD_CONSTANTS.MAX_METADATA,
            .metadata_flags = [_]u32{0} ** dod_config.DOD_CONSTANTS.MAX_METADATA,
            .stats_operation_types = [_]u8{0} ** dod_config.DOD_CONSTANTS.MAX_STATS,
            .stats_values = [_]u64{0} ** dod_config.DOD_CONSTANTS.MAX_STATS,
            .stats_timestamps = [_]u64{0} ** dod_config.DOD_CONSTANTS.MAX_STATS,
            .stats_active = [_]bool{false} ** dod_config.DOD_CONSTANTS.MAX_STATS,
            .stats_tiers = [_]u8{0} ** dod_config.DOD_CONSTANTS.MAX_STATS,
            .stats_flags = [_]u32{0} ** dod_config.DOD_CONSTANTS.MAX_STATS,
            .prefetch_keys = [_][dod_config.DOD_CONSTANTS.CACHE_SIZE_MEDIUM]u8{[_]u8{0} ** dod_config.DOD_CONSTANTS.CACHE_SIZE_MEDIUM} ** dod_config.DOD_CONSTANTS.MAX_PREFETCH,
            .prefetch_tiers = [_]u8{0} ** dod_config.DOD_CONSTANTS.MAX_PREFETCH,
            .prefetch_priorities = [_]u8{0} ** dod_config.DOD_CONSTANTS.MAX_PREFETCH,
            .prefetch_active = [_]bool{false} ** dod_config.DOD_CONSTANTS.MAX_PREFETCH,
            .prefetch_timestamps = [_]u64{0} ** dod_config.DOD_CONSTANTS.MAX_PREFETCH,
            .prefetch_hints = [_]u8{0} ** dod_config.DOD_CONSTANTS.MAX_PREFETCH,
            .tier_capacities = [_]u32{1024, 16384, 262144, 1048576}, // GPU, CPU, NVMe, Disk
            .tier_usage = [_]u32{0} ** 4,
            .tier_latencies = [_]u64{1000, 10000, 100000, 1000000}, // ns
            .tier_hit_rates = [_]f64{0.0} ** 4,
        };
    }
    
    // Key operations with DOD optimization
    pub fn addKey(self: *DODCacheLayout, key: []const u8, tier: u8) !u32 {
        if (self.key_count >= dod_config.DOD_CONSTANTS.MAX_KEYS) {
            return dod_config.DODError.PoolExhausted;
        }
        
        const index = self.key_count;
        const key_size = @min(key.len, dod_config.DOD_CONSTANTS.CACHE_SIZE_MEDIUM - 1);
        
        @memcpy(self.key_data[index][0..key_size], key[0..key_size]);
        self.key_data[index][key_size] = 0; // Null terminate
        self.key_sizes[index] = @intCast(key_size);
        self.key_hashes[index] = std.hash_map.hashString(key);
        self.key_active[index] = true;
        self.key_tiers[index] = tier;
        self.key_timestamps[index] = @as(u64, @intCast(std.time.nanoTimestamp()));
        self.key_access_counts[index] = 0;
        
        self.key_count += 1;
        return index;
    }
    
    // Value operations with DOD optimization
    pub fn addValue(self: *DODCacheLayout, value: []const u8, tier: u8, compressed: bool) !u32 {
        if (self.value_count >= dod_config.DOD_CONSTANTS.MAX_VALUES) {
            return dod_config.DODError.PoolExhausted;
        }
        
        const index = self.value_count;
        const value_size = @min(value.len, dod_config.DOD_CONSTANTS.CACHE_SIZE_LARGE - 1);
        
        @memcpy(self.value_data[index][0..value_size], value[0..value_size]);
        self.value_data[index][value_size] = 0; // Null terminate
        self.value_sizes[index] = @intCast(value_size);
        self.value_compressed[index] = compressed;
        self.value_active[index] = true;
        self.value_tiers[index] = tier;
        self.value_timestamps[index] = @as(u64, @intCast(std.time.nanoTimestamp()));
        self.value_access_counts[index] = 0;
        
        self.value_count += 1;
        return index;
    }
    
    // Metadata operations with DOD optimization
    pub fn addMetadata(self: *DODCacheLayout, metadata_type: u8, size: u32, tier: u8, flags: u32) !u32 {
        if (self.metadata_count >= dod_config.DOD_CONSTANTS.MAX_METADATA) {
            return dod_config.DODError.PoolExhausted;
        }
        
        const index = self.metadata_count;
        self.metadata_types[index] = metadata_type;
        self.metadata_sizes[index] = size;
        self.metadata_active[index] = true;
        self.metadata_tiers[index] = tier;
        self.metadata_timestamps[index] = @as(u64, @intCast(std.time.nanoTimestamp()));
        self.metadata_flags[index] = flags;
        
        self.metadata_count += 1;
        return index;
    }
    
    // Statistics operations with DOD optimization
    pub fn addStats(self: *DODCacheLayout, operation_type: u8, value: u64, tier: u8, flags: u32) !u32 {
        if (self.stats_count >= dod_config.DOD_CONSTANTS.MAX_STATS) {
            return dod_config.DODError.PoolExhausted;
        }
        
        const index = self.stats_count;
        self.stats_operation_types[index] = operation_type;
        self.stats_values[index] = value;
        self.stats_timestamps[index] = @as(u64, @intCast(std.time.nanoTimestamp()));
        self.stats_active[index] = true;
        self.stats_tiers[index] = tier;
        self.stats_flags[index] = flags;
        
        self.stats_count += 1;
        return index;
    }
    
    // Prefetch operations with DOD optimization
    pub fn addPrefetch(self: *DODCacheLayout, key: []const u8, tier: u8, priority: u8, hint: u8) !u32 {
        if (self.prefetch_count >= dod_config.DOD_CONSTANTS.MAX_PREFETCH) {
            return dod_config.DODError.PoolExhausted;
        }
        
        const index = self.prefetch_count;
        const key_size = @min(key.len, dod_config.DOD_CONSTANTS.CACHE_SIZE_MEDIUM - 1);
        
        @memcpy(self.prefetch_keys[index][0..key_size], key[0..key_size]);
        self.prefetch_keys[index][key_size] = 0; // Null terminate
        self.prefetch_tiers[index] = tier;
        self.prefetch_priorities[index] = priority;
        self.prefetch_active[index] = true;
        self.prefetch_timestamps[index] = @as(u64, @intCast(std.time.nanoTimestamp()));
        self.prefetch_hints[index] = hint;
        
        self.prefetch_count += 1;
        return index;
    }
    
    // SIMD-optimized key operations
    pub fn findKeysSIMD(self: *DODCacheLayout, search_keys: []const []const u8, results: []u32) !u32 {
        var found_count: u32 = 0;
        const simd_batch_size = dod_config.DOD_CONSTANTS.SIMD_KEY_BATCH;
        
        var i: u32 = 0;
        while (i < search_keys.len and found_count < results.len) {
            const batch_size = @min(simd_batch_size, search_keys.len - i);
            
            // Process batch with SIMD optimization
            for (i..i + batch_size) |j| {
                const search_key = search_keys[j];
                const search_hash = std.hash_map.hashString(search_key);
                
                // Search through active keys
                for (0..self.key_count) |k| {
                    if (self.key_active[k] and self.key_hashes[k] == search_hash) {
                        // Verify exact match
                        if (self.key_sizes[k] == search_key.len and 
                            std.mem.eql(u8, self.key_data[k][0..self.key_sizes[k]], search_key)) {
                            results[found_count] = @intCast(k);
                            found_count += 1;
                            break;
                        }
                    }
                }
            }
            
            i += batch_size;
        }
        
        return found_count;
    }
    
    // SIMD-optimized value operations
    pub fn getValuesSIMD(self: *DODCacheLayout, value_indices: []const u32, results: []u8) !u32 {
        var total_copied: u32 = 0;
        const simd_batch_size = dod_config.DOD_CONSTANTS.SIMD_VALUE_BATCH;
        
        var i: u32 = 0;
        while (i < value_indices.len) {
            const batch_size = @min(simd_batch_size, value_indices.len - i);
            
            // Process batch with SIMD optimization
            for (i..i + batch_size) |j| {
                const value_idx = value_indices[j];
                if (value_idx < self.value_count and self.value_active[value_idx]) {
                    const copy_size = @min(self.value_sizes[value_idx], results.len - total_copied);
                    if (copy_size > 0) {
                        @memcpy(results[total_copied..total_copied + copy_size], 
                               self.value_data[value_idx][0..copy_size]);
                        total_copied += copy_size;
                    }
                }
            }
            
            i += batch_size;
        }
        
        return total_copied;
    }
    
    // Tier management
    pub fn updateTierUsage(self: *DODCacheLayout, tier: u8, usage: u32) void {
        if (tier < 4) {
            self.tier_usage[tier] = usage;
        }
    }
    
    pub fn updateTierLatency(self: *DODCacheLayout, tier: u8, latency_ns: u64) void {
        if (tier < 4) {
            self.tier_latencies[tier] = latency_ns;
        }
    }
    
    pub fn updateTierHitRate(self: *DODCacheLayout, tier: u8, hit_rate: f64) void {
        if (tier < 4) {
            self.tier_hit_rates[tier] = hit_rate;
        }
    }
    
    // Get statistics
    pub fn getStats(self: *const DODCacheLayout) DODCacheStats {
        return DODCacheStats{
            .key_count = self.key_count,
            .value_count = self.value_count,
            .metadata_count = self.metadata_count,
            .stats_count = self.stats_count,
            .prefetch_count = self.prefetch_count,
            .key_capacity = dod_config.DOD_CONSTANTS.MAX_KEYS,
            .value_capacity = dod_config.DOD_CONSTANTS.MAX_VALUES,
            .metadata_capacity = dod_config.DOD_CONSTANTS.MAX_METADATA,
            .stats_capacity = dod_config.DOD_CONSTANTS.MAX_STATS,
            .prefetch_capacity = dod_config.DOD_CONSTANTS.MAX_PREFETCH,
            .tier_usage = self.tier_usage,
            .tier_latencies = self.tier_latencies,
            .tier_hit_rates = self.tier_hit_rates,
        };
    }
};

// DOD Cache statistics
pub const DODCacheStats = struct {
    key_count: u32,
    value_count: u32,
    metadata_count: u32,
    stats_count: u32,
    prefetch_count: u32,
    key_capacity: u32,
    value_capacity: u32,
    metadata_capacity: u32,
    stats_capacity: u32,
    prefetch_capacity: u32,
    tier_usage: [4]u32,
    tier_latencies: [4]u64,
    tier_hit_rates: [4]f64,
    
    pub fn getKeyUtilization(self: DODCacheStats) f32 {
        return @as(f32, @floatFromInt(self.key_count)) / @as(f32, @floatFromInt(self.key_capacity));
    }
    
    pub fn getValueUtilization(self: DODCacheStats) f32 {
        return @as(f32, @floatFromInt(self.value_count)) / @as(f32, @floatFromInt(self.value_capacity));
    }
    
    pub fn getMetadataUtilization(self: DODCacheStats) f32 {
        return @as(f32, @floatFromInt(self.metadata_count)) / @as(f32, @floatFromInt(self.metadata_capacity));
    }
    
    pub fn getStatsUtilization(self: DODCacheStats) f32 {
        return @as(f32, @floatFromInt(self.stats_count)) / @as(f32, @floatFromInt(self.stats_capacity));
    }
    
    pub fn getPrefetchUtilization(self: DODCacheStats) f32 {
        return @as(f32, @floatFromInt(self.prefetch_count)) / @as(f32, @floatFromInt(self.prefetch_capacity));
    }
    
    pub fn getOverallUtilization(self: DODCacheStats) f32 {
        const total_used = self.key_count + self.value_count + self.metadata_count + 
                          self.stats_count + self.prefetch_count;
        const total_capacity = self.key_capacity + self.value_capacity + self.metadata_capacity + 
                              self.stats_capacity + self.prefetch_capacity;
        return @as(f32, @floatFromInt(total_used)) / @as(f32, @floatFromInt(total_capacity));
    }
    
    pub fn getTierUtilization(self: DODCacheStats, tier: u32) f32 {
        if (tier >= 4) return 0.0;
        const total_tier_usage = self.tier_usage[0] + self.tier_usage[1] + 
                                self.tier_usage[2] + self.tier_usage[3];
        if (total_tier_usage == 0) return 0.0;
        return @as(f32, @floatFromInt(self.tier_usage[tier])) / @as(f32, @floatFromInt(total_tier_usage));
    }
    
    pub fn getAverageLatency(self: DODCacheStats) u64 {
        const total_latency = self.tier_latencies[0] + self.tier_latencies[1] + 
                             self.tier_latencies[2] + self.tier_latencies[3];
        return total_latency / 4;
    }
    
    pub fn getAverageHitRate(self: DODCacheStats) f64 {
        const total_hit_rate = self.tier_hit_rates[0] + self.tier_hit_rates[1] + 
                              self.tier_hit_rates[2] + self.tier_hit_rates[3];
        return total_hit_rate / 4.0;
    }
};
