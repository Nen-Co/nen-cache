// Performance Benchmarking Framework for NenCache
// Measure performance improvements over baseline and LMCache targets

const std = @import("std");
const time = std.time;
const mem = std.mem;
const testing = std.testing;

const EnhancedKVCache = @import("nencache").EnhancedKVCache;
const StaticCacheTier = @import("nencache").StaticCacheTier;

// Benchmark configuration
pub const BenchmarkConfig = struct {
    iterations: usize = 10000,
    key_count: usize = 1000,
    value_sizes: []const usize = &.{ 64, 256, 1024, 4096, 16384 },
    warmup_iterations: usize = 1000,
    
    pub fn init() BenchmarkConfig {
        return BenchmarkConfig{};
    }
};

// Benchmark results
pub const BenchmarkResult = struct {
    operation: []const u8,
    tier: StaticCacheTier,
    iterations: usize,
    total_time_ns: u64,
    average_time_ns: f64,
    throughput_ops_per_sec: f64,
    memory_usage_bytes: usize,
    
    pub fn init(operation: []const u8, tier: StaticCacheTier, iterations: usize, total_time_ns: u64, memory_usage_bytes: usize) BenchmarkResult {
        const average_time_ns = @as(f64, @floatFromInt(total_time_ns)) / @as(f64, @floatFromInt(iterations));
        const throughput_ops_per_sec = 1_000_000_000.0 / average_time_ns;
        
        return BenchmarkResult{
            .operation = operation,
            .tier = tier,
            .iterations = iterations,
            .total_time_ns = total_time_ns,
            .average_time_ns = average_time_ns,
            .throughput_ops_per_sec = throughput_ops_per_sec,
            .memory_usage_bytes = memory_usage_bytes,
        };
    }
    
    pub fn print(self: BenchmarkResult) void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("\n📊 {s} Benchmark Results ({s} Tier)\n", .{ self.operation, @tagName(self.tier) }) catch {};
        stdout.print("   Iterations: {d}\n", .{self.iterations}) catch {};
        stdout.print("   Total Time: {d} ns ({d:.2} ms)\n", .{ self.total_time_ns, @as(f64, @floatFromInt(self.total_time_ns)) / 1_000_000.0 }) catch {};
        stdout.print("   Average Time: {d:.2} ns\n", .{self.average_time_ns}) catch {};
        stdout.print("   Throughput: {d:.0} ops/sec\n", .{self.throughput_ops_per_sec}) catch {};
        stdout.print("   Memory Usage: {d} bytes ({d:.2} MB)\n", .{ self.memory_usage_bytes, @as(f64, @floatFromInt(self.memory_usage_bytes)) / (1024.0 * 1024.0) }) catch {};
    }
};

