const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var cache = try nencache.EnhancedKVCache.init(allocator);
    defer cache.deinit();

    std.debug.print("🤖 NenCache Conversation Chatbot\n", .{});
    std.debug.print("This chatbot stores ALL conversations in NenCache!\n\n", .{});

    // Simulate a conversation that gets stored
    const messages = [_][]const u8{
        "Hello! How are you?",
        "What is NenCache?", 
        "How fast is it?",
        "Can you remember what I said?",
        "Show me the stats"
    };

    var count: u32 = 0;
    for (messages) |msg| {
        std.debug.print("👤 You: {s}\n", .{msg});
        
        // Store in cache
        const key = try std.fmt.allocPrint(allocator, "conv:{d}", .{count});
        defer allocator.free(key);
        try cache.set(key, msg);

        // Generate response
        const response = if (std.mem.indexOf(u8, msg, "hello") != null)
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
            stats_msg
        } else
            "That is interesting! Tell me more.";

        std.debug.print("🤖 Bot: {s}\n\n", .{response});
        count += 1;
    }

    // Show retrieval
    std.debug.print("🔄 Retrieving conversation from NenCache...\n", .{});
    for (0..count) |i| {
        const key = try std.fmt.allocPrint(allocator, "conv:{d}", .{i});
        defer allocator.free(key);
        if (cache.get(key)) |stored_msg| {
            std.debug.print("📝 Retrieved: {s}\n", .{stored_msg});
        }
    }

    std.debug.print("\n🎉 Your entire conversation is stored in NenCache!\n", .{});
    std.debug.print("Total operations: {d}\n", .{cache.stats.total_gets + cache.stats.total_sets});
}
