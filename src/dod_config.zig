// Nen Cache Data-Oriented Design (DOD) Configuration
// Optimized for high-performance caching with static memory management

const std = @import("std");

// DOD Configuration for nen-cache
pub const DODConfig = struct {
    // Cache configuration
    pub const cache = struct {
        pub const max_entries: u32 = 1048576; // 1M entries
        pub const key_size: u32 = 256; // Max key size
        pub const value_size: u32 = 4096; // Max value size
        pub const alignment: u32 = 64; // Cache line alignment
        pub const simd_alignment: u32 = 32; // SIMD alignment
    };
    
    // Memory tier configuration
    pub const tiers = struct {
        pub const gpu_cache_size: u32 = 1024 * 1024; // 1MB GPU cache
        pub const cpu_cache_size: u32 = 16 * 1024 * 1024; // 16MB CPU cache
        pub const nvme_cache_size: u32 = 256 * 1024 * 1024; // 256MB NVMe cache
        pub const disk_cache_size: u32 = 1024 * 1024 * 1024; // 1GB disk cache
        pub const max_tier_entries: u32 = 65536; // Max entries per tier
    };
    
    // Prefetching configuration
    pub const prefetching = struct {
        pub const enable_hardware_prefetch: bool = true;
        pub const enable_software_prefetch: bool = true;
        pub const prefetch_distance: u32 = 4; // Cache lines ahead
        pub const max_prefetch_requests: u32 = 16; // Maximum concurrent prefetch requests
        pub const gpu_prefetch_size: u32 = 128; // GPU prefetch size in KB
        pub const cpu_prefetch_size: u32 = 64; // CPU prefetch size in KB
        pub const nvme_prefetch_size: u32 = 32; // NVMe prefetch size in KB
    };
    
    // SIMD configuration
    pub const simd = struct {
        pub const enable_simd: bool = true;
        pub const simd_width: u32 = 8; // SIMD width for vectorized operations
        pub const alignment: u32 = 32; // SIMD alignment requirement
        pub const batch_size: u32 = 8; // Process 8 elements at once
        pub const key_simd_batch: u32 = 8; // SIMD batch for key operations
        pub const value_simd_batch: u32 = 8; // SIMD batch for value operations
    };
    
    // Memory pools configuration
    pub const memory_pools = struct {
        pub const key_pool_size: u32 = 1024; // Key pool size
        pub const value_pool_size: u32 = 512; // Value pool size
        pub const metadata_pool_size: u32 = 256; // Metadata pool size
        pub const stats_pool_size: u32 = 128; // Statistics pool size
        pub const prefetch_pool_size: u32 = 64; // Prefetch pool size
    };
    
    // Performance targets
    pub const performance = struct {
        pub const gpu_latency_ns: u64 = 1000; // Target: <1μs GPU access
        pub const cpu_latency_ns: u64 = 10000; // Target: <10μs CPU access
        pub const nvme_latency_ns: u64 = 100000; // Target: <100μs NVMe access
        pub const disk_latency_ns: u64 = 1000000; // Target: <1ms disk access
        pub const cache_hit_rate: f64 = 0.99; // Target: >99% cache hit rate
        pub const memory_efficiency: f64 = 0.95; // Target: >95% memory efficiency
        pub const simd_utilization: f64 = 0.9; // Target: >90% SIMD utilization
        pub const prefetch_effectiveness: f64 = 0.85; // Target: >85% prefetch effectiveness
    };
    
    // Feature flags
    pub const features = struct {
        pub const use_soa_layout: bool = true; // Use Struct of Arrays layout
        pub const separate_hot_cold: bool = true; // Separate hot and cold data
        pub const enable_component_system: bool = true; // Enable component-based architecture
        pub const align_for_simd: bool = true; // Align data for SIMD operations
        pub const use_memory_pools: bool = true; // Use static memory pools
        pub const enable_memory_prefetch: bool = true; // Enable memory prefetching
        pub const enable_vectorization: bool = true; // Enable vectorized operations
        pub const enable_batch_processing: bool = true; // Enable batch processing
        pub const optimize_cache_locality: bool = true; // Optimize for cache locality
        pub const use_cache_friendly_layouts: bool = true; // Use cache-friendly layouts
        pub const enable_tier_prefetch: bool = true; // Enable tier-specific prefetching
        pub const enable_compression: bool = true; // Enable compression
        pub const enable_p2p_sharing: bool = true; // Enable P2P sharing
    };
};

