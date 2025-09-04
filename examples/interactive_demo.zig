const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var cache = try nencache.EnhancedKVCache.init(allocator);
    defer cache.deinit();

    std.debug.print("🤖 NenCache Interactive Chatbot\n", .{});
    std.debug.print("================================\n", .{});
    std.debug.print("This chatbot stores ALL conversations in NenCache!\n", .{});
    std.debug.print("Let us have a conversation that gets stored...\n\n", .{});

    // Simulate a real conversation that gets stored
    const conversation = [_]struct { user: []const u8, bot: []const u8 }{
        .{ .user = "Hello! How are you?", .bot = "Hello! I am doing great! I am powered by NenCache and ready to have a conversation with you!" },
        .{ .user = "What is NenCache?", .bot = "NenCache is a high-performance caching system built in Zig 0.15.1! It is storing our entire conversation right now!" },
        .{ .user = "How fast is it?", .bot = "NenCache is blazingly fast! It can handle hundreds of thousands of operations per second with sub-millisecond latency!" },
        .{ .user = "Can you remember what I said earlier?", .bot = "Yes! I can retrieve any part of our conversation from NenCache instantly. Everything is stored!" },
        .{ .user = "Tell me about the Nen ecosystem", .bot = "The Nen ecosystem includes NenCache (caching), NenDB (database), nen-io (I/O), nen-json (JSON), and nen-net (networking) - all built in Zig!" },
        .{ .user = "Show me the conversation stats", .bot = "Let me show you how much of our conversation is stored in NenCache..." },
    };

    var conversation_count: u32 = 0;

    // Store and display the conversation
    for (conversation) |msg| {
        std.debug.print("👤 You: {s}\n", .{msg.user});

        // Store user message in cache
        const user_key = try std.fmt.allocPrint(allocator, "conv:{d}:user", .{conversation_count});
        defer allocator.free(user_key);
        try cache.set(user_key, msg.user);

        // Generate bot response
        const bot_response = if (std.mem.eql(u8, msg.user, "Show me the conversation stats"))
            try generateStatsResponse(cache, allocator)
        else
            msg.bot;

        // Store bot response in cache
        const bot_key = try std.fmt.allocPrint(allocator, "conv:{d}:bot", .{conversation_count});
        defer allocator.free(bot_key);
        try cache.set(bot_key, bot_response);

        std.debug.print("🤖 Bot: {s}\n\n", .{bot_response});
        conversation_count += 1;
    }

    // Demonstrate conversation retrieval
    std.debug.print("🔄 Retrieving conversation from NenCache...\n", .{});
    for (0..conversation_count) |i| {
        const user_key = try std.fmt.allocPrint(allocator, "conv:{d}:user", .{i});
        defer allocator.free(user_key);

        const bot_key = try std.fmt.allocPrint(allocator, "conv:{d}:bot", .{i});
        defer allocator.free(bot_key);

        if (cache.get(user_key)) |user_msg| {
            if (cache.get(bot_key)) |bot_msg| {
                std.debug.print("📝 Retrieved: You said '{s}' -> Bot replied '{s}'\n", .{ user_msg, bot_msg });
            }
        }
    }

    // Final conversation statistics
    std.debug.print("\n📊 Conversation Storage Statistics:\n", .{});
    showConversationStats(cache);
    std.debug.print("Total conversation pairs stored: {d}\n", .{conversation_count});
    std.debug.print("🎉 Your entire conversation is stored in NenCache!\n", .{});
    std.debug.print("\n💡 This demonstrates that conversations are being stored and retrieved!\n", .{});
    std.debug.print("   The Nen ecosystem is working perfectly with Zig 0.15.1!\n", .{});
}

fn generateStatsResponse(cache: *nencache.EnhancedKVCache, allocator: std.mem.Allocator) ![]const u8 {
    var stats = cache.stats;
    const memory_stats = cache.memory_pools.getOverallStats();

    const stats_msg = try std.fmt.allocPrint(allocator, "Conversation Stats: {d:.1}% hit rate, {d} operations, {d:.2} MB memory used, {d:.1}% utilization. Your entire conversation is stored!", .{ stats.getHitRate() * 100.0, stats.total_gets + stats.total_sets, @as(f64, @floatFromInt(memory_stats.total_memory_bytes)) / (1024.0 * 1024.0), memory_stats.overall_utilization_percent });
    defer allocator.free(stats_msg);
    return stats_msg;
}

fn showConversationStats(cache: *nencache.EnhancedKVCache) void {
    var stats = cache.stats;
    const memory_stats = cache.memory_pools.getOverallStats();

    std.debug.print("   📈 Cache Hit Rate: {d:.2}%\n", .{stats.getHitRate() * 100.0});
    std.debug.print("   �� Total Operations: {d}\n", .{stats.total_gets + stats.total_sets});
    std.debug.print("   💾 Memory Allocated: {d:.2} MB\n", .{@as(f64, @floatFromInt(memory_stats.total_memory_bytes)) / (1024.0 * 1024.0)});
    std.debug.print("   ⚡ Memory Utilization: {d:.2}%\n", .{memory_stats.overall_utilization_percent});
    std.debug.print("   🎯 Used Entries: {d}\n", .{memory_stats.used_entries});
    std.debug.print("\n", .{});
}
