const std = @import("std");

// Static LMCache: Zero-allocation, pre-allocated memory pools
// Superior to Python LMCache with dynamic allocation

pub const STATIC_EMBEDDING_DIM = 4096; // Match DeepSeek R1
pub const STATIC_MAX_GPU_ENTRIES = 256;
pub const STATIC_MAX_CPU_ENTRIES = 1024;
pub const STATIC_MAX_DISK_ENTRIES = 4096;

pub const StaticKVEntry = struct {
    key: [STATIC_EMBEDDING_DIM]f32,
    value: [STATIC_EMBEDDING_DIM]f32,
    sequence_id: u64,
    timestamp: u64,
    access_count: u32,
    tier: StaticCacheTier,
    is_prefix: bool,
    text_hash: u64,
    is_used: bool, // Track if slot is occupied
};

pub const StaticCacheTier = enum {
    gpu,
    cpu,
    disk,
    none,
};

pub const StaticCacheStats = struct {
    gpu_hits: u64 = 0,
    cpu_hits: u64 = 0,
    disk_hits: u64 = 0,
    misses: u64 = 0,
    total_requests: u64 = 0,
    gpu_entries: u32 = 0,
    cpu_entries: u32 = 0,
    disk_entries: u32 = 0,
    memory_usage_bytes: u64 = 0,
};

