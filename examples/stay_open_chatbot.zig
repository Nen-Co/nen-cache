const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var cache = try nencache.EnhancedKVCache.init(allocator);
    defer cache.deinit();

    const stdin = std.fs.File.openHandle(0);
    const stdout = std.fs.File.openHandle(1);

    std.debug.print("🤖 NenCache Interactive Chatbot - STAYS OPEN!\n", .{});
    std.debug.print("============================================\n", .{});
    std.debug.print("This chatbot STAYS OPEN so you can type and chat!\n", .{});
    std.debug.print("Type your messages and press Enter to chat!\n", .{});
    std.debug.print("Type 'quit' to exit, 'stats' for cache statistics\n\n", .{});

    var conversation_count: u32 = 0;

    // Interactive conversation loop - STAYS OPEN
    while (true) {
        try stdout.writer().print("👤 You: ", .{});

        var buffer: [1024]u8 = undefined;
        const input = try stdin.reader().readUntilDelimiterOrEof(&buffer, '\n');
        if (input == null) {
            break; // Exit on EOF (Ctrl+D)
        }

        const user_input = std.mem.trimRight(u8, input.?, "\r\n");

        if (std.mem.eql(u8, user_input, "quit")) {
            try stdout.writer().print("🤖 Bot: Goodbye! Thanks for chatting! 👋\n", .{});
            break;
        }

        if (std.mem.eql(u8, user_input, "")) {
            continue; // Skip empty inputs
        }

        // Store user message in cache
        const user_key = try std.fmt.allocPrint(allocator, "conv:{d}:user", .{conversation_count});
        defer allocator.free(user_key);
        try cache.set(user_key, user_input);

        // Generate bot response
        const bot_response = if (std.mem.eql(u8, user_input, "stats"))
            "Cache Stats: Your entire conversation is stored in NenCache! High performance, low latency, and instant retrieval!"
        else if (std.mem.indexOf(u8, user_input, "hello") != null or std.mem.indexOf(u8, user_input, "hi") != null)
            "Hello! I am your Nen-powered AI assistant. I am running on the Nen ecosystem with NenCache for conversation storage. How can I help you today?"
        else if (std.mem.indexOf(u8, user_input, "nencache") != null or std.mem.indexOf(u8, user_input, "cache") != null)
            "NenCache is a high-performance caching system built in Zig 0.15.1! It is incredibly fast and memory-efficient, perfect for LLM workloads like our conversation right now!"
        else if (std.mem.indexOf(u8, user_input, "fast") != null or std.mem.indexOf(u8, user_input, "speed") != null or std.mem.indexOf(u8, user_input, "performance") != null)
            "NenCache is blazingly fast! It can handle hundreds of thousands of operations per second with sub-millisecond latency. That is why our conversation feels so responsive!"
        else if (std.mem.indexOf(u8, user_input, "zig") != null)
            "Zig 0.15.1 is amazing! It provides zero-cost abstractions, compile-time safety, and incredible performance. The entire Nen ecosystem is built in Zig for maximum efficiency!"
        else if (std.mem.indexOf(u8, user_input, "memory") != null)
            "NenCache uses static memory allocation with no garbage collection overhead! It is incredibly memory-efficient and predictable, perfect for high-performance applications."
        else if (std.mem.indexOf(u8, user_input, "code") != null or std.mem.indexOf(u8, user_input, "coding") != null or std.mem.indexOf(u8, user_input, "programming") != null)
            "Absolutely! I can help with Zig programming, the Nen ecosystem, or any coding questions. What would you like to know about?"
        else if (std.mem.indexOf(u8, user_input, "nen") != null)
            "The Nen ecosystem is a complete high-performance computing stack! It includes NenCache (caching), NenDB (database), nen-io (I/O), nen-json (JSON), and nen-net (networking) - all built in Zig!"
        else
            "That is interesting! I am learning from our conversation using NenCache. The Nen ecosystem makes AI conversations fast and efficient. Tell me more about what you are working on!";

        // Store bot response in cache
        const bot_key = try std.fmt.allocPrint(allocator, "conv:{d}:bot", .{conversation_count});
        defer allocator.free(bot_key);
        try cache.set(bot_key, bot_response);

        try stdout.writer().print("🤖 Bot: {s}\n\n", .{bot_response});
        conversation_count += 1;
    }

    // Show final conversation statistics
    std.debug.print("\n📊 Conversation Summary:\n", .{});
    std.debug.print("Total conversation pairs: {d}\n", .{conversation_count});
    var stats = cache.stats;
    const memory_stats = cache.memory_pools.getOverallStats();
    std.debug.print("   📈 Cache Hit Rate: {d:.2}%\n", .{stats.getHitRate() * 100.0});
    std.debug.print("   🔢 Total Operations: {d}\n", .{stats.total_gets + stats.total_sets});
    std.debug.print("   💾 Memory Allocated: {d:.2} MB\n", .{@as(f64, @floatFromInt(memory_stats.total_memory_bytes)) / (1024.0 * 1024.0)});
    std.debug.print("   ⚡ Memory Utilization: {d:.2}%\n", .{memory_stats.overall_utilization_percent});
    std.debug.print("   🎯 Used Entries: {d}\n", .{memory_stats.used_entries});
    std.debug.print("\n🎉 Your entire conversation is stored in NenCache!\n", .{});
}
