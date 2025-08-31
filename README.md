# NenCache 🚀

**Building the Future of LLM Caching - Together**

NenCache is a **community-driven, high-performance KV cache system** designed to provide an open alternative to LMCache. Built in Zig with static memory allocation, we're working together to create the fastest, most efficient LLM caching solution possible.

## 🌟 **What We're Building**

### **Performance Goals**
- **Speed**: Target 4-15x delay savings over baseline (vs LMCache's claimed 3-10x)
- **Memory**: Aim for 50% less memory usage than LMCache
- **I/O**: Target 2-3x faster disk operations
- **Latency**: Working toward sub-millisecond P2P sharing

> **Note**: These are our *targets* and *goals*. We're building this together, and performance will improve as the community contributes and optimizes the codebase.

### **Why Zig?**
- **Zero-allocation overhead** through static memory pools
- **Cache-line optimized** memory layout for maximum performance
- **Cross-platform** support without runtime dependencies
- **Community-driven** development with rapid iteration

## 🏗️ **Architecture Vision**

### **4-Tier Storage System (Target)**
```
GPU Cache     → < 1μs access    (CUDA/OpenCL integration)
CPU Cache     → < 10μs access   (L1/L2 cache optimized)
NVMe Cache    → < 100μs access  (Direct I/O, no syscalls)
Disk Cache    → < 1ms access    (Memory-mapped files)
```

### **Key Features We're Developing**
- **Static memory pools** for zero-allocation overhead
- **Intelligent prefetching** with ML-based prediction
- **Advanced compression** with vector quantization
- **P2P sharing** across multiple instances
- **LMCache compatibility** for easy migration

## 🚀 **Getting Started**

### **For Users**
```bash
# Clone the repository
git clone https://github.com/Nen-Co/nen-cache.git
cd nen-cache

# Build (development mode)
zig build

# Build (release mode)
zig build -Doptimize=ReleaseFast

# Run the server
./zig-out/bin/nencache serve
```

### **For Contributors**
```bash
# Clone and set up
git clone https://github.com/Nen-Co/nen-cache.git
cd nen-cache

# Build and test
zig build
zig build test

# Check out our roadmap and pick something to work on!
# See ROADMAP.md for current development priorities
```

## 📊 **Current Status**

### **What's Working**
- ✅ Project structure and build system
- ✅ Basic Zig project setup
- ✅ Documentation framework
- ✅ Community roadmap

### **What We're Building**
- 🟡 Static memory management system
- 🟢 Basic KV store implementation
- 🟢 4-tier storage architecture
- 🟢 Performance benchmarking suite

### **What's Coming Next**
- 🟢 Intelligent prefetching engine
- 🟢 LMCache compatibility layer
- 🟢 Production monitoring tools
- 🟢 Community examples and tutorials

## 🤝 **Join the Community**

### **How to Contribute**
- **Code**: Pick up issues from our [roadmap](ROADMAP.md)
- **Testing**: Help benchmark and test performance
- **Documentation**: Improve guides and examples
- **Ideas**: Share your use cases and requirements
- **Feedback**: Tell us what you need and what's not working

### **Community Areas**
- **Performance**: Help optimize and benchmark
- **Features**: Build the caching features you need
- **Integrations**: Create bindings for your language
- **Deployment**: Help with Docker, K8s, and cloud deployment
- **Documentation**: Write tutorials and improve guides

### **Get Involved**
- **GitHub Discussions**: [Share ideas and get help](https://github.com/Nen-Co/nen-cache/discussions)
- **Issues**: Report bugs and request features
- **Pull Requests**: Contribute code and improvements
- **Discord**: [Real-time chat and collaboration](https://discord.gg/nen-community)
- **Twitter**: [Follow updates and announcements](https://twitter.com/nen_co)

## 📈 **Performance Benchmarks**

### **Our Goals vs LMCache**
| Metric | LMCache Claim | NenCache Target | Status |
|--------|---------------|-----------------|---------|
| TTFT Improvement | 3-10x | 4-15x | 🟡 In Development |
| Memory Usage | 100% | 50% | 🟡 In Development |
| Disk I/O | 100% | 200-300% | 🟡 In Development |
| P2P Latency | ~1ms | <1ms | 🟡 In Development |

> **Important**: These are our *targets* and *goals*. We're building this together, and actual performance will depend on community contributions and real-world testing.

### **Current Benchmarks**
- **Development Phase**: Still building core infrastructure
- **Performance Testing**: Framework in development
- **LMCache Comparison**: Coming in Phase 2
- **Real-world Testing**: Community deployments needed

## 🏗️ **Project Structure**

```
nencache/
├── src/
│   ├── memory/           # Static memory pools (in development)
│   │   ├── static_cache.zig
│   │   ├── kv_cache.zig
│   │   └── pool.zig
│   ├── cache/            # Enhanced multi-tier cache (planned)
│   │   ├── enhanced_kv_cache.zig
│   │   ├── compression.zig
│   │   └── prefetching.zig
│   └── engine/           # Cache engine (planned)
│       ├── nen_engine.zig
│       └── batch.zig
├── tests/                # Performance tests (in development)
├── examples/             # Usage examples (planned)
├── docs/                 # Documentation (in progress)
└── ROADMAP.md            # Development roadmap
```

## 🌟 **Why NenCache?**

### **For Developers**
- **Learn Zig**: Deep dive into systems programming
- **Performance**: Build the fastest cache possible
- **Community**: Work with passionate developers worldwide
- **Innovation**: Explore cutting-edge caching strategies

### **For Users**
- **Open Source**: Full control over your caching infrastructure
- **Performance**: Target performance that exceeds LMCache
- **Community**: Get help and contribute improvements
- **Future**: Help shape the direction of LLM caching

### **For Organizations**
- **No Vendor Lock-in**: Open source with community support
- **Customization**: Modify and extend for your specific needs
- **Performance**: Optimize for your specific workloads
- **Community**: Access to a growing ecosystem of tools and integrations

## 📚 **Documentation & Resources**

- **[ROADMAP.md](ROADMAP.md)**: Detailed development roadmap
- **[PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md)**: Technical architecture details
- **[INTEGRATION_ARCHITECTURE.md](INTEGRATION_ARCHITECTURE.md)**: How to integrate NenCache
- **Examples**: Coming soon - basic usage examples
- **API Reference**: Coming soon - comprehensive API documentation

## 🚧 **Current Limitations**

### **What's Not Ready Yet**
- **Production Use**: Still in development phase
- **Performance Claims**: Targets, not current performance
- **LMCache Compatibility**: Coming in Phase 3
- **Language Bindings**: Python, JS, Rust bindings planned

### **What We Need Help With**
- **Performance Testing**: Real-world benchmarks and testing
- **Use Cases**: Understanding your specific caching needs
- **Integration**: Help with different LLM frameworks
- **Deployment**: Cloud and container deployment strategies

## 💡 **Have Ideas?**

We want to hear from you! NenCache is being built by the community, for the community.

- **Feature Requests**: What caching features do you need?
- **Performance Requirements**: What are your latency and throughput needs?
- **Integration Needs**: What LLM frameworks are you using?
- **Deployment**: How do you want to deploy and scale?

## 🌍 **Community Values**

- **Open Collaboration**: Everyone can contribute and influence direction
- **Performance First**: We're building the fastest cache possible
- **Real-world Focus**: Features driven by actual user needs
- **Transparency**: Open development process and honest about current status
- **Inclusivity**: Welcome developers of all skill levels and backgrounds

---

**Ready to build the future of LLM caching together? Let's make this happen! 🚀**

*NenCache is a community project. Your contributions, feedback, and ideas shape its future. Join us in building something amazing!*

## 📄 **License**

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 **Acknowledgments**

- **LMCache Team**: For inspiring this project and setting the performance bar
- **Zig Community**: For the amazing language and tooling
- **Early Contributors**: Everyone helping build the foundation
- **Future Contributors**: You! (Yes, you reading this right now)