// DOD-specific constants
pub const DOD_CONSTANTS = struct {
    // Cache sizes (power of 2 for better alignment)
    pub const CACHE_SIZE_SMALL = 1024; // 1KB
    pub const CACHE_SIZE_MEDIUM = 4096; // 4KB
    pub const CACHE_SIZE_LARGE = 65536; // 64KB
    pub const CACHE_SIZE_HUGE = 1048576; // 1MB
    
    // Alignment requirements
    pub const CACHE_LINE_SIZE = 64;
    pub const SIMD_ALIGNMENT = 32;
    pub const PAGE_SIZE = 4096;
    
    // Pool sizes (reduced for demo)
    pub const MAX_KEYS = 1024; // 1K keys
    pub const MAX_VALUES = 512; // 512 values
    pub const MAX_METADATA = 256; // 256 metadata entries
    pub const MAX_STATS = 128; // 128 stats entries
    pub const MAX_PREFETCH = 64; // 64 prefetch entries
    
    // SIMD batch sizes
    pub const SIMD_KEY_BATCH = 8;
    pub const SIMD_VALUE_BATCH = 8;
    pub const SIMD_METADATA_BATCH = 8;
    pub const SIMD_STATS_BATCH = 8;
    
    // Prefetch distances
    pub const PREFETCH_DISTANCE_SMALL = 1;
    pub const PREFETCH_DISTANCE_MEDIUM = 2;
    pub const PREFETCH_DISTANCE_LARGE = 4;
    pub const PREFETCH_DISTANCE_HUGE = 8;
    
    // Performance thresholds
    pub const GPU_LATENCY_THRESHOLD_NS = 1000;
    pub const CPU_LATENCY_THRESHOLD_NS = 10000;
    pub const NVME_LATENCY_THRESHOLD_NS = 100000;
    pub const DISK_LATENCY_THRESHOLD_NS = 1000000;
    pub const CACHE_HIT_THRESHOLD = 0.95;
    pub const MEMORY_EFFICIENCY_THRESHOLD = 0.9;
};

// DOD error types
pub const DODError = error{
    PoolExhausted,
    CacheOverflow,
    InvalidAlignment,
    PrefetchFailed,
    SIMDNotSupported,
    ComponentNotFound,
    HotColdSeparationFailed,
    SoALayoutError,
    MemoryPoolError,
    TierProcessingError,
    CompressionError,
    P2PError,
};

// DOD statistics
pub const DODStats = struct {
    // Performance metrics
    gpu_latency_ns: u64 = 0,
    cpu_latency_ns: u64 = 0,
    nvme_latency_ns: u64 = 0,
    disk_latency_ns: u64 = 0,
    cache_hit_rate: f64 = 0.0,
    memory_efficiency: f64 = 0.0,
    simd_utilization: f64 = 0.0,
    prefetch_effectiveness: f64 = 0.0,
    
    // Operation counts
    gpu_operations: u64 = 0,
    cpu_operations: u64 = 0,
    nvme_operations: u64 = 0,
    disk_operations: u64 = 0,
    prefetch_operations: u64 = 0,
    simd_operations: u64 = 0,
    
    // Prefetch statistics
    hardware_prefetches: u64 = 0,
    software_prefetches: u64 = 0,
    prefetch_hits: u64 = 0,
    prefetch_misses: u64 = 0,
    tier_prefetches: u64 = 0,
    
    // Memory statistics
    total_allocated: u64 = 0,
    total_freed: u64 = 0,
    peak_usage: u64 = 0,
    current_usage: u64 = 0,
    tier_usage: [4]u64 = [_]u64{0} ** 4,
    
    // Cache statistics
    cache_hits: u64 = 0,
    cache_misses: u64 = 0,
    evictions: u64 = 0,
    compressions: u64 = 0,
    decompressions: u64 = 0,
    
    pub fn getGPULatency(self: DODStats) u64 {
        return self.gpu_latency_ns;
    }
    
    pub fn getCPULatency(self: DODStats) u64 {
        return self.cpu_latency_ns;
    }
    
    pub fn getNVMELatency(self: DODStats) u64 {
        return self.nvme_latency_ns;
    }
    
    pub fn getDiskLatency(self: DODStats) u64 {
        return self.disk_latency_ns;
    }
    
    pub fn getCacheHitRate(self: DODStats) f64 {
        return self.cache_hit_rate;
    }
    
    pub fn getMemoryEfficiency(self: DODStats) f64 {
        return self.memory_efficiency;
    }
    
    pub fn getSIMDUtilization(self: DODStats) f64 {
        return self.simd_utilization;
    }
    
    pub fn getPrefetchEffectiveness(self: DODStats) f64 {
        return self.prefetch_effectiveness;
    }
    
    pub fn getTotalOperations(self: DODStats) u64 {
        return self.gpu_operations + self.cpu_operations + 
               self.nvme_operations + self.disk_operations + 
               self.prefetch_operations + self.simd_operations;
    }
    
    pub fn getTierUtilization(self: DODStats, tier: u32) f64 {
        if (tier >= 4) return 0.0;
        const total_tier_usage = self.tier_usage[0] + self.tier_usage[1] + 
                                self.tier_usage[2] + self.tier_usage[3];
        if (total_tier_usage == 0) return 0.0;
        return @as(f64, @floatFromInt(self.tier_usage[tier])) / @as(f64, @floatFromInt(total_tier_usage));
    }
    
    pub fn getOverallLatency(self: DODStats) u64 {
        const total_ops = self.getTotalOperations();
        if (total_ops == 0) return 0;
        
        const weighted_latency = (self.gpu_latency_ns * self.gpu_operations + 
                                 self.cpu_latency_ns * self.cpu_operations + 
                                 self.nvme_latency_ns * self.nvme_operations + 
                                 self.disk_latency_ns * self.disk_operations) / total_ops;
        return weighted_latency;
    }
    
    pub fn getMemoryUtilization(self: DODStats) f64 {
        if (self.peak_usage == 0) return 0.0;
        return @as(f64, @floatFromInt(self.current_usage)) / @as(f64, @floatFromInt(self.peak_usage));
    }
};
