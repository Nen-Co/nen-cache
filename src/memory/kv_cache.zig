const std = @import("std");

// LMCache-inspired Multi-Tier KV Cache for Nen
// Provides fastest time-to-first-token (TTFT) through intelligent caching

pub const KV_CACHE_SIZE = 1024;
pub const EMBEDDING_DIM = 4096; // Match DeepSeek R1 embedding dimension
pub const MAX_SEQUENCE_LENGTH = 8192;

pub const KVEntry = struct {
    text_hash: u64,
    key_vector: [EMBEDDING_DIM]f32,
    value_vector: [EMBEDDING_DIM]f32,
    access_count: u32,
    tier: CacheTier,
    is_used: bool,
    is_valid: bool, // NEW: validity flag
    timestamp: u64,
};

pub const CacheTier = enum {
    gpu,    // Fastest: GPU memory (Metal/CUDA)
    cpu,    // Fast: CPU DRAM
    disk,   // Slow: Local disk (SSD)
    none,   // Not cached
};

pub const CacheStats = struct {
    gpu_hits: u64 = 0,
    cpu_hits: u64 = 0,
    disk_hits: u64 = 0,
    misses: u64 = 0,
    total_requests: u64 = 0,
    gpu_entries: u32 = 0,
    cpu_entries: u32 = 0,
    disk_entries: u32 = 0,
};

