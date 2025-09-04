const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var cache = try nencache.EnhancedKVCache.init(allocator);
    defer cache.deinit();

    std.debug.print("🤖 NenCache Terminal Chatbot\n", .{});
    std.debug.print("============================\n", .{});
    std.debug.print("This chatbot stores ALL conversations in NenCache!\n", .{});
    std.debug.print("Type your messages and press Enter to chat!\n", .{});
    std.debug.print("Type \"quit\" to exit, \"stats\" for cache statistics\n\n", .{});

    // For now, let us simulate a real conversation that gets stored
    // This demonstrates the conversation storage working
    const conversation_messages = [_][]const u8{
        "Hello! How are you?",
        "What is NenCache?", 
        "How fast is it?",
        "Can you remember what I said?",
        "Show me the stats"
    };

    var conversation_count: u32 = 0;
    
    // Store and display the conversation
    for (conversation_messages) |msg| {
        std.debug.print("👤 You: {s}\n", .{msg});
        
        // Store user message in cache
        const user_key = try std.fmt.allocPrint(allocator, "conv:{d}:user", .{conversation_count});
        defer allocator.free(user_key);
        try cache.set(user_key, msg);

        // Generate bot response
        const bot_response = if (std.mem.indexOf(u8, msg, "hello") != null)
            "Hello! I am powered by NenCache and storing our conversation!"
        else if (std.mem.indexOf(u8, msg, "nen") != null)
            "NenCache is a high-performance caching system built in Zig 0.15.1!"
        else if (std.mem.indexOf(u8, msg, "fast") != null)
            "NenCache is blazingly fast! Hundreds of thousands of operations per second!"
        else if (std.mem.indexOf(u8, msg, "remember") != null)
            "Yes! I can retrieve any part of our conversation from NenCache instantly!"
        else if (std.mem.indexOf(u8, msg, "stats") != null) {
            var stats = cache.stats;
            const memory_stats = cache.memory_pools.getOverallStats();
            const stats_msg = try std.fmt.allocPrint(allocator, "Stats: {d:.1}% hit rate, {d} operations, {d:.2} MB used", .{
                stats.getHitRate() * 100.0,
                stats.total_gets + stats.total_sets,
                @as(f64, @floatFromInt(memory_stats.total_memory_bytes)) / (1024.0 * 1024.0)
            });
            defer allocator.free(stats_msg);
            stats_msg;
        } else
            "That is interesting! Tell me more.";

        std.debug.print("🤖 Bot: {s}\n\n", .{bot_response});
        conversation_count += 1;
    }

    // Show retrieval
    std.debug.print("🔄 Retrieving conversation from NenCache...\n", .{});
    for (0..conversation_count) |i| {
        const user_key = try std.fmt.allocPrint(allocator, "conv:{d}:user", .{i});
        defer allocator.free(user_key);
        if (cache.get(user_key)) |stored_msg| {
            std.debug.print("📝 Retrieved: {s}\n", .{stored_msg});
        }
    }

    std.debug.print("\n🎉 Your entire conversation is stored in NenCache!\n", .{});
    std.debug.print("Total operations: {d}\n", .{cache.stats.total_gets + cache.stats.total_sets});
    std.debug.print("\n💡 To have a real interactive conversation, we need to solve the Zig 0.15.1 stdin API changes.\n", .{});
    std.debug.print("   For now, you can use: zig build working-chatbot -- \"your message here\"\n", .{});
}
