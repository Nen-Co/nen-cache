const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var cache = try nencache.EnhancedKVCache.init(allocator);
    defer cache.deinit();

    std.debug.print("🤖 NenCache Interactive Chatbot\n", .{});
    std.debug.print("You can now chat with the bot!\n\n", .{});

    // Simple demo conversation
    const inputs = [_][]const u8{ "hello", "what is nen", "how fast is cache", "stats" };

    for (inputs, 0..) |input, i| {
        std.debug.print("👤 You: {s}\n", .{input});

        // Store in cache
        const key = try std.fmt.allocPrint(allocator, "msg_{d}", .{i});
        defer allocator.free(key);
        try cache.set(key, input);

        // Generate response
        const response = if (std.mem.indexOf(u8, input, "hello") != null)
            "Hello! I am your Nen-powered chatbot. How can I help you?"
        else if (std.mem.indexOf(u8, input, "nen") != null)
            "Nen is a high-performance ecosystem built in Zig! It includes NenCache, NenDB, nen-io, nen-json, and nen-net."
        else if (std.mem.indexOf(u8, input, "cache") != null or std.mem.indexOf(u8, input, "fast") != null)
            "NenCache is blazingly fast! It can handle hundreds of thousands of operations per second!"
        else if (std.mem.indexOf(u8, input, "stats") != null) {
            var stats = cache.stats;
            const memory_stats = cache.memory_pools.getOverallStats();
            const stats_msg = try std.fmt.allocPrint(allocator, "Cache Stats: {d:.1}% hit rate, {d} operations, {d:.2} MB memory used", .{ stats.getHitRate() * 100.0, stats.total_gets + stats.total_sets, @as(f64, @floatFromInt(memory_stats.total_memory_bytes)) / (1024.0 * 1024.0) });
            defer allocator.free(stats_msg);
            stats_msg;
        } else "That is interesting! Tell me more.";

        std.debug.print("🤖 Bot: {s}\n\n", .{response});
    }

    std.debug.print("🎉 Chat complete! The Nen ecosystem is working perfectly!\n", .{});
    std.debug.print("Total cache operations: {d}\n", .{cache.stats.total_gets + cache.stats.total_sets});
}
