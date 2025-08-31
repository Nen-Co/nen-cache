// Tests for Static Memory Pools
// Verify zero-allocation behavior and correct functionality

const std = @import("std");
const testing = std.testing;

const StaticMemoryPool = @import("static_pools.zig").StaticMemoryPool;
const StaticPoolEntry = @import("static_pools.zig").StaticPoolEntry;
const GPUMemoryPool = @import("static_pools.zig").GPUMemoryPool;
const CPUMemoryPool = @import("static_pools.zig").CPUMemoryPool;
const NVMEMemoryPool = @import("static_pools.zig").NVMEMemoryPool;
const DiskMemoryPool = @import("static_pools.zig").DiskMemoryPool;
const MemoryPoolManager = @import("static_pools.zig").MemoryPoolManager;

test "StaticMemoryPool basic functionality" {
    const entry_size = 1024;
    const max_entries = 10;
    
    var pool = try StaticMemoryPool.init(entry_size, max_entries);
    defer pool.deinit();
    
    // Test initial state
    try testing.expectEqual(@as(usize, 0), pool.used_count);
    try testing.expectEqual(@as(usize, max_entries), pool.entries.len);
    try testing.expectEqual(@as(usize, entry_size * max_entries), pool.data_buffer.len);
    
    // Test allocation
    const entry1 = pool.allocate();
    try testing.expect(entry1 != null);
    try testing.expectEqual(@as(usize, 1), pool.used_count);
    
    const entry2 = pool.allocate();
    try testing.expect(entry2 != null);
    try testing.expectEqual(@as(usize, 2), pool.used_count);
    
    // Test entry properties
    try testing.expect(entry1.?.is_used);
    try testing.expect(entry2.?.is_used);
    try testing.expectEqual(@as(usize, entry_size), entry1.?.data.len);
    try testing.expectEqual(@as(usize, entry_size), entry2.?.data.len);
    
    // Test freeing
    pool.free(entry1.?);
    try testing.expectEqual(@as(usize, 1), pool.used_count);
    try testing.expect(!entry1.?.is_used);
    
    // Test reallocation
    const entry3 = pool.allocate();
    try testing.expect(entry3 != null);
    try testing.expectEqual(@as(usize, 2), pool.used_count);
}

test "StaticMemoryPool full allocation" {
    const entry_size = 512;
    const max_entries = 5;
    
    var pool = try StaticMemoryPool.init(entry_size, max_entries);
    defer pool.deinit();
    
    // Allocate all entries
    var entries: [max_entries]*StaticPoolEntry = undefined;
    for (0..max_entries) |i| {
        entries[i] = pool.allocate() orelse return error.AllocationFailed;
        try testing.expectEqual(@as(usize, i + 1), pool.used_count);
    }
    
    // Try to allocate one more (should fail)
    const extra_entry = pool.allocate();
    try testing.expect(extra_entry == null);
    try testing.expectEqual(@as(usize, max_entries), pool.used_count);
    
    // Free one entry and reallocate
    pool.free(entries[2]);
    try testing.expectEqual(@as(usize, max_entries - 1), pool.used_count);
    
    const new_entry = pool.allocate();
    try testing.expect(new_entry != null);
    try testing.expectEqual(@as(usize, max_entries), pool.used_count);
}

test "StaticMemoryPool find and eviction" {
    const entry_size = 256;
    const max_entries = 3;
    
    var pool = try StaticMemoryPool.init(entry_size, max_entries);
    defer pool.deinit();
    
    // Allocate and set key hash
    const entry1 = pool.allocate() orelse return error.AllocationFailed;
    entry1.key_hash = 12345;
    entry1.timestamp = 1000;
    
    const entry2 = pool.allocate() orelse return error.AllocationFailed;
    entry2.key_hash = 67890;
    entry2.timestamp = 2000;
    
    // Test find functionality
    const found1 = pool.find(12345);
    try testing.expect(found1 != null);
    try testing.expectEqual(@as(u64, 12345), found1.?.key_hash);
    
    const found2 = pool.find(67890);
    try testing.expect(found2 != null);
    try testing.expectEqual(@as(u64, 67890), found2.?.key_hash);
    
    const not_found = pool.find(99999);
    try testing.expect(not_found == null);
    
    // Test LRU eviction
    const evicted = pool.evictLRU();
    try testing.expect(evicted != null);
    try testing.expectEqual(@as(u64, 12345), evicted.?.key_hash); // Should evict oldest (1000)
    try testing.expectEqual(@as(usize, 1), pool.used_count);
}

test "StaticMemoryPool statistics" {
    const entry_size = 128;
    const max_entries = 4;
    
    var pool = try StaticMemoryPool.init(entry_size, max_entries);
    defer pool.deinit();
    
    // Get initial stats
    var stats = pool.getStats();
    try testing.expectEqual(@as(usize, max_entries), stats.total_entries);
    try testing.expectEqual(@as(usize, 0), stats.used_entries);
    try testing.expectEqual(@as(usize, max_entries), stats.free_entries);
    try testing.expectEqual(@as(f64, 0.0), stats.utilization_percent);
    try testing.expectEqual(@as(usize, entry_size * max_entries), stats.memory_usage_bytes);
    
    // Allocate some entries
    _ = pool.allocate() orelse return error.AllocationFailed;
    _ = pool.allocate() orelse return error.AllocationFailed;
    
    // Get updated stats
    stats = pool.getStats();
    try testing.expectEqual(@as(usize, 2), stats.used_entries);
    try testing.expectEqual(@as(usize, 2), stats.free_entries);
    try testing.expectEqual(@as(f64, 50.0), stats.utilization_percent);
}

