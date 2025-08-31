// Static Memory Pools for NenCache
// Zero-allocation memory management for maximum performance

const std = @import("std");
const mem = std.mem;
const math = std.math;

// Configuration constants
pub const STATIC_POOL_SIZES = struct {
    pub const GPU_ENTRIES = 256;
    pub const CPU_ENTRIES = 1024;
    pub const NVME_ENTRIES = 4096;
    pub const DISK_ENTRIES = 16384;
    
    pub const GPU_ENTRY_SIZE = 4096;    // 4KB per entry
    pub const CPU_ENTRY_SIZE = 8192;    // 8KB per entry
    pub const NVME_ENTRY_SIZE = 32768;  // 32KB per entry
    pub const DISK_ENTRY_SIZE = 131072; // 128KB per entry
};

// Static memory pool entry
pub const StaticPoolEntry = struct {
    data: []u8,
    key_hash: u64,
    timestamp: i64,
    access_count: u32,
    is_used: bool,
    next_free: ?usize, // For free list management
    
    pub fn init(data: []u8) StaticPoolEntry {
        return StaticPoolEntry{
            .data = data,
            .key_hash = 0,
            .timestamp = 0,
            .access_count = 0,
            .is_used = false,
            .next_free = null,
        };
    }
    
    pub fn reset(self: *StaticPoolEntry) void {
        self.key_hash = 0;
        self.timestamp = 0;
        self.access_count = 0;
        self.is_used = false;
        self.next_free = null;
    }
};

// Static memory pool for a specific tier
pub const StaticMemoryPool = struct {
    entries: []StaticPoolEntry,
    data_buffer: []u8,
    free_list_head: ?usize,
    used_count: usize,
    max_entries: usize,
    entry_size: usize,
    
    pub fn init(entry_size: usize, max_entries: usize) !StaticMemoryPool {
        // Allocate the data buffer
        const total_data_size = entry_size * max_entries;
        const data_buffer = try std.heap.page_allocator.alloc(u8, total_data_size);
        
        // Allocate entry metadata
        const entries = try std.heap.page_allocator.alloc(StaticPoolEntry, max_entries);
        
        // Initialize entries and free list
        for (0..max_entries) |i| {
            const data_start = i * entry_size;
            const data_end = data_start + entry_size;
            entries[i] = StaticPoolEntry.init(data_buffer[data_start..data_end]);
            
            if (i < max_entries - 1) {
                entries[i].next_free = i + 1;
            } else {
                entries[i].next_free = null;
            }
        }
        
        return StaticMemoryPool{
            .entries = entries,
            .data_buffer = data_buffer,
            .free_list_head = 0, // Start with first entry as free
            .used_count = 0,
            .max_entries = max_entries,
            .entry_size = entry_size,
        };
    }
    
    pub fn deinit(self: *StaticMemoryPool) void {
        std.heap.page_allocator.free(self.entries);
        std.heap.page_allocator.free(self.data_buffer);
    }
    
    // Allocate an entry from the pool (ZERO allocation)
    pub fn allocate(self: *StaticMemoryPool) ?*StaticPoolEntry {
        if (self.free_list_head) |free_index| {
            const entry = &self.entries[free_index];
            self.free_list_head = entry.next_free;
            entry.is_used = true;
            self.used_count += 1;
            return entry;
        }
        return null; // Pool is full
    }
    
    // Free an entry back to the pool
    pub fn free(self: *StaticMemoryPool, entry: *StaticPoolEntry) void {
        if (!entry.is_used) return; // Already freed
        
        entry.reset();
        entry.next_free = self.free_list_head;
        
        // Calculate index by finding the entry in the array
        for (0..self.entries.len) |i| {
            if (&self.entries[i] == entry) {
                self.free_list_head = i;
                break;
            }
        }
        
        self.used_count -= 1;
    }
    
    // Find entry by key hash
    pub fn find(self: *StaticMemoryPool, key_hash: u64) ?*StaticPoolEntry {
        for (self.entries) |*entry| {
            if (entry.is_used and entry.key_hash == key_hash) {
                return entry;
            }
        }
        return null;
    }
    
    // Get pool statistics
    pub fn getStats(self: *StaticMemoryPool) struct {
        total_entries: usize,
        used_entries: usize,
        free_entries: usize,
        utilization_percent: f64,
        memory_usage_bytes: usize,
    } {
        const free_entries = self.max_entries - self.used_count;
        const utilization_percent = if (self.max_entries > 0) 
            (@as(f64, @floatFromInt(self.used_count)) / @as(f64, @floatFromInt(self.max_entries))) * 100.0
        else 0.0;
        
        return .{
            .total_entries = self.max_entries,
            .used_entries = self.used_count,
            .free_entries = free_entries,
            .utilization_percent = utilization_percent,
            .memory_usage_bytes = self.max_entries * self.entry_size,
        };
    }
    
    // Evict least recently used entry
    pub fn evictLRU(self: *StaticMemoryPool) ?*StaticPoolEntry {
        var oldest_timestamp: i64 = std.math.maxInt(i64);
        var oldest_entry: ?*StaticPoolEntry = null;
        
        for (self.entries) |*entry| {
            if (entry.is_used and entry.timestamp < oldest_timestamp) {
                oldest_timestamp = entry.timestamp;
                oldest_entry = entry;
            }
        }
        
        if (oldest_entry) |entry| {
            // Mark as evicted but don't free yet
            entry.is_used = false;
            self.used_count -= 1;
            
            // Add to free list
            entry.next_free = self.free_list_head;
            self.free_list_head = self.findEntryIndex(entry);
            
            return entry;
        }
        
        return null;
    }
    
    // Helper function to find entry index
    fn findEntryIndex(self: *StaticMemoryPool, entry: *StaticPoolEntry) usize {
        for (0..self.entries.len) |i| {
            if (&self.entries[i] == entry) {
                return i;
            }
        }
        return 0; // Fallback
    }
};

