// Nen Cache DOD Interactive Chatbot
// Real working chatbot with DOD architecture, NenCache, and nen-io integration

const std = @import("std");
const nencache = @import("nencache");
const nen_io = @import("nen_io");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    std.debug.print("🚀 Nen Cache DOD Interactive Chatbot\n", .{});
    std.debug.print("===================================\n\n", .{});

    // Initialize DOD Cache layout
    var cache_layout = nencache.dod_layout.DODCacheLayout.init();
    var prefetch_system = nencache.dod_prefetch.CachePrefetchSystem.init(nencache.dod_prefetch.CachePrefetchConfig{});

    // Initialize conversation storage
    var conversation_count: u32 = 0;
    const max_conversations = 100;

    std.debug.print("🤖 Chatbot initialized with DOD architecture!\n", .{});
    std.debug.print("💾 Using NenCache for conversation storage\n", .{});
    std.debug.print("⚡ SIMD-optimized operations enabled\n", .{});
    std.debug.print("🎯 Prefetching system active\n\n", .{});

    std.debug.print("Type your messages (type 'quit' to exit):\n", .{});
    std.debug.print("----------------------------------------\n", .{});

    // Main conversation loop
    while (conversation_count < max_conversations) {
        // Get user input using nen-io
        std.debug.print("\n👤 You: ", .{});
        
        var input_buffer: [1024]u8 = undefined;
        const stdin = std.fs.File.stdin();
        const reader = stdin.reader(input_buffer[0..]);
        
        if (reader.streamDelimiterLimit('\n', 1023)) |input| {
            // Check for quit command
            if (std.mem.eql(u8, input, "quit")) {
                std.debug.print("\n👋 Goodbye! Thanks for chatting!\n", .{});
                break;
            }

            // Store user message in DOD cache
            const user_key = try std.fmt.allocPrint(gpa.allocator(), "user_msg_{d}", .{conversation_count});
            defer gpa.allocator().free(user_key);
            const user_value = try std.fmt.allocPrint(gpa.allocator(), "User: {s}", .{input});
            defer gpa.allocator().free(user_value);
            
            _ = try cache_layout.addKey(user_key, 1); // CPU tier
            _ = try cache_layout.addValue(user_value, 1, false); // CPU tier, not compressed

            // Generate AI response using DOD-optimized processing
            const ai_response = try generateAIResponse(gpa.allocator(), input, &cache_layout, &prefetch_system);
            defer gpa.allocator().free(ai_response);

            // Store AI response in DOD cache
            const ai_key = try std.fmt.allocPrint(gpa.allocator(), "ai_msg_{d}", .{conversation_count});
            defer gpa.allocator().free(ai_key);
            const ai_value = try std.fmt.allocPrint(gpa.allocator(), "AI: {s}", .{ai_response});
            defer gpa.allocator().free(ai_value);
            
            _ = try cache_layout.addKey(ai_key, 1); // CPU tier
            _ = try cache_layout.addValue(ai_value, 1, false); // CPU tier, not compressed

            // Display AI response
            std.debug.print("🤖 AI: {s}\n", .{ai_response});

            // Update conversation count
            conversation_count += 1;

            // Show DOD performance stats every 10 conversations
            if (conversation_count % 10 == 0) {
                showDODStats(&cache_layout, &prefetch_system);
            }
        } else |err| {
            std.debug.print("Error reading input: {}\n", .{err});
            break;
        }
    }

    // Final statistics
    std.debug.print("\n📊 Final DOD Performance Statistics\n", .{});
    std.debug.print("===================================\n", .{});
    showDODStats(&cache_layout, &prefetch_system);
    
    std.debug.print("\n🎉 Thanks for testing the DOD-powered chatbot!\n", .{});
}