// Benchmark suite
pub const BenchmarkSuite = struct {
    cache: *EnhancedKVCache,
    config: BenchmarkConfig,
    results: std.ArrayList(BenchmarkResult),
    
    pub fn init(cache: *EnhancedKVCache, config: BenchmarkConfig) !BenchmarkSuite {
        return BenchmarkSuite{
            .cache = cache,
            .config = config,
            .results = try std.ArrayList(BenchmarkResult).initCapacity(testing.allocator, 0),
        };
    }
    
    pub fn deinit(self: *BenchmarkSuite, allocator: std.mem.Allocator) void {
        self.results.deinit(allocator);
    }
    
    // Benchmark set operations
    pub fn benchmarkSet(self: *BenchmarkSuite) !void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("\n🚀 Benchmarking SET Operations...\n", .{}) catch {};
        
        for (self.config.value_sizes) |value_size| {
            try self.benchmarkSetWithSize(value_size);
        }
    }
    
    fn benchmarkSetWithSize(self: *BenchmarkSuite, value_size: usize) !void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("   Testing value size: {d} bytes\n", .{value_size}) catch {};
        
        // Generate test data
        var test_value: [16384]u8 = undefined;
        for (0..value_size) |i| {
            test_value[i] = @as(u8, @intCast(i % 256));
        }
        const value_slice = test_value[0..value_size];
        
        // Warmup
        for (0..self.config.warmup_iterations) |i| {
            const key = try std.fmt.allocPrint(testing.allocator, "warmup:{d}", .{i});
            defer testing.allocator.free(key);
            try self.cache.set(key, value_slice);
        }
        
        // Benchmark
        const start_time = time.nanoTimestamp();
        for (0..self.config.iterations) |i| {
            const key = try std.fmt.allocPrint(testing.allocator, "bench:{d}", .{i});
            defer testing.allocator.free(key);
            try self.cache.set(key, value_slice);
        }
        const end_time = time.nanoTimestamp();
        
        const total_time_ns = @as(u64, @intCast(end_time - start_time));
        const memory_stats = self.cache.getMemoryPoolStats();
        
        const result = BenchmarkResult.init(
            "SET",
            .cpu, // Default tier for set operations
            self.config.iterations,
            total_time_ns,
            memory_stats.total_memory_bytes
        );
        
        try self.results.append(result);
        result.print();
    }
    
    // Benchmark get operations
    pub fn benchmarkGet(self: *BenchmarkSuite) !void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("\n🔍 Benchmarking GET Operations...\n", .{}) catch {};
        
        // First populate cache with data
        try self.populateCacheForGet();
        
        for (self.config.value_sizes) |value_size| {
            try self.benchmarkGetWithSize(value_size);
        }
    }
    
    fn populateCacheForGet(self: *BenchmarkSuite) !void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("   Populating cache for GET benchmarks...\n", .{}) catch {};
        
        for (0..self.config.key_count) |i| {
            const key = try std.fmt.allocPrint(testing.allocator, "get_bench:{d}", .{i});
            defer testing.allocator.free(key);
            
            var value: [1024]u8 = undefined;
            for (0..1024) |j| {
                value[j] = @as(u8, @intCast((i + j) % 256));
            }
            
            try self.cache.set(key, &value);
        }
    }
    
    fn benchmarkGetWithSize(self: *BenchmarkSuite, value_size: usize) !void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("   Testing GET with value size: {d} bytes\n", .{value_size}) catch {};
        
        // Warmup
        for (0..self.config.warmup_iterations) |i| {
            const key = try std.fmt.allocPrint(testing.allocator, "warmup_get:{d}", .{i % self.config.key_count});
            defer testing.allocator.free(key);
            _ = self.cache.get(key);
        }
        
        // Benchmark
        const start_time = time.nanoTimestamp();
        for (0..self.config.iterations) |i| {
            const key = try std.fmt.allocPrint(testing.allocator, "get_bench:{d}", .{i % self.config.key_count});
            defer testing.allocator.free(key);
            _ = self.cache.get(key);
        }
        const end_time = time.nanoTimestamp();
        
        const total_time_ns = @as(u64, @intCast(end_time - start_time));
        const memory_stats = self.cache.getMemoryPoolStats();
        
        const result = BenchmarkResult.init(
            "GET",
            .cpu, // Default tier for get operations
            self.config.iterations,
            total_time_ns,
            memory_stats.total_memory_bytes
        );
        
        try self.results.append(result);
        result.print();
    }
    
    // Benchmark mixed operations (set + get)
    pub fn benchmarkMixed(self: *BenchmarkSuite) !void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("\n🔄 Benchmarking Mixed Operations (SET + GET)...\n", .{}) catch {};
        
        // Warmup
        for (0..self.config.warmup_iterations) |i| {
            const key = try std.fmt.allocPrint(testing.allocator, "mixed_warmup:{d}", .{i});
            defer testing.allocator.free(key);
            
            if (i % 2 == 0) {
                try self.cache.set(key, "warmup_value");
            } else {
                _ = self.cache.get(key);
            }
        }
        
        // Benchmark mixed operations
        const start_time = time.nanoTimestamp();
        for (0..self.config.iterations) |i| {
            const key = try std.fmt.allocPrint(testing.allocator, "mixed_bench:{d}", .{i});
            defer testing.allocator.free(key);
            
            if (i % 2 == 0) {
                try self.cache.set(key, "bench_value");
            } else {
                _ = self.cache.get(key);
            }
        }
        const end_time = time.nanoTimestamp();
        
        const total_time_ns = @as(u64, @intCast(end_time - start_time));
        const memory_stats = self.cache.getMemoryPoolStats();
        
        const result = BenchmarkResult.init(
            "MIXED",
            .cpu,
            self.config.iterations,
            total_time_ns,
            memory_stats.total_memory_bytes
        );
        
        try self.results.append(result);
        result.print();
    }
    
    // Run all benchmarks
    pub fn runAll(self: *BenchmarkSuite) !void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("\n🎯 Starting NenCache Performance Benchmark Suite\n", .{}) catch {};
        stdout.print("=============================================\n", .{}) catch {};
        
        try self.benchmarkSet();
        try self.benchmarkGet();
        try self.benchmarkMixed();
        
        try self.printSummary();
    }
    
    // Print benchmark summary
    fn printSummary(self: *BenchmarkSuite) !void {
        const stdout = std.io.getStdOut().writer();
        stdout.print("\n📈 Benchmark Summary\n", .{}) catch {};
        stdout.print("===================\n", .{}) catch {};
        
        var total_memory: usize = 0;
        var total_operations: usize = 0;
        
        for (self.results.items) |result| {
            stdout.print("\n{s}: {d:.0} ops/sec, {d:.2} ns avg, {d:.2} MB\n", .{
                result.operation,
                result.throughput_ops_per_sec,
                result.average_time_ns,
                @as(f64, @floatFromInt(result.memory_usage_bytes)) / (1024.0 * 1024.0)
            }) catch {};
            
            total_memory = @max(total_memory, result.memory_usage_bytes);
            total_operations += result.iterations;
        }
        
        stdout.print("\n🏆 Overall Performance:\n", .{}) catch {};
        stdout.print("   Total Operations: {d}\n", .{total_operations}) catch {};
        stdout.print("   Peak Memory Usage: {d:.2} MB\n", .{@as(f64, @floatFromInt(total_memory)) / (1024.0 * 1024.0)}) catch {};
        
        // Compare with LMCache targets
        stdout.print("\n🎯 LMCache Performance Targets:\n", .{}) catch {};
        stdout.print("   TTFT Improvement: 3-10x (LMCache claim)\n", .{}) catch {};
        stdout.print("   NenCache Target: 4-15x\n", .{}) catch {};
        stdout.print("   Memory Usage: 50% reduction target\n", .{}) catch {};
    }
};