// Tier-specific static memory pools
pub const GPUMemoryPool = struct {
    pool: StaticMemoryPool,
    
    pub fn init() !GPUMemoryPool {
        const pool = try StaticMemoryPool.init(
            STATIC_POOL_SIZES.GPU_ENTRY_SIZE,
            STATIC_POOL_SIZES.GPU_ENTRIES
        );
        return GPUMemoryPool{ .pool = pool };
    }
    
    pub fn deinit(self: *GPUMemoryPool) void {
        self.pool.deinit();
    }
    
    pub fn allocate(self: *GPUMemoryPool) ?*StaticPoolEntry {
        return self.pool.allocate();
    }
    
    pub fn free(self: *GPUMemoryPool, entry: *StaticPoolEntry) void {
        self.pool.free(entry);
    }
    
    pub fn find(self: *GPUMemoryPool, key_hash: u64) ?*StaticPoolEntry {
        return self.pool.find(key_hash);
    }
    
    pub fn getStats(self: *GPUMemoryPool) @TypeOf(self.pool.getStats()) {
        return self.pool.getStats();
    }
};

pub const CPUMemoryPool = struct {
    pool: StaticMemoryPool,
    
    pub fn init() !CPUMemoryPool {
        const pool = try StaticMemoryPool.init(
            STATIC_POOL_SIZES.CPU_ENTRY_SIZE,
            STATIC_POOL_SIZES.CPU_ENTRIES
        );
        return CPUMemoryPool{ .pool = pool };
    }
    
    pub fn deinit(self: *CPUMemoryPool) void {
        self.pool.deinit();
    }
    
    pub fn allocate(self: *CPUMemoryPool) ?*StaticPoolEntry {
        return self.pool.allocate();
    }
    
    pub fn free(self: *CPUMemoryPool, entry: *StaticPoolEntry) void {
        self.pool.free(entry);
    }
    
    pub fn find(self: *CPUMemoryPool, key_hash: u64) ?*StaticPoolEntry {
        return self.pool.find(key_hash);
    }
    
    pub fn getStats(self: *CPUMemoryPool) @TypeOf(self.pool.getStats()) {
        return self.pool.getStats();
    }
};

pub const NVMEMemoryPool = struct {
    pool: StaticMemoryPool,
    
    pub fn init() !NVMEMemoryPool {
        const pool = try StaticMemoryPool.init(
            STATIC_POOL_SIZES.NVME_ENTRY_SIZE,
            STATIC_POOL_SIZES.NVME_ENTRIES
        );
        return NVMEMemoryPool{ .pool = pool };
    }
    
    pub fn deinit(self: *NVMEMemoryPool) void {
        self.pool.deinit();
    }
    
    pub fn allocate(self: *NVMEMemoryPool) ?*StaticPoolEntry {
        return self.pool.allocate();
    }
    
    pub fn free(self: *NVMEMemoryPool, entry: *StaticPoolEntry) void {
        self.pool.free(entry);
    }
    
    pub fn find(self: *NVMEMemoryPool, key_hash: u64) ?*StaticPoolEntry {
        return self.pool.find(key_hash);
    }
    
    pub fn getStats(self: *NVMEMemoryPool) @TypeOf(self.pool.getStats()) {
        return self.pool.getStats();
    }
};