test "Tier-specific memory pools" {
    // Test GPU pool
    var gpu_pool = try GPUMemoryPool.init();
    defer gpu_pool.deinit();
    
    const gpu_entry = gpu_pool.allocate();
    try testing.expect(gpu_entry != null);
    try testing.expectEqual(@as(usize, 4096), gpu_entry.?.data.len);
    
    // Test CPU pool
    var cpu_pool = try CPUMemoryPool.init();
    defer cpu_pool.deinit();
    
    const cpu_entry = cpu_pool.allocate();
    try testing.expect(cpu_entry != null);
    try testing.expectEqual(@as(usize, 8192), cpu_entry.?.data.len);
    
    // Test NVMe pool
    var nvme_pool = try NVMEMemoryPool.init();
    defer nvme_pool.deinit();
    
    const nvme_entry = nvme_pool.allocate();
    try testing.expect(nvme_entry != null);
    try testing.expectEqual(@as(usize, 32768), nvme_entry.?.data.len);
    
    // Test Disk pool
    var disk_pool = try DiskMemoryPool.init();
    defer disk_pool.deinit();
    
    const disk_entry = disk_pool.allocate();
    try testing.expect(disk_entry != null);
    try testing.expectEqual(@as(usize, 131072), disk_entry.?.data.len);
}

test "MemoryPoolManager integration" {
    var manager = try MemoryPoolManager.init();
    defer manager.deinit();
    
    // Test total memory usage
    const total_memory = manager.getTotalMemoryUsage();
    const expected_memory = (256 * 4096) + (1024 * 8192) + (4096 * 32768) + (16384 * 131072);
    try testing.expectEqual(expected_memory, total_memory);
    
    // Test overall stats
    const overall_stats = manager.getOverallStats();
    try testing.expectEqual(expected_memory, overall_stats.total_memory_bytes);
    try testing.expectEqual(@as(usize, 256 + 1024 + 4096 + 16384), overall_stats.total_entries);
    try testing.expectEqual(@as(usize, 0), overall_stats.used_entries);
    try testing.expectEqual(@as(f64, 0.0), overall_stats.overall_utilization_percent);
    
    // Test allocation across tiers
    const gpu_entry = manager.gpu_pool.allocate();
    try testing.expect(gpu_entry != null);
    
    const cpu_entry = manager.cpu_pool.allocate();
    try testing.expect(cpu_entry != null);
    
    // Verify stats are updated
    const updated_stats = manager.getOverallStats();
    try testing.expectEqual(@as(usize, 2), updated_stats.used_entries);
}

test "StaticMemoryPool edge cases" {
    const entry_size = 64;
    const max_entries = 1;
    
    var pool = try StaticMemoryPool.init(entry_size, max_entries);
    defer pool.deinit();
    
    // Test single entry allocation
    const entry = pool.allocate() orelse return error.AllocationFailed;
    try testing.expectEqual(@as(usize, 1), pool.used_count);
    
    // Test double-free protection
    pool.free(entry);
    try testing.expectEqual(@as(usize, 0), pool.used_count);
    
    pool.free(entry); // Should not crash or change count
    try testing.expectEqual(@as(usize, 0), pool.used_count);
    
    // Test reallocation after free
    const new_entry = pool.allocate();
    try testing.expect(new_entry != null);
    try testing.expectEqual(@as(usize, 1), pool.used_count);
}

test "StaticMemoryPool data integrity" {
    const entry_size = 256;
    const max_entries = 2;
    
    var pool = try StaticMemoryPool.init(entry_size, max_entries);
    defer pool.deinit();
    
    // Allocate entry and write data
    const entry = pool.allocate() orelse return error.AllocationFailed;
    
    // Write test data
    const test_data = "Hello, NenCache!";
    if (entry.data.len >= test_data.len) {
        @memcpy(entry.data[0..test_data.len], test_data);
        entry.data[test_data.len] = 0; // Null terminate
        
        // Verify data was written correctly
        try testing.expectEqualStrings(test_data, entry.data[0..test_data.len]);
    }
    
    // Test that data persists after operations
    entry.key_hash = 42;
    entry.timestamp = 12345;
    entry.access_count = 10;
    
    try testing.expectEqual(@as(u64, 42), entry.key_hash);
    try testing.expectEqual(@as(i64, 12345), entry.timestamp);
    try testing.expectEqual(@as(u32, 10), entry.access_count);
    
    // Test reset functionality
    entry.reset();
    try testing.expectEqual(@as(u64, 0), entry.key_hash);
    try testing.expectEqual(@as(i64, 0), entry.timestamp);
    try testing.expectEqual(@as(u32, 0), entry.access_count);
    try testing.expect(!entry.is_used);
}