// Convenience function to run benchmarks
pub fn runBenchmarks(allocator: mem.Allocator) !void {
    // Initialize cache
    var cache = try EnhancedKVCache.init(allocator);
    defer cache.deinit();
    
    // Configure benchmarks
    const config = BenchmarkConfig.init();
    
    // Run benchmark suite
    var benchmark_suite = try BenchmarkSuite.init(&cache, config);
    defer benchmark_suite.deinit();
    
    try benchmark_suite.runAll();
}

// Test function
test "Performance Benchmark Framework" {
    const allocator = testing.allocator;
    
    // Test benchmark configuration
    const config = BenchmarkConfig.init();
    try testing.expectEqual(@as(usize, 10000), config.iterations);
    try testing.expectEqual(@as(usize, 1000), config.key_count);
    
    // Test benchmark result creation
    const result = BenchmarkResult.init("TEST", .cpu, 1000, 1000000, 1024);
    try testing.expectEqual(@as(f64, 1000.0), result.average_time_ns);
    try testing.expectEqual(@as(f64, 1000000.0), result.throughput_ops_per_sec);
    
    // Test benchmark suite initialization
    var cache = try EnhancedKVCache.init(allocator);
    defer cache.deinit();
    
    var suite = try BenchmarkSuite.init(cache, config);
    defer suite.deinit();
    
    try testing.expectEqual(@as(usize, 0), suite.results.items.len);
}