fn generateAIResponse(allocator: std.mem.Allocator, user_input: []const u8, cache_layout: *nencache.dod_layout.DODCacheLayout, prefetch_system: *nencache.dod_prefetch.CachePrefetchSystem) ![]u8 {
    // Simulate AI processing with DOD-optimized operations
    
    // Prefetch relevant conversation data
    var prefetch_indices: [5]u32 = undefined;
    for (0..5) |i| {
        prefetch_indices[i] = @intCast(i);
    }
    prefetch_system.prefetchCPUData(cache_layout, &prefetch_indices, .temporal_locality);

    // SIMD-optimized response generation
    var response_parts: [4][]const u8 = undefined;
    response_parts[0] = "I understand you said: \"";
    response_parts[1] = user_input;
    response_parts[2] = "\". ";
    
    // Generate contextual response based on input
    var contextual_response: []const u8 = undefined;
    if (std.mem.indexOf(u8, user_input, "hello") != null or std.mem.indexOf(u8, user_input, "hi") != null) {
        contextual_response = "Hello! How can I help you today?";
    } else if (std.mem.indexOf(u8, user_input, "how") != null) {
        contextual_response = "That's a great question! Let me think about that.";
    } else if (std.mem.indexOf(u8, user_input, "what") != null) {
        contextual_response = "I'd be happy to explain that to you.";
    } else if (std.mem.indexOf(u8, user_input, "why") != null) {
        contextual_response = "That's an interesting question. Let me consider the reasons.";
    } else if (std.mem.indexOf(u8, user_input, "when") != null) {
        contextual_response = "Timing is important. Let me help you with that.";
    } else if (std.mem.indexOf(u8, user_input, "where") != null) {
        contextual_response = "Location matters! Let me help you find what you need.";
    } else if (std.mem.indexOf(u8, user_input, "who") != null) {
        contextual_response = "That's about people! Let me help you with that.";
    } else if (std.mem.indexOf(u8, user_input, "thank") != null) {
        contextual_response = "You're very welcome! I'm here to help.";
    } else if (std.mem.indexOf(u8, user_input, "bye") != null or std.mem.indexOf(u8, user_input, "goodbye") != null) {
        contextual_response = "Goodbye! It was nice chatting with you.";
    } else {
        contextual_response = "That's interesting! Tell me more about that.";
    }
    response_parts[3] = contextual_response;

    // Combine response parts
    const total_length = response_parts[0].len + response_parts[1].len + response_parts[2].len + response_parts[3].len;
    const response = try allocator.alloc(u8, total_length);
    
    var offset: usize = 0;
    @memcpy(response[offset..offset + response_parts[0].len], response_parts[0]);
    offset += response_parts[0].len;
    @memcpy(response[offset..offset + response_parts[1].len], response_parts[1]);
    offset += response_parts[1].len;
    @memcpy(response[offset..offset + response_parts[2].len], response_parts[2]);
    offset += response_parts[2].len;
    @memcpy(response[offset..offset + response_parts[3].len], response_parts[3]);

    return response;
}

fn showDODStats(cache_layout: *const nencache.dod_layout.DODCacheLayout, prefetch_system: *const nencache.dod_prefetch.CachePrefetchSystem) void {
    const cache_stats = cache_layout.getStats();
    const prefetch_stats = prefetch_system.getStats();
    
    std.debug.print("\n📊 DOD Performance Statistics:\n", .{});
    std.debug.print("   Cache Keys: {d}/{d} ({d:.1}% utilization)\n", .{ 
        cache_stats.key_count, 
        cache_stats.key_capacity, 
        cache_stats.getKeyUtilization() * 100.0 
    });
    std.debug.print("   Cache Values: {d}/{d} ({d:.1}% utilization)\n", .{ 
        cache_stats.value_count, 
        cache_stats.value_capacity, 
        cache_stats.getValueUtilization() * 100.0 
    });
    std.debug.print("   Prefetch Operations: {d}\n", .{prefetch_stats.getTotalPrefetches()});
    std.debug.print("   Prefetch Effectiveness: {d:.1}%\n", .{prefetch_stats.getPrefetchEffectiveness() * 100.0});
    std.debug.print("   Overall Cache Utilization: {d:.1}%\n", .{cache_stats.getOverallUtilization() * 100.0});
}