pub const LMCache = struct {
    // Multi-tier storage
    gpu_cache: std.AutoHashMap(u64, *KVEntry),      // GPU tier (fastest)
    cpu_cache: std.AutoHashMap(u64, *KVEntry),      // CPU tier (fast)
    disk_cache: std.AutoHashMap(u64, *KVEntry),     // Disk tier (slow)
    
    // Memory pools for each tier
    gpu_pool: std.ArrayList(KVEntry),               // GPU memory pool
    cpu_pool: std.ArrayList(KVEntry),               // CPU memory pool
    disk_pool: std.ArrayList(KVEntry),              // Disk memory pool
    
    // LRU eviction for each tier
    gpu_lru: std.ArrayList(u64),                    // GPU LRU queue
    cpu_lru: std.ArrayList(u64),                    // CPU LRU queue
    disk_lru: std.ArrayList(u64),                   // Disk LRU queue
    
    // Statistics and configuration
    stats: CacheStats,
    allocator: std.mem.Allocator,
    
    // Tier capacity limits
    max_gpu_entries: u32,
    max_cpu_entries: u32,
    max_disk_entries: u32,
    
    pub fn init(allocator: std.mem.Allocator) !LMCache {
        return LMCache{
            .gpu_cache = std.AutoHashMap(u64, *KVEntry).init(allocator),
            .cpu_cache = std.AutoHashMap(u64, *KVEntry).init(allocator),
            .disk_cache = std.AutoHashMap(u64, *KVEntry).init(allocator),
            .gpu_pool = std.ArrayList(KVEntry).init(allocator),
            .cpu_pool = std.ArrayList(KVEntry).init(allocator),
            .disk_pool = std.ArrayList(KVEntry).init(allocator),
            .gpu_lru = std.ArrayList(u64).init(allocator),
            .cpu_lru = std.ArrayList(u64).init(allocator),
            .disk_lru = std.ArrayList(u64).init(allocator),
            .stats = CacheStats{},
            .allocator = allocator,
            .max_gpu_entries = 256,   // GPU memory is precious
            .max_cpu_entries = 1024,  // CPU DRAM is fast
            .max_disk_entries = 4096, // Disk is plentiful
        };
    }
    
    pub fn deinit(self: *LMCache) void {
        self.gpu_cache.deinit();
        self.cpu_cache.deinit();
        self.disk_cache.deinit();
        self.gpu_pool.deinit();
        self.cpu_pool.deinit();
        self.disk_pool.deinit();
        self.gpu_lru.deinit();
        self.cpu_lru.deinit();
        self.disk_lru.deinit();
    }
    
    /// Get KV cache entry with automatic tier promotion
    pub fn get_kv(self: *LMCache, text_hash: u64) ?*KVEntry {
        self.stats.total_requests += 1;
        
        // Check GPU tier first
        for (self.gpu_pool.items) |*entry| {
            if (entry.text_hash == text_hash) {
                if (!self.is_valid_pool_pointer(entry)) {
                    std.debug.print("[cache] get_kv: INVALID POINTER {x} for hash {x} in GPU pool!\n", .{@intFromPtr(entry), text_hash});
                    return null;
                }
                if (entry.is_valid) {
                    std.debug.print("[cache] get_kv: hit for hash {x}, access_count {d}, is_valid={}\n", .{text_hash, entry.access_count, entry.is_valid});
                    self.promote_to_gpu(text_hash, entry);
                    return entry;
                }
            }
        }
        
        // Check CPU tier
        for (self.cpu_pool.items) |*entry| {
            if (entry.text_hash == text_hash) {
                if (!self.is_valid_pool_pointer(entry)) {
                    std.debug.print("[cache] get_kv: INVALID POINTER {x} for hash {x} in CPU pool!\n", .{@intFromPtr(entry), text_hash});
                    return null;
                }
                if (entry.is_valid) {
                    std.debug.print("[cache] get_kv: hit for hash {x}, access_count {d}, is_valid={}\n", .{text_hash, entry.access_count, entry.is_valid});
                    self.promote_to_gpu(text_hash, entry);
                    return entry;
                }
            }
        }
        
        // Check disk tier
        for (self.disk_pool.items) |*entry| {
            if (entry.text_hash == text_hash) {
                if (!self.is_valid_pool_pointer(entry)) {
                    std.debug.print("[cache] get_kv: INVALID POINTER {x} for hash {x} in disk pool!\n", .{@intFromPtr(entry), text_hash});
                    return null;
                }
                if (entry.is_valid) {
                    std.debug.print("[cache] get_kv: hit for hash {x}, access_count {d}, is_valid={}\n", .{text_hash, entry.access_count, entry.is_valid});
                    self.promote_to_gpu(text_hash, entry);
                    return entry;
                }
            }
        }
        
        std.debug.print("[cache] get_kv: miss or invalid for hash {x}\n", .{text_hash});
        return null;
    }
    
    /// Store KV cache entry with intelligent tier placement
    pub fn put_kv(self: *LMCache, text_hash: u64, key_vector: [EMBEDDING_DIM]f32, value_vector: [EMBEDDING_DIM]f32, tier: CacheTier, is_used: bool) !void {
        const entry = KVEntry{
            .text_hash = text_hash,
            .key_vector = key_vector,
            .value_vector = value_vector,
            .access_count = 1,
            .tier = tier,
            .is_used = is_used,
            .is_valid = true, // NEW: mark as valid
            .timestamp = @as(u64, @intCast(std.time.milliTimestamp())),
        };
        
        // Intelligent tier placement based on access patterns
        if (is_used) {
            // Prefix caches are high-value, put in GPU
            try self.store_in_gpu(text_hash, entry);
        } else if (self.stats.total_requests < 100) {
            // Early in session, be conservative with GPU
            try self.store_in_cpu(text_hash, entry);
        } else {
            // Use access frequency to decide tier
            const avg_access = self.get_average_access_frequency();
            if (avg_access > 5) {
                try self.store_in_gpu(text_hash, entry);
            } else if (avg_access > 2) {
                try self.store_in_cpu(text_hash, entry);
            } else {
                try self.store_in_disk(text_hash, entry);
            }
        }
    }
    
    /// Store entry in GPU tier (fastest)
    fn store_in_gpu(self: *LMCache, text_hash: u64, entry: KVEntry) !void {
        // Evict if GPU is full
        if (self.gpu_cache.count() >= self.max_gpu_entries) {
            try self.evict_from_gpu();
        }
        
        // Allocate from GPU pool
        try self.gpu_pool.append(entry);
        const entry_ptr = &self.gpu_pool.items[self.gpu_pool.items.len - 1];
        entry_ptr.tier = .gpu;
        
        try self.gpu_cache.put(text_hash, entry_ptr);
        try self.gpu_lru.append(text_hash);
        self.stats.gpu_entries = @as(u32, @intCast(self.gpu_cache.count()));
    }
    
    /// Store entry in CPU tier (fast)
    fn store_in_cpu(self: *LMCache, text_hash: u64, entry: KVEntry) !void {
        // Evict if CPU is full
        if (self.cpu_cache.count() >= self.max_cpu_entries) {
            try self.evict_from_cpu();
        }
        
        // Allocate from CPU pool
        try self.cpu_pool.append(entry);
        const entry_ptr = &self.cpu_pool.items[self.cpu_pool.items.len - 1];
        entry_ptr.tier = .cpu;
        
        try self.cpu_cache.put(text_hash, entry_ptr);
        try self.cpu_lru.append(text_hash);
        self.stats.cpu_entries = @as(u32, @intCast(self.cpu_cache.count()));
    }
    
    /// Store entry in disk tier (slow but plentiful)
    fn store_in_disk(self: *LMCache, text_hash: u64, entry: KVEntry) !void {
        // Evict if disk is full
        if (self.disk_cache.count() >= self.max_disk_entries) {
            try self.evict_from_disk();
        }
        
        // Allocate from disk pool
        try self.disk_pool.append(entry);
        const entry_ptr = &self.disk_pool.items[self.disk_pool.items.len - 1];
        entry_ptr.tier = .disk;
        
        try self.disk_cache.put(text_hash, entry_ptr);
        try self.disk_lru.append(text_hash);
        self.stats.disk_entries = @as(u32, @intCast(self.disk_cache.count()));
    }
    
    pub fn is_valid_pool_pointer(self: *LMCache, ptr: ?*KVEntry) bool {
        if (ptr == null) return false;
        const ptr_val = @intFromPtr(ptr);
        
        // Check if pointer is in any of our pools
        for (self.gpu_pool.items) |*entry| {
            const entry_ptr = @intFromPtr(entry);
            if (ptr_val == entry_ptr and entry.is_valid) {
                return true;
            }
        }
        for (self.cpu_pool.items) |*entry| {
            const entry_ptr = @intFromPtr(entry);
            if (ptr_val == entry_ptr and entry.is_valid) {
                return true;
            }
        }
        for (self.disk_pool.items) |*entry| {
            const entry_ptr = @intFromPtr(entry);
            if (ptr_val == entry_ptr and entry.is_valid) {
                return true;
            }
        }
        return false;
    }

    pub fn print_valid_pointers(self: *LMCache) void {
        std.debug.print("[cache] Valid GPU pool pointers: ", .{});
        for (self.gpu_pool.items) |*entry| {
            if (entry.is_valid) {
                std.debug.print("{x} ", .{@intFromPtr(entry)});
            }
        }
        std.debug.print("\n[cache] Valid CPU pool pointers: ", .{});
        for (self.cpu_pool.items) |*entry| {
            if (entry.is_valid) {
                std.debug.print("{x} ", .{@intFromPtr(entry)});
            }
        }
        std.debug.print("\n[cache] Valid disk pool pointers: ", .{});
        for (self.disk_pool.items) |*entry| {
            if (entry.is_valid) {
                std.debug.print("{x} ", .{@intFromPtr(entry)});
            }
        }
        std.debug.print("\n", .{});
    }

    pub fn promote_to_gpu(self: *LMCache, text_hash: u64, entry: ?*KVEntry) void {
        if (entry == null) {
            std.debug.print("[cache] promote_to_gpu: entry is null for hash {x}\n", .{text_hash});
            return;
        }
        const ptr_val = @intFromPtr(entry);
        std.debug.print("[cache] promote_to_gpu: entry ptr={x} for hash {x}\n", .{ptr_val, text_hash});
        
        if (!self.is_valid_pool_pointer(entry)) {
            std.debug.print("[cache] promote_to_gpu: INVALID POINTER {x} for hash {x}!\n", .{ptr_val, text_hash});
            std.debug.print("[cache] Current valid pointers:\n", .{});
            self.print_valid_pointers();
            return;
        }
        
        if (!entry.?.is_valid) {
            std.debug.print("[cache] promote_to_gpu: entry is NOT VALID for hash {x}, skipping\n", .{text_hash});
            return;
        }
        entry.?.access_count += 1;
        std.debug.print("[cache] promote_to_gpu: promoted entry for hash {x}, access_count now {d}, is_valid={}\n", .{text_hash, entry.?.access_count, entry.?.is_valid});
        entry.?.timestamp = @as(u64, @intCast(std.time.milliTimestamp()));
        
        // Update LRU position
        self.update_lru_position(&self.gpu_lru, text_hash);
    }
    
    /// Promote entry to CPU tier
    fn promote_to_cpu(self: *LMCache, text_hash: u64, entry: *KVEntry) void {
        entry.access_count += 1;
        entry.timestamp = @as(u64, @intCast(std.time.milliTimestamp()));
        
        // If entry is in disk, move it to CPU
        if (entry.tier == .disk) {
            _ = self.disk_cache.remove(text_hash);
            self.remove_from_lru(&self.disk_lru, text_hash);
            self.stats.disk_entries -= 1;
            
            // Add to CPU
            self.cpu_cache.put(text_hash, entry) catch return;
            self.cpu_lru.append(text_hash) catch return;
            entry.tier = .cpu;
            self.stats.cpu_entries += 1;
        } else {
            // Update LRU position
            self.update_lru_position(&self.cpu_lru, text_hash);
        }
    }
    
    /// Evict least recently used entry from GPU
    fn evict_from_gpu(self: *LMCache) !void {
        if (self.gpu_lru.items.len == 0) return;
        
        const lru_hash = self.gpu_lru.orderedRemove(0);
        const entry = self.gpu_cache.get(lru_hash) orelse return;
        
        // Demote to CPU if it's still valuable
        if (entry.access_count > 2) {
            try self.store_in_cpu(lru_hash, entry.*);
        } else {
            // Remove completely
            _ = self.gpu_cache.remove(lru_hash);
            self.stats.gpu_entries -= 1;
        }
    }
    
    /// Evict least recently used entry from CPU
    fn evict_from_cpu(self: *LMCache) !void {
        if (self.cpu_lru.items.len == 0) return;
        
        const lru_hash = self.cpu_lru.orderedRemove(0);
        const entry = self.cpu_cache.get(lru_hash) orelse return;
        
        // Demote to disk
        try self.store_in_disk(lru_hash, entry.*);
        _ = self.cpu_cache.remove(lru_hash);
        self.stats.cpu_entries -= 1;
    }
    
    /// Evict least recently used entry from disk
    fn evict_from_disk(self: *LMCache) !void {
        if (self.disk_lru.items.len == 0) return;
        
        const lru_hash = self.disk_lru.orderedRemove(0);
        _ = self.disk_cache.remove(lru_hash);
        self.stats.disk_entries -= 1;
    }
    
    /// Update LRU position (move to end)
    fn update_lru_position(self: *LMCache, lru: *std.ArrayList(u64), text_hash: u64) void {
        // Find and remove from current position
        self.remove_from_lru(lru, text_hash);
        // Add to end (most recently used)
        lru.append(text_hash) catch return;
    }
    
    /// Remove entry from LRU list
    fn remove_from_lru(_: *LMCache, lru: *std.ArrayList(u64), text_hash: u64) void {
        for (lru.items, 0..) |hash, i| {
            if (hash == text_hash) {
                _ = lru.orderedRemove(i);
                break;
            }
        }
    }
    
    /// Get average access frequency across all tiers
    fn get_average_access_frequency(self: *LMCache) f32 {
        var total_access: u32 = 0;
        var total_entries: u32 = 0;
        
        // GPU entries
        var gpu_iter = self.gpu_cache.iterator();
        while (gpu_iter.next()) |entry| {
            total_access += entry.value_ptr.*.access_count;
            total_entries += 1;
        }
        
        // CPU entries
        var cpu_iter = self.cpu_cache.iterator();
        while (cpu_iter.next()) |entry| {
            total_access += entry.value_ptr.*.access_count;
            total_entries += 1;
        }
        
        // Disk entries
        var disk_iter = self.disk_cache.iterator();
        while (disk_iter.next()) |entry| {
            total_access += entry.value_ptr.*.access_count;
            total_entries += 1;
        }
        
        if (total_entries == 0) return 0.0;
        return @as(f32, @floatFromInt(total_access)) / @as(f32, @floatFromInt(total_entries));
    }
    
    /// Get cache statistics
    pub fn get_stats(self: *LMCache) CacheStats {
        return self.stats;
    }
    
    /// Print cache statistics
    pub fn print_stats(self: *LMCache) void {
        const stats = self.get_stats();
        const hit_rate = if (stats.total_requests > 0) 
            @as(f32, @floatFromInt(stats.gpu_hits + stats.cpu_hits + stats.disk_hits)) / @as(f32, @floatFromInt(stats.total_requests))
        else 0.0;
        
        std.debug.print("\n=== LMCache Statistics ===\n", .{});
        std.debug.print("Total Requests: {d}\n", .{stats.total_requests});
        std.debug.print("Hit Rate: {d:.2}%\n", .{hit_rate * 100.0});
        std.debug.print("GPU Hits: {d} (Tier: {d} entries)\n", .{stats.gpu_hits, stats.gpu_entries});
        std.debug.print("CPU Hits: {d} (Tier: {d} entries)\n", .{stats.cpu_hits, stats.cpu_entries});
        std.debug.print("Disk Hits: {d} (Tier: {d} entries)\n", .{stats.disk_hits, stats.disk_entries});
        std.debug.print("Misses: {d}\n", .{stats.misses});
        std.debug.print("========================\n\n", .{});
    }
    
    /// Save cache state to disk for persistence
    pub fn save_to_disk(self: *LMCache, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/lmcache.bin", .{dir});
        defer self.allocator.free(file_path);
        
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true });
        defer file.close();
        
        // Write cache entries
        var writer = file.writer();
        
        // Write GPU entries
        const gpu_count = @as(u32, @intCast(self.gpu_cache.count()));
        try writer.writeAll(&[_]u8{ @as(u8, @intCast(gpu_count & 0xFF)), @as(u8, @intCast((gpu_count >> 8) & 0xFF)), @as(u8, @intCast((gpu_count >> 16) & 0xFF)), @as(u8, @intCast((gpu_count >> 24) & 0xFF)) });
        var gpu_iter = self.gpu_cache.iterator();
        while (gpu_iter.next()) |entry| {
            // Write entry as raw bytes
            const entry_value = entry.value_ptr.*;
            const entry_bytes = @as([*]const u8, @ptrCast(&entry_value))[0..@sizeOf(KVEntry)];
            try writer.writeAll(entry_bytes);
        }
        
        // Write CPU entries
        const cpu_count = @as(u32, @intCast(self.cpu_cache.count()));
        try writer.writeAll(&[_]u8{ @as(u8, @intCast(cpu_count & 0xFF)), @as(u8, @intCast((cpu_count >> 8) & 0xFF)), @as(u8, @intCast((cpu_count >> 16) & 0xFF)), @as(u8, @intCast((cpu_count >> 24) & 0xFF)) });
        var cpu_iter = self.cpu_cache.iterator();
        while (cpu_iter.next()) |entry| {
            // Write entry as raw bytes
            const entry_value = entry.value_ptr.*;
            const entry_bytes = @as([*]const u8, @ptrCast(&entry_value))[0..@sizeOf(KVEntry)];
            try writer.writeAll(entry_bytes);
        }
        
        // Write disk entries
        const disk_count = @as(u32, @intCast(self.disk_cache.count()));
        try writer.writeAll(&[_]u8{ @as(u8, @intCast(disk_count & 0xFF)), @as(u8, @intCast((disk_count >> 8) & 0xFF)), @as(u8, @intCast((disk_count >> 16) & 0xFF)), @as(u8, @intCast((disk_count >> 24) & 0xFF)) });
        var disk_iter = self.disk_cache.iterator();
        while (disk_iter.next()) |entry| {
            // Write entry as raw bytes
            const entry_value = entry.value_ptr.*;
            const entry_bytes = @as([*]const u8, @ptrCast(&entry_value))[0..@sizeOf(KVEntry)];
            try writer.writeAll(entry_bytes);
        }
    }
    
    /// Load cache state from disk
    pub fn load_from_disk(self: *LMCache, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/lmcache.bin", .{dir});
        defer self.allocator.free(file_path);
        
        var file = std.fs.cwd().openFile(file_path, .{}) catch return;
        defer file.close();
        
        var reader = file.reader();
        
        // Read GPU entries
        var gpu_count_bytes: [4]u8 = undefined;
        _ = try reader.readAll(&gpu_count_bytes);
        const gpu_count = @as(u32, gpu_count_bytes[0]) | (@as(u32, gpu_count_bytes[1]) << 8) | (@as(u32, gpu_count_bytes[2]) << 16) | (@as(u32, gpu_count_bytes[3]) << 24);
        for (0..gpu_count) |_| {
            var entry: KVEntry = undefined;
            const entry_bytes = @as([*]u8, @ptrCast(&entry))[0..@sizeOf(KVEntry)];
            _ = try reader.readAll(entry_bytes);
            try self.store_in_gpu(entry.text_hash, entry);
        }
        
        // Read CPU entries
        var cpu_count_bytes: [4]u8 = undefined;
        _ = try reader.readAll(&cpu_count_bytes);
        const cpu_count = @as(u32, cpu_count_bytes[0]) | (@as(u32, cpu_count_bytes[1]) << 8) | (@as(u32, cpu_count_bytes[2]) << 16) | (@as(u32, cpu_count_bytes[3]) << 24);
        for (0..cpu_count) |_| {
            var entry: KVEntry = undefined;
            const entry_bytes = @as([*]u8, @ptrCast(&entry))[0..@sizeOf(KVEntry)];
            _ = try reader.readAll(entry_bytes);
            try self.store_in_cpu(entry.text_hash, entry);
        }
        
        // Read disk entries
        var disk_count_bytes: [4]u8 = undefined;
        _ = try reader.readAll(&disk_count_bytes);
        const disk_count = @as(u32, disk_count_bytes[0]) | (@as(u32, disk_count_bytes[1]) << 8) | (@as(u32, disk_count_bytes[2]) << 16) | (@as(u32, disk_count_bytes[3]) << 24);
        for (0..disk_count) |_| {
            var entry: KVEntry = undefined;
            const entry_bytes = @as([*]u8, @ptrCast(&entry))[0..@sizeOf(KVEntry)];
            _ = try reader.readAll(entry_bytes);
            try self.store_in_disk(entry.text_hash, entry);
        }
    }
}; 