pub const DiskMemoryPool = struct {
    pool: StaticMemoryPool,
    
    pub fn init() !DiskMemoryPool {
        const pool = try StaticMemoryPool.init(
            STATIC_POOL_SIZES.DISK_ENTRY_SIZE,
            STATIC_POOL_SIZES.DISK_ENTRIES
        );
        return DiskMemoryPool{ .pool = pool };
    }
    
    pub fn deinit(self: *DiskMemoryPool) void {
        self.pool.deinit();
    }
    
    pub fn allocate(self: *DiskMemoryPool) ?*StaticPoolEntry {
        return self.pool.allocate();
    }
    
    pub fn free(self: *DiskMemoryPool, entry: *StaticPoolEntry) void {
        self.pool.free(entry);
    }
    
    pub fn find(self: *DiskMemoryPool, key_hash: u64) ?*StaticPoolEntry {
        return self.pool.find(key_hash);
    }
    
    pub fn getStats(self: *DiskMemoryPool) @TypeOf(self.pool.getStats()) {
        return self.pool.getStats();
    }
};

// Global memory pool manager
pub const MemoryPoolManager = struct {
    gpu_pool: GPUMemoryPool,
    cpu_pool: CPUMemoryPool,
    nvme_pool: NVMEMemoryPool,
    disk_pool: DiskMemoryPool,
    
    pub fn init() !MemoryPoolManager {
        return MemoryPoolManager{
            .gpu_pool = try GPUMemoryPool.init(),
            .cpu_pool = try CPUMemoryPool.init(),
            .nvme_pool = try NVMEMemoryPool.init(),
            .disk_pool = try DiskMemoryPool.init(),
        };
    }
    
    pub fn deinit(self: *MemoryPoolManager) void {
        self.gpu_pool.deinit();
        self.cpu_pool.deinit();
        self.nvme_pool.deinit();
        self.disk_pool.deinit();
    }
    
    // Get total memory usage across all pools
    pub fn getTotalMemoryUsage(self: *MemoryPoolManager) usize {
        const gpu_stats = self.gpu_pool.getStats();
        const cpu_stats = self.cpu_pool.getStats();
        const nvme_stats = self.nvme_pool.getStats();
        const disk_stats = self.disk_pool.getStats();
        
        return gpu_stats.memory_usage_bytes + 
               cpu_stats.memory_usage_bytes + 
               nvme_stats.memory_usage_bytes + 
               disk_stats.memory_usage_bytes;
    }
    
    // Get overall utilization statistics
    pub fn getOverallStats(self: *MemoryPoolManager) struct {
        total_memory_bytes: usize,
        used_memory_bytes: usize,
        total_entries: usize,
        used_entries: usize,
        overall_utilization_percent: f64,
    } {
        const gpu_stats = self.gpu_pool.getStats();
        const cpu_stats = self.cpu_pool.getStats();
        const nvme_stats = self.nvme_pool.getStats();
        const disk_stats = self.disk_pool.getStats();
        
        const total_memory = gpu_stats.memory_usage_bytes + 
                            cpu_stats.memory_usage_bytes + 
                            nvme_stats.memory_usage_bytes + 
                            disk_stats.memory_usage_bytes;
        
        const total_entries = gpu_stats.total_entries + 
                             cpu_stats.total_entries + 
                             nvme_stats.total_entries + 
                             disk_stats.total_entries;
        
        const used_entries = gpu_stats.used_entries + 
                            cpu_stats.used_entries + 
                            nvme_stats.used_entries + 
                            disk_stats.used_entries;
        
        const overall_utilization = if (total_entries > 0) 
            (@as(f64, @floatFromInt(used_entries)) / @as(f64, @floatFromInt(total_entries))) * 100.0
        else 0.0;
        
        return .{
            .total_memory_bytes = total_memory,
            .used_memory_bytes = total_memory, // Static allocation, so used = total
            .total_entries = total_entries,
            .used_entries = used_entries,
            .overall_utilization_percent = overall_utilization,
        };
    }
};
