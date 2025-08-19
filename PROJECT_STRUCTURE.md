# NenCache Project Structure

## 🏗️ **Repository Overview**

NenCache is the **LMCache Killer** - a high-performance, zero-allocation KV cache system built in Zig that will beat LMCache's performance claims.

## 📁 **Directory Structure**

```
nencache/
├── src/                    # Source code
│   ├── main.zig           # Main entry point and exports
│   ├── cache/             # Enhanced KV cache implementation
│   │   └── enhanced_kv_cache.zig  # 4-tier cache system
│   └── memory/            # Memory pools and basic cache
│       ├── static_cache.zig       # Static memory pools
│       ├── kv_cache.zig           # Basic KV cache
│       └── pool.zig               # Memory pools
├── examples/               # Usage examples
│   └── basic_usage.zig    # Basic usage demonstration
├── tests/                  # Test files (to be created)
├── docs/                   # Documentation (to be created)
├── build.zig              # Build system
├── README.md              # Main documentation
└── PROJECT_STRUCTURE.md   # This file
```

## 🔧 **Core Components**

### **1. Enhanced KV Cache (`src/cache/enhanced_kv_cache.zig`)**
- **4-tier storage system** (GPU → CPU → NVMe → Disk)
- **Intelligent prefetching** (ML-based prediction)
- **Advanced compression** (vector quantization, LZ4, Zstd)
- **P2P sharing** (sub-millisecond latency)
- **Performance statistics** and monitoring

### **2. Memory Pools (`src/memory/`)**
- **Static memory allocation** (zero-allocation overhead)
- **Cache-line optimized** memory layout
- **Pre-allocated pools** for predictable performance

### **3. Basic KV Cache (`src/memory/kv_cache.zig`)**
- **Simple KV operations** (set, get, delete)
- **Memory-efficient storage** with static allocation
- **Fast hash-based lookups**

## 🚀 **Build Commands**

```bash
# Build everything
zig build

# Run tests
zig build test

# Run performance tests
zig build perf

# Run benchmarks
zig build bench

# Run LMCache comparison
zig build lmcache-bench

# Run basic example
zig build basic-example

# Generate documentation
zig build docs
```

## 🎯 **Performance Targets**

### **vs LMCache (Current Claims)**
- **TTFT Improvement**: 4-15x (vs LMCache's 3-10x)
- **Memory Usage**: 50% less than LMCache
- **Disk I/O**: 2-3x faster than LMCache
- **P2P Latency**: <1ms (vs LMCache's ~1ms)

### **Architecture Advantages**
- **4-tier storage** vs LMCache's 3-tier
- **Zero-allocation overhead** vs dynamic allocation
- **Cache-line optimized** memory layout
- **Static memory pools** for predictable performance

## 🔬 **Testing Strategy**

### **Unit Tests**
- Basic functionality (set, get, delete)
- Tier selection and promotion
- Statistics and monitoring
- Error handling

### **Performance Tests**
- Throughput benchmarks
- Latency measurements
- Memory usage analysis
- Tier performance comparison

### **Integration Tests**
- LMCache compatibility layer
- vLLM integration
- Multi-instance P2P sharing

## 📊 **Benchmarking**

### **Internal Benchmarks**
- **Operations per second** (set/get)
- **Latency per tier** (GPU/CPU/NVMe/Disk)
- **Memory efficiency** (bytes per operation)
- **Compression ratios** (storage savings)

### **Competitive Benchmarks**
- **vs LMCache** (Python-based)
- **vs Redis** (memory-only)
- **vs Memcached** (network-based)
- **vs vLLM** (integrated)

## 🚧 **Current Status**

### **✅ Completed**
- [x] Project structure and build system
- [x] Enhanced KV cache architecture
- [x] 4-tier storage system
- [x] Basic functionality (set, get)
- [x] Performance statistics
- [x] Unit tests
- [x] Basic usage example

### **🔄 In Progress**
- [ ] Advanced compression algorithms
- [ ] Intelligent prefetching (ML-based)
- [ ] P2P sharing implementation
- [ ] Performance benchmarks

### **📋 Planned**
- [ ] LMCache compatibility layer
- [ ] vLLM integration
- [ ] Production deployment
- [ ] Enterprise features

## 🎯 **Next Steps**

### **Phase 1: Core Performance**
1. **Implement compression algorithms** (LZ4, Zstd, vector quantization)
2. **Add intelligent prefetching** (access pattern prediction)
3. **Complete P2P sharing** (network implementation)
4. **Performance optimization** (memory layout, algorithms)

### **Phase 2: Integration**
1. **LMCache compatibility layer** (drop-in replacement)
2. **vLLM integration** (beat LMCache's vLLM integration)
3. **Performance benchmarks** (prove superiority)

### **Phase 3: Production**
1. **Kubernetes deployment** (scalable architecture)
2. **Monitoring and metrics** (Prometheus, Grafana)
3. **Enterprise features** (multi-tenancy, security)

## 🤝 **Contributing**

We welcome contributions to make NenCache the fastest KV cache system ever built!

### **Development Setup**
```bash
git clone https://github.com/Nen-Co/nencache.git
cd nencache
zig build test
```

### **Areas for Contribution**
- **Performance optimization** (algorithms, memory layout)
- **Compression algorithms** (new algorithms, improvements)
- **ML-based prefetching** (access pattern prediction)
- **P2P protocols** (network optimization)
- **Benchmarks** (competitive analysis)

---

**Built with ❤️ by the Nen team**

*Performance matters. Memory matters. NenCache delivers both.*
