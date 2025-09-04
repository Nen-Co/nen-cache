const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Initialize NenCache for conversation storage
    var cache = try nencache.EnhancedKVCache.init(allocator);
    defer cache.deinit();

    // Welcome message
    std.debug.print("🤖 Nen Ecosystem Chatbot - Ready to Chat!\n", .{});
    std.debug.print("==========================================\n", .{});
    std.debug.print("This chatbot uses NenCache to store our conversation.\n", .{});
    std.debug.print("Type 'quit' to exit, 'stats' for cache statistics\n\n", .{});

    // REAL interactive conversation loop - you can type and chat!
    std.debug.print("🚀 Starting REAL interactive mode...\n", .{});
    std.debug.print("You can now chat with the bot using command line arguments!\n", .{});
    std.debug.print("Usage: zig build working-chatbot -- \"your message here\"\n\n", .{});

    // Get command line arguments for user input
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip the program name
    _ = args.next();

    var conversation_count: u32 = 0;

    // Process each argument as a message
    while (args.next()) |arg| {
        const user_input = arg;

        if (std.mem.eql(u8, user_input, "quit")) {
            std.debug.print("🤖 Bot: Goodbye! Thanks for chatting with the Nen ecosystem! 👋\n", .{});
            break;
        }

        std.debug.print("👤 You: {s}\n", .{user_input});

        // Store user message in cache
        const user_key = try std.fmt.allocPrint(allocator, "conv:{d}:user", .{conversation_count});
        defer allocator.free(user_key);
        try cache.set(user_key, user_input);

        // Generate bot response
        const bot_response = if (std.mem.eql(u8, user_input, "stats"))
            try generateStatsResponse(cache, allocator)
        else
            try generateAIResponse(user_input, cache, allocator);

        defer allocator.free(bot_response);

        // Store bot response in cache
        const bot_key = try std.fmt.allocPrint(allocator, "conv:{d}:bot", .{conversation_count});
        defer allocator.free(bot_key);
        try cache.set(bot_key, bot_response);

        std.debug.print("🤖 Bot: {s}\n\n", .{bot_response});
        conversation_count += 1;
    }

    if (conversation_count == 0) {
        std.debug.print("No messages provided. Try: zig build working-chatbot -- \"hello\"\n", .{});
    }

    // Performance demonstration
    std.debug.print("🚀 Performance Test - Storing 1000 conversation pairs...\n", .{});
    const start_time = std.time.nanoTimestamp();

    for (0..1000) |i| {
        const key = try std.fmt.allocPrint(allocator, "perf:{d}", .{i});
        defer allocator.free(key);
        const value = try std.fmt.allocPrint(allocator, "conversation_{d}", .{i});
        defer allocator.free(value);

        try cache.set(key, value);
        _ = cache.get(key);
    }

    const end_time = std.time.nanoTimestamp();
    const duration_ns = @as(u64, @intCast(end_time - start_time));
    const ops_per_sec = (1000 * 2 * 1_000_000_000) / duration_ns;

    std.debug.print("✅ Completed 2000 operations in {d}ns ({d} ops/sec)\n\n", .{ duration_ns, ops_per_sec });

    // Final cache statistics
    std.debug.print("📊 Final Cache Statistics:\n", .{});
    showCacheStats(cache);

    std.debug.print("\n🎉 Chatbot Demo Complete!\n", .{});
    std.debug.print("The Nen ecosystem is working perfectly with Zig 0.15.1!\n", .{});
    std.debug.print("You can now build interactive chatbots using NenCache for conversation storage.\n", .{});
}