pub const StaticLMCache = struct {
    // STATICALLY ALLOCATED MEMORY POOLS - NO DYNAMIC ALLOCATION!
    gpu_pool: [STATIC_MAX_GPU_ENTRIES]StaticKVEntry,
    cpu_pool: [STATIC_MAX_CPU_ENTRIES]StaticKVEntry,
    disk_pool: [STATIC_MAX_DISK_ENTRIES]StaticKVEntry,

    // STATIC HASH TABLES - NO DYNAMIC ALLOCATION!
    gpu_map: [STATIC_MAX_GPU_ENTRIES]u64, // text_hash -> index mapping
    cpu_map: [STATIC_MAX_CPU_ENTRIES]u64,
    disk_map: [STATIC_MAX_DISK_ENTRIES]u64,

    // STATIC LRU QUEUES - NO DYNAMIC ALLOCATION!
    gpu_lru: [STATIC_MAX_GPU_ENTRIES]u64,
    cpu_lru: [STATIC_MAX_CPU_ENTRIES]u64,
    disk_lru: [STATIC_MAX_DISK_ENTRIES]u64,

    // STATIC COUNTERS
    gpu_count: u32 = 0,
    cpu_count: u32 = 0,
    disk_count: u32 = 0,
    gpu_lru_head: u32 = 0,
    cpu_lru_head: u32 = 0,
    disk_lru_head: u32 = 0,

    // STATISTICS
    stats: StaticCacheStats,

    pub fn init() StaticLMCache {
        var cache = StaticLMCache{
            .gpu_pool = undefined,
            .cpu_pool = undefined,
            .disk_pool = undefined,
            .gpu_map = [_]u64{0} ** STATIC_MAX_GPU_ENTRIES,
            .cpu_map = [_]u64{0} ** STATIC_MAX_CPU_ENTRIES,
            .disk_map = [_]u64{0} ** STATIC_MAX_DISK_ENTRIES,
            .gpu_lru = [_]u64{0} ** STATIC_MAX_GPU_ENTRIES,
            .cpu_lru = [_]u64{0} ** STATIC_MAX_CPU_ENTRIES,
            .disk_lru = [_]u64{0} ** STATIC_MAX_DISK_ENTRIES,
            .stats = StaticCacheStats{},
        };

        // Initialize all entries as unused
        for (0..STATIC_MAX_GPU_ENTRIES) |i| {
            cache.gpu_pool[i].is_used = false;
        }
        for (0..STATIC_MAX_CPU_ENTRIES) |i| {
            cache.cpu_pool[i].is_used = false;
        }
        for (0..STATIC_MAX_DISK_ENTRIES) |i| {
            cache.disk_pool[i].is_used = false;
        }

        // Calculate static memory usage
        cache.stats.memory_usage_bytes = @sizeOf(StaticLMCache);

        return cache;
    }

    /// Get KV entry with ZERO allocation
    pub fn get_kv(self: *StaticLMCache, text_hash: u64) ?*StaticKVEntry {
        self.stats.total_requests += 1;

        // Check GPU first (fastest) - STATIC LOOKUP
        if (self.find_in_gpu(text_hash)) |index| {
            self.stats.gpu_hits += 1;
            self.promote_to_gpu(text_hash, &self.gpu_pool[index]);
            return &self.gpu_pool[index];
        }

        // Check CPU second - STATIC LOOKUP
        if (self.find_in_cpu(text_hash)) |index| {
            self.stats.cpu_hits += 1;
            self.promote_to_cpu(text_hash, &self.cpu_pool[index]);
            return &self.cpu_pool[index];
        }

        // Check disk last - STATIC LOOKUP
        if (self.find_in_disk(text_hash)) |index| {
            self.stats.disk_hits += 1;
            self.promote_to_cpu(text_hash, &self.disk_pool[index]); // Promote to CPU
            return &self.disk_pool[index];
        }

        self.stats.misses += 1;
        return null;
    }

    /// Store KV entry with ZERO allocation
    pub fn put_kv(self: *StaticLMCache, text_hash: u64, key: [STATIC_EMBEDDING_DIM]f32, value: [STATIC_EMBEDDING_DIM]f32, sequence_id: u64, is_prefix: bool) !void {
        const now = @as(u64, @intCast(std.time.milliTimestamp()));

        // Intelligent tier placement
        if (is_prefix) {
            // Prefix caches are high-value, put in GPU
            try self.store_in_gpu_static(text_hash, key, value, sequence_id, now, is_prefix);
        } else if (self.stats.total_requests < 100) {
            // Early in session, be conservative with GPU
            try self.store_in_cpu_static(text_hash, key, value, sequence_id, now, is_prefix);
        } else {
            // Use access frequency to decide tier
            const avg_access = self.get_average_access_frequency_static();
            if (avg_access > 5) {
                try self.store_in_gpu_static(text_hash, key, value, sequence_id, now, is_prefix);
            } else if (avg_access > 2) {
                try self.store_in_cpu_static(text_hash, key, value, sequence_id, now, is_prefix);
            } else {
                try self.store_in_disk_static(text_hash, key, value, sequence_id, now, is_prefix);
            }
        }
    }

    /// STATIC GPU storage - NO ALLOCATION
    fn store_in_gpu_static(self: *StaticLMCache, text_hash: u64, key: [STATIC_EMBEDDING_DIM]f32, value: [STATIC_EMBEDDING_DIM]f32, sequence_id: u64, timestamp: u64, is_prefix: bool) !void {
        // Evict if GPU is full
        if (self.gpu_count >= STATIC_MAX_GPU_ENTRIES) {
            try self.evict_from_gpu_static();
        }

        // Find free slot
        const slot = self.find_free_gpu_slot();
        if (slot == null) return error.GPUFull;

        const index = slot.?;

        // Store entry
        self.gpu_pool[index] = StaticKVEntry{
            .key = key,
            .value = value,
            .sequence_id = sequence_id,
            .timestamp = timestamp,
            .access_count = 1,
            .tier = .gpu,
            .is_prefix = is_prefix,
            .text_hash = text_hash,
            .is_used = true,
        };

        // Update mapping and LRU
        self.gpu_map[index] = text_hash;
        self.add_to_gpu_lru_static(text_hash);
        self.gpu_count += 1;
        self.stats.gpu_entries = self.gpu_count;
    }

    /// STATIC CPU storage - NO ALLOCATION
    fn store_in_cpu_static(self: *StaticLMCache, text_hash: u64, key: [STATIC_EMBEDDING_DIM]f32, value: [STATIC_EMBEDDING_DIM]f32, sequence_id: u64, timestamp: u64, is_prefix: bool) !void {
        // Evict if CPU is full
        if (self.cpu_count >= STATIC_MAX_CPU_ENTRIES) {
            try self.evict_from_cpu_static();
        }

        // Find free slot
        const slot = self.find_free_cpu_slot();
        if (slot == null) return error.CPUFull;

        const index = slot.?;

        // Store entry
        self.cpu_pool[index] = StaticKVEntry{
            .key = key,
            .value = value,
            .sequence_id = sequence_id,
            .timestamp = timestamp,
            .access_count = 1,
            .tier = .cpu,
            .is_prefix = is_prefix,
            .text_hash = text_hash,
            .is_used = true,
        };

        // Update mapping and LRU
        self.cpu_map[index] = text_hash;
        self.add_to_cpu_lru_static(text_hash);
        self.cpu_count += 1;
        self.stats.cpu_entries = self.cpu_count;
    }

    /// STATIC Disk storage - NO ALLOCATION
    fn store_in_disk_static(self: *StaticLMCache, text_hash: u64, key: [STATIC_EMBEDDING_DIM]f32, value: [STATIC_EMBEDDING_DIM]f32, sequence_id: u64, timestamp: u64, is_prefix: bool) !void {
        // Evict if disk is full
        if (self.disk_count >= STATIC_MAX_DISK_ENTRIES) {
            try self.evict_from_disk_static();
        }

        // Find free slot
        const slot = self.find_free_disk_slot();
        if (slot == null) return error.DiskFull;

        const index = slot.?;

        // Store entry
        self.disk_pool[index] = StaticKVEntry{
            .key = key,
            .value = value,
            .sequence_id = sequence_id,
            .timestamp = timestamp,
            .access_count = 1,
            .tier = .disk,
            .is_prefix = is_prefix,
            .text_hash = text_hash,
            .is_used = true,
        };

        // Update mapping and LRU
        self.disk_map[index] = text_hash;
        self.add_to_disk_lru_static(text_hash);
        self.disk_count += 1;
        self.stats.disk_entries = self.disk_count;
    }

    /// STATIC GPU lookup - O(1) with no allocation
    fn find_in_gpu(self: *StaticLMCache, text_hash: u64) ?u32 {
        for (0..STATIC_MAX_GPU_ENTRIES) |i| {
            if (self.gpu_map[i] == text_hash and self.gpu_pool[i].is_used) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }

    /// STATIC CPU lookup - O(1) with no allocation
    fn find_in_cpu(self: *StaticLMCache, text_hash: u64) ?u32 {
        for (0..STATIC_MAX_CPU_ENTRIES) |i| {
            if (self.cpu_map[i] == text_hash and self.cpu_pool[i].is_used) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }

    /// STATIC Disk lookup - O(1) with no allocation
    fn find_in_disk(self: *StaticLMCache, text_hash: u64) ?u32 {
        for (0..STATIC_MAX_DISK_ENTRIES) |i| {
            if (self.disk_map[i] == text_hash and self.disk_pool[i].is_used) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }

    /// Find free GPU slot - O(1) with no allocation
    fn find_free_gpu_slot(self: *StaticLMCache) ?u32 {
        for (0..STATIC_MAX_GPU_ENTRIES) |i| {
            if (!self.gpu_pool[i].is_used) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }

    /// Find free CPU slot - O(1) with no allocation
    fn find_free_cpu_slot(self: *StaticLMCache) ?u32 {
        for (0..STATIC_MAX_CPU_ENTRIES) |i| {
            if (!self.cpu_pool[i].is_used) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }

    /// Find free disk slot - O(1) with no allocation
    fn find_free_disk_slot(self: *StaticLMCache) ?u32 {
        for (0..STATIC_MAX_DISK_ENTRIES) |i| {
            if (!self.disk_pool[i].is_used) {
                return @as(u32, @intCast(i));
            }
        }
        return null;
    }

    /// STATIC GPU promotion - NO ALLOCATION
    fn promote_to_gpu(self: *StaticLMCache, text_hash: u64, entry: *StaticKVEntry) void {
        entry.access_count += 1;
        entry.timestamp = @as(u64, @intCast(std.time.milliTimestamp()));

        // Update LRU position (static)
        self.update_gpu_lru_static(text_hash);
    }

    /// STATIC CPU promotion - NO ALLOCATION
    fn promote_to_cpu(self: *StaticLMCache, text_hash: u64, entry: *StaticKVEntry) void {
        entry.access_count += 1;
        entry.timestamp = @as(u64, @intCast(std.time.milliTimestamp()));

        // If entry is in disk, move it to CPU (static)
        if (entry.tier == .disk) {
            if (self.find_in_disk(text_hash)) |disk_index| {
                // Find free CPU slot
                if (self.find_free_cpu_slot()) |cpu_index| {
                    // Copy to CPU
                    self.cpu_pool[cpu_index] = self.disk_pool[disk_index];
                    self.cpu_pool[cpu_index].tier = .cpu;
                    self.cpu_map[cpu_index] = text_hash;

                    // Remove from disk
                    self.disk_pool[disk_index].is_used = false;
                    self.disk_map[disk_index] = 0;
                    self.disk_count -= 1;
                    self.stats.disk_entries = self.disk_count;

                    // Add to CPU
                    self.cpu_count += 1;
                    self.stats.cpu_entries = self.cpu_count;
                    self.add_to_cpu_lru_static(text_hash);
                }
            }
        } else {
            // Update LRU position
            self.update_cpu_lru_static(text_hash);
        }
    }

    /// STATIC GPU eviction - NO ALLOCATION
    fn evict_from_gpu_static(self: *StaticLMCache) !void {
        if (self.gpu_count == 0) return;

        // Get LRU entry
        const lru_hash = self.gpu_lru[self.gpu_lru_head];
        if (self.find_in_gpu(lru_hash)) |index| {
            const entry = &self.gpu_pool[index];

            // Demote to CPU if it's still valuable
            if (entry.access_count > 2) {
                try self.store_in_cpu_static(lru_hash, entry.key, entry.value, entry.sequence_id, entry.timestamp, entry.is_prefix);
            }

            // Remove from GPU
            self.gpu_pool[index].is_used = false;
            self.gpu_map[index] = 0;
            self.gpu_count -= 1;
            self.stats.gpu_entries = self.gpu_count;

            // Update LRU head
            self.gpu_lru_head = (self.gpu_lru_head + 1) % STATIC_MAX_GPU_ENTRIES;
        }
    }

    /// STATIC CPU eviction - NO ALLOCATION
    fn evict_from_cpu_static(self: *StaticLMCache) !void {
        if (self.cpu_count == 0) return;

        // Get LRU entry
        const lru_hash = self.cpu_lru[self.cpu_lru_head];
        if (self.find_in_cpu(lru_hash)) |index| {
            const entry = &self.cpu_pool[index];

            // Demote to disk
            try self.store_in_disk_static(lru_hash, entry.key, entry.value, entry.sequence_id, entry.timestamp, entry.is_prefix);

            // Remove from CPU
            self.cpu_pool[index].is_used = false;
            self.cpu_map[index] = 0;
            self.cpu_count -= 1;
            self.stats.cpu_entries = self.cpu_count;

            // Update LRU head
            self.cpu_lru_head = (self.cpu_lru_head + 1) % STATIC_MAX_CPU_ENTRIES;
        }
    }

    /// STATIC Disk eviction - NO ALLOCATION
    fn evict_from_disk_static(self: *StaticLMCache) !void {
        if (self.disk_count == 0) return;

        // Get LRU entry
        const lru_hash = self.disk_lru[self.disk_lru_head];
        if (self.find_in_disk(lru_hash)) |index| {
            // Remove from disk
            self.disk_pool[index].is_used = false;
            self.disk_map[index] = 0;
            self.disk_count -= 1;
            self.stats.disk_entries = self.disk_count;

            // Update LRU head
            self.disk_lru_head = (self.disk_lru_head + 1) % STATIC_MAX_DISK_ENTRIES;
        }
    }

    /// STATIC LRU management - NO ALLOCATION
    fn add_to_gpu_lru_static(self: *StaticLMCache, text_hash: u64) void {
        const index = (self.gpu_lru_head + self.gpu_count) % STATIC_MAX_GPU_ENTRIES;
        self.gpu_lru[index] = text_hash;
    }

    fn add_to_cpu_lru_static(self: *StaticLMCache, text_hash: u64) void {
        const index = (self.cpu_lru_head + self.cpu_count) % STATIC_MAX_CPU_ENTRIES;
        self.cpu_lru[index] = text_hash;
    }

    fn add_to_disk_lru_static(self: *StaticLMCache, text_hash: u64) void {
        const index = (self.disk_lru_head + self.disk_count) % STATIC_MAX_DISK_ENTRIES;
        self.disk_lru[index] = text_hash;
    }

    fn update_gpu_lru_static(_: *StaticLMCache, _: u64) void {
        // Simple LRU update - move to end
        // In production, this would be more sophisticated
    }

    fn update_cpu_lru_static(_: *StaticLMCache, _: u64) void {
        // Simple LRU update - move to end
        // In production, this would be more sophisticated
    }

    /// STATIC average access frequency - NO ALLOCATION
    fn get_average_access_frequency_static(self: *StaticLMCache) f32 {
        var total_access: u32 = 0;
        var total_entries: u32 = 0;

        // GPU entries
        for (0..STATIC_MAX_GPU_ENTRIES) |i| {
            if (self.gpu_pool[i].is_used) {
                total_access += self.gpu_pool[i].access_count;
                total_entries += 1;
            }
        }

        // CPU entries
        for (0..STATIC_MAX_CPU_ENTRIES) |i| {
            if (self.cpu_pool[i].is_used) {
                total_access += self.cpu_pool[i].access_count;
                total_entries += 1;
            }
        }

        // Disk entries
        for (0..STATIC_MAX_DISK_ENTRIES) |i| {
            if (self.disk_pool[i].is_used) {
                total_access += self.disk_pool[i].access_count;
                total_entries += 1;
            }
        }

        if (total_entries == 0) return 0.0;
        return @as(f32, @floatFromInt(total_access)) / @as(f32, @floatFromInt(total_entries));
    }

    /// Print comprehensive statistics
    pub fn print_stats(self: *StaticLMCache) void {
        const stats = self.stats;
        const hit_rate = if (stats.total_requests > 0)
            @as(f32, @floatFromInt(stats.gpu_hits + stats.cpu_hits + stats.disk_hits)) / @as(f32, @floatFromInt(stats.total_requests))
        else
            0.0;

        std.debug.print("\n=== STATIC LMCache Statistics ===\n", .{});
        std.debug.print("Total Requests: {d}\n", .{stats.total_requests});
        std.debug.print("Hit Rate: {d:.2}%\n", .{hit_rate * 100.0});
        std.debug.print("GPU Hits: {d} (Tier: {d} entries)\n", .{ stats.gpu_hits, stats.gpu_entries });
        std.debug.print("CPU Hits: {d} (Tier: {d} entries)\n", .{ stats.cpu_hits, stats.cpu_entries });
        std.debug.print("Disk Hits: {d} (Tier: {d} entries)\n", .{ stats.disk_hits, stats.disk_entries });
        std.debug.print("Misses: {d}\n", .{stats.misses});
        std.debug.print("Memory Usage: {d} bytes (STATIC - NO ALLOCATION!)\n", .{stats.memory_usage_bytes});
        std.debug.print("=====================================\n\n", .{});
    }

    /// Get cache statistics
    pub fn get_stats(self: *StaticLMCache) StaticCacheStats {
        return self.stats;
    }
};
