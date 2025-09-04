const std = @import("std");
const nencache = @import("nencache");

const ChatMessage = struct {
    role: []const u8,
    content: []const u8,
    timestamp: u64,
};

const ChatSession = struct {
    session_id: []const u8,
    messages: std.ArrayList(ChatMessage),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, session_id: []const u8) !ChatSession {
        return ChatSession{
            .session_id = session_id,
            .messages = try std.ArrayList(ChatMessage).initCapacity(allocator, 0),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ChatSession) void {
        for (self.messages.items) |msg| {
            self.allocator.free(msg.role);
            self.allocator.free(msg.content);
        }
        self.messages.deinit(self.allocator);
    }

    pub fn addMessage(self: *ChatSession, role: []const u8, content: []const u8) !void {
        const role_copy = try self.allocator.dupe(u8, role);
        const content_copy = try self.allocator.dupe(u8, content);
        
        try self.messages.append(self.allocator, ChatMessage{
            .role = role_copy,
            .content = content_copy,
            .timestamp = std.time.nanoTimestamp(),
        });
    }

    pub fn getHistory(self: *ChatSession) []const ChatMessage {
        return self.messages.items;
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    // Initialize NenCache for conversation storage
    var cache = try nencache.EnhancedKVCache.init(allocator);
    defer cache.deinit();

    // Create a new chat session
    var session = try ChatSession.init(allocator, "demo_session_001");
    defer session.deinit();

    // Welcome message
    std.debug.print("🤖 Nen Ecosystem Chatbot Demo\n", .{});
    std.debug.print("============================\n", .{});
    std.debug.print("This demo shows NenCache storing conversation history!\n", .{});
    std.debug.print("Type 'quit' to exit, 'history' to see conversation, 'stats' for cache stats\n\n", .{});

    // Main chat loop
    while (true) {
        std.debug.print("You: ", .{});
        
        // Read user input (simplified for demo)
        var input_buffer: [1024]u8 = undefined;
        if (std.io.getStdIn().readUntilDelimiterOrEof(input_buffer[0..], '\n')) |input| {
            if (input) |user_input| {
                // Check for special commands
                if (std.mem.eql(u8, user_input, "quit")) {
                    std.debug.print("Goodbye! 👋\n", .{});
                    break;
                } else if (std.mem.eql(u8, user_input, "history")) {
                    showHistory(&session);
                    continue;
                } else if (std.mem.eql(u8, user_input, "stats")) {
                    showCacheStats(&cache);
                    continue;
                }

                // Store user message in cache
                const user_key = try std.fmt.allocPrint(allocator, "msg:user:{d}", .{session.messages.items.len});
                defer allocator.free(user_key);
                try cache.set(user_key, user_input);

                // Add to session
                try session.addMessage("user", user_input);

                // Generate AI response (simplified)
                const ai_response = generateResponse(user_input, &cache, allocator);
                defer allocator.free(ai_response);

                // Store AI response in cache
                const ai_key = try std.fmt.allocPrint(allocator, "msg:ai:{d}", .{session.messages.items.len});
                defer allocator.free(ai_key);
                try cache.set(ai_key, ai_response);

                // Add to session
                try session.addMessage("assistant", ai_response);

                // Display response
                std.debug.print("Bot: {s}\n\n", .{ai_response});
            }
        } else |_| {
            std.debug.print("Error reading input\n", .{});
            break;
        }
    }

    // Final stats
    std.debug.print("\n📊 Final Cache Statistics:\n", .{});
    showCacheStats(&cache);
}

fn generateResponse(user_input: []const u8, _: *nencache.EnhancedKVCache, allocator: std.mem.Allocator) ![]const u8 {
    // Simple response generation based on keywords
    if (std.mem.indexOf(u8, user_input, "hello") != null or std.mem.indexOf(u8, user_input, "hi") != null) {
        return try std.fmt.allocPrint(allocator, "Hello! I'm powered by the Nen ecosystem. How can I help you today?", .{});
    } else if (std.mem.indexOf(u8, user_input, "cache") != null) {
        return try std.fmt.allocPrint(allocator, "Great question! I'm using NenCache to store our conversation. It's super fast and efficient!", .{});
    } else if (std.mem.indexOf(u8, user_input, "performance") != null) {
        return try std.fmt.allocPrint(allocator, "NenCache is incredibly fast! It can handle thousands of operations per second with minimal latency.", .{});
    } else if (std.mem.indexOf(u8, user_input, "memory") != null) {
        return try std.fmt.allocPrint(allocator, "NenCache uses static memory allocation for maximum performance. No garbage collection overhead!", .{});
    } else if (std.mem.indexOf(u8, user_input, "zig") != null) {
        return try std.fmt.allocPrint(allocator, "Yes! The entire Nen ecosystem is built in Zig 0.15.1. It's blazingly fast and memory-efficient!", .{});
    } else {
        return try std.fmt.allocPrint(allocator, "That's interesting! I'm learning from our conversation using NenCache. Tell me more!", .{});
    }
}

fn showHistory(session: *ChatSession) void {
    std.debug.print("\n📜 Conversation History:\n", .{});
    std.debug.print("======================\n", .{});
    
    for (session.getHistory(), 0..) |msg, i| {
        const role_emoji = if (std.mem.eql(u8, msg.role, "user")) "👤" else "🤖";
        std.debug.print("{d}. {s} {s}: {s}\n", .{ i + 1, role_emoji, msg.role, msg.content });
    }
    std.debug.print("\n", .{});
}

fn showCacheStats(cache: *nencache.EnhancedKVCache) void {
    const stats = cache.stats;
    const memory_stats = cache.memory_pools.getOverallStats();
    
    std.debug.print("Cache Hit Rate: {d:.2}%\n", .{stats.getHitRate() * 100.0});
    std.debug.print("Total Operations: {d}\n", .{stats.getTotalOperations()});
    std.debug.print("Memory Used: {d:.2} MB\n", .{@as(f64, @floatFromInt(memory_stats.total_allocated)) / (1024.0 * 1024.0)});
    std.debug.print("Memory Efficiency: {d:.2}%\n", .{memory_stats.efficiency * 100.0});
    std.debug.print("\n");
}