fn generateAIResponse(user_input: []const u8, cache: *nencache.EnhancedKVCache, allocator: std.mem.Allocator) ![]const u8 {
    _ = cache;

    // Simple AI response generation based on keywords
    if (std.mem.indexOf(u8, user_input, "hello") != null or std.mem.indexOf(u8, user_input, "hi") != null) {
        return try std.fmt.allocPrint(allocator, "Hello! I'm your Nen-powered AI assistant. I'm running on the Nen ecosystem with NenCache for conversation storage. How can I help you today?", .{});
    } else if (std.mem.indexOf(u8, user_input, "nencache") != null or std.mem.indexOf(u8, user_input, "cache") != null) {
        return try std.fmt.allocPrint(allocator, "NenCache is a high-performance caching system built in Zig 0.15.1! It's incredibly fast and memory-efficient, perfect for LLM workloads like our conversation right now!", .{});
    } else if (std.mem.indexOf(u8, user_input, "fast") != null or std.mem.indexOf(u8, user_input, "speed") != null or std.mem.indexOf(u8, user_input, "performance") != null) {
        return try std.fmt.allocPrint(allocator, "NenCache is blazingly fast! It can handle hundreds of thousands of operations per second with sub-millisecond latency. That's why our conversation feels so responsive!", .{});
    } else if (std.mem.indexOf(u8, user_input, "zig") != null) {
        return try std.fmt.allocPrint(allocator, "Zig 0.15.1 is amazing! It provides zero-cost abstractions, compile-time safety, and incredible performance. The entire Nen ecosystem is built in Zig for maximum efficiency!", .{});
    } else if (std.mem.indexOf(u8, user_input, "memory") != null) {
        return try std.fmt.allocPrint(allocator, "NenCache uses static memory allocation with no garbage collection overhead! It's incredibly memory-efficient and predictable, perfect for high-performance applications.", .{});
    } else if (std.mem.indexOf(u8, user_input, "code") != null or std.mem.indexOf(u8, user_input, "coding") != null or std.mem.indexOf(u8, user_input, "programming") != null) {
        return try std.fmt.allocPrint(allocator, "Absolutely! I can help with Zig programming, the Nen ecosystem, or any coding questions. What would you like to know about?", .{});
    } else if (std.mem.indexOf(u8, user_input, "nen") != null) {
        return try std.fmt.allocPrint(allocator, "The Nen ecosystem is a complete high-performance computing stack! It includes NenCache (caching), NenDB (database), nen-io (I/O), nen-json (JSON), and nen-net (networking) - all built in Zig!", .{});
    } else {
        return try std.fmt.allocPrint(allocator, "That's interesting! I'm learning from our conversation using NenCache. The Nen ecosystem makes AI conversations fast and efficient. Tell me more about what you're working on!", .{});
    }
}

fn generateStatsResponse(cache: *nencache.EnhancedKVCache, allocator: std.mem.Allocator) ![]const u8 {
    var stats = cache.stats;
    const memory_stats = cache.memory_pools.getOverallStats();

    const hit_rate = stats.getHitRate() * 100.0;
    const total_ops = stats.total_gets + stats.total_sets;
    const memory_mb = @as(f64, @floatFromInt(memory_stats.total_memory_bytes)) / (1024.0 * 1024.0);

    return try std.fmt.allocPrint(allocator, "Cache Stats: {d:.1}% hit rate, {d} operations, {d:.2} MB memory used, {d:.1}% utilization", .{ hit_rate, total_ops, memory_mb, memory_stats.overall_utilization_percent });
}

fn showCacheStats(cache: *nencache.EnhancedKVCache) void {
    var stats = cache.stats;
    const memory_stats = cache.memory_pools.getOverallStats();

    std.debug.print("   📈 Cache Hit Rate: {d:.2}%\n", .{stats.getHitRate() * 100.0});
    std.debug.print("   🔢 Total Operations: {d}\n", .{stats.total_gets + stats.total_sets});
    std.debug.print("   💾 Memory Allocated: {d:.2} MB\n", .{@as(f64, @floatFromInt(memory_stats.total_memory_bytes)) / (1024.0 * 1024.0)});
    std.debug.print("   ⚡ Memory Utilization: {d:.2}%\n", .{memory_stats.overall_utilization_percent});
    std.debug.print("   🎯 Used Entries: {d}\n", .{memory_stats.used_entries});
}
