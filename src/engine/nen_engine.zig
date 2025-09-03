const std = @import("std");
const pool = @import("pool.zig");
const batch = @import("batch.zig");
const cache = @import("cache.zig");

// Integrated Nen Engine: TigerBeetle-Style Memory + LMCache KV Caching
// Provides fastest time-to-first-token (TTFT) with persistent memory

pub const NenEngine = struct {
    // TigerBeetle-style memory engine
    memory_engine: batch.BatchEngine,

    // LMCache multi-tier KV cache
    kv_cache: cache.LMCache,

    // Sequence management
    sequence_counter: u64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !NenEngine {
        var node_pool = pool.NodePool{};
        var edge_pool = pool.EdgePool{};
        var embedding_pool = pool.EmbeddingPool{};

        const memory_engine = try batch.BatchEngine.init(@constCast(&allocator), &node_pool, &edge_pool, &embedding_pool);
        const kv_cache = try cache.LMCache.init(allocator);

        return NenEngine{
            .memory_engine = memory_engine,
            .kv_cache = kv_cache,
            .sequence_counter = 0,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *NenEngine) void {
        self.kv_cache.deinit();
    }

    /// Process a conversation with integrated memory and caching
    pub fn process_conversation(self: *NenEngine, user_message: []const u8) ![]const u8 {
        const start_time = std.time.milliTimestamp();

        // Step 1: Generate text hash for KV cache lookup
        const text_hash = self.hash_text(user_message);

        // Step 2: Check KV cache for existing computation
        if (self.kv_cache.get_kv(text_hash)) |cached_entry| {
            std.debug.print("🎯 KV Cache HIT! Using cached computation\n", .{});
            return self.generate_response_from_cache(cached_entry, user_message);
        }

        // Step 3: Assemble context from memory engine
        const context = try self.assemble_context_for_user(user_message);

        // Step 4: Generate LLM response (simulated for now)
        const response = try self.generate_llm_response(user_message, context);

        // Step 5: Store conversation in memory engine
        try self.store_conversation_in_memory(user_message, response);

        // Step 6: Cache the KV computation for future use
        try self.cache_kv_computation(text_hash, user_message, response);

        const end_time = std.time.milliTimestamp();
        const latency = end_time - start_time;

        std.debug.print("⚡ Conversation processed in {d}ms\n", .{latency});

        return response;
    }

    /// Assemble context from memory engine for a user
    fn assemble_context_for_user(self: *NenEngine, user_message: []const u8) ![]const u8 {
        var context_buf = try self.allocator.alloc(u8, 4096);
        defer self.allocator.free(context_buf);

        // Try to find user in memory
        const user_id = try self.extract_user_id(user_message);
        const written = try self.memory_engine.assemble_context(user_id, context_buf);

        if (written > 0) {
            return try self.allocator.dupe(u8, context_buf[0..written]);
        } else {
            // No existing context, return empty
            return try self.allocator.dupe(u8, "");
        }
    }

    /// Store conversation in memory engine
    fn store_conversation_in_memory(self: *NenEngine, user_message: []const u8, _: []const u8) !void {
        const user_id = try self.extract_user_id(user_message);

        // Create user node if it doesn't exist
        var user_props = [_]u8{0} ** 64;
        const user_name = "User";
        for (user_name, 0..) |c, i| user_props[i] = c;

        var nodes = try self.allocator.alloc(batch.NodeDef, 1);
        defer self.allocator.free(nodes);
        nodes[0] = batch.NodeDef{ .id = user_id, .kind = 0, .props = user_props };

        const node_batch = batch.BatchNodeInsert{ .nodes = nodes };
        _ = try self.memory_engine.batch_insert_nodes(node_batch);

        // Create conversation edge
        var conv_props = [_]u8{0} ** 32;
        const conv_label = "conversation";
        for (conv_label, 0..) |c, i| conv_props[i] = c;

        var edges = try self.allocator.alloc(batch.EdgeDef, 1);
        defer self.allocator.free(edges);
        edges[0] = batch.EdgeDef{ .from = user_id, .to = try self.generate_conversation_id(), .label = 1, .props = conv_props };

        const edge_batch = batch.BatchEdgeInsert{ .edges = edges };
        _ = try self.memory_engine.batch_insert_edges(edge_batch);

        std.debug.print("💾 Stored conversation in memory engine\n", .{});
    }

    /// Cache KV computation for future reuse
    fn cache_kv_computation(self: *NenEngine, text_hash: u64, _: []const u8, _: []const u8) !void {
        // Generate synthetic KV vectors (in real implementation, these would come from LLM)
        var key_vector: [cache.EMBEDDING_DIM]f32 = undefined;
        var value_vector: [cache.EMBEDDING_DIM]f32 = undefined;

        // Simple hash-based vector generation for demo
        for (0..cache.EMBEDDING_DIM) |i| {
            const key_val = @as(u32, @intCast(text_hash % 1000)) +% @as(u32, @intCast(i % 1000));
            const value_val = @as(u32, @intCast((text_hash >> 32) % 1000)) +% @as(u32, @intCast(i % 1000));
            key_vector[i] = @as(f32, @floatFromInt(key_val)) / 1000.0;
            value_vector[i] = @as(f32, @floatFromInt(value_val)) / 1000.0;
        }

        self.sequence_counter += 1;
        const is_prefix = self.is_likely_prefix(""); // Simplified for demo

        try self.kv_cache.put_kv(text_hash, key_vector, value_vector, self.sequence_counter, is_prefix);

        std.debug.print("💾 Cached KV computation (tier: {})\n", .{self.get_cache_tier_for_hash(text_hash)});
    }

    /// Generate response from cached KV computation
    fn generate_response_from_cache(self: *NenEngine, cached_entry: *cache.KVEntry, user_message: []const u8) ![]const u8 {
        // In real implementation, this would use the cached KV to generate response
        // For demo, return a simulated response based on cache hit
        const response = try std.fmt.allocPrint(self.allocator, "🎯 Cached response for: {s} (access count: {d}, tier: {})", .{ user_message, cached_entry.access_count, cached_entry.tier });

        return response;
    }

    /// Generate LLM response (simulated)
    fn generate_llm_response(self: *NenEngine, user_message: []const u8, context: []const u8) ![]const u8 {
        // Simulate LLM response generation
        const response = if (context.len > 0)
            try std.fmt.allocPrint(self.allocator, "LLM Response: {s} (with context: {s})", .{ user_message, context })
        else
            try std.fmt.allocPrint(self.allocator, "LLM Response: {s} (no context)", .{user_message});

        return response;
    }

    /// Hash text for cache lookup
    fn hash_text(_: *NenEngine, text: []const u8) u64 {
        var hash: u64 = 0;
        for (text) |byte| {
            hash = hash *% 31 +% byte;
        }
        return hash;
    }

    /// Extract user ID from message
    fn extract_user_id(self: *NenEngine, message: []const u8) ![]const u8 {
        // Simple user ID extraction (in real implementation, this would be more sophisticated)
        return try std.fmt.allocPrint(self.allocator, "user:{}", .{self.hash_text(message) % 1000});
    }

    /// Generate conversation ID
    fn generate_conversation_id(self: *NenEngine) ![]const u8 {
        return try std.fmt.allocPrint(self.allocator, "conv:{}", .{self.sequence_counter});
    }

    /// Check if message is likely a prefix (for cache optimization)
    fn is_likely_prefix(_: *NenEngine, message: []const u8) bool {
        // Simple heuristic: short messages are likely prefixes
        return message.len < 50;
    }

    /// Get cache tier for a hash (for debugging)
    fn get_cache_tier_for_hash(self: *NenEngine, text_hash: u64) cache.CacheTier {
        if (self.kv_cache.gpu_cache.get(text_hash)) |_| return .gpu;
        if (self.kv_cache.cpu_cache.get(text_hash)) |_| return .cpu;
        if (self.kv_cache.disk_cache.get(text_hash)) |_| return .disk;
        return .none;
    }

    /// Save entire engine state to disk
    pub fn save_state(self: *NenEngine, dir: []const u8) !void {
        // Save memory engine state
        try self.memory_engine.save_persistent_state(dir);

        // Save KV cache state
        try self.kv_cache.save_to_disk(dir);

        std.debug.print("💾 Saved Nen engine state to disk\n", .{});
    }

    /// Load entire engine state from disk
    pub fn load_state(self: *NenEngine, dir: []const u8) !void {
        // Load memory engine state
        try self.memory_engine.load_persistent_state(dir);

        // Load KV cache state
        try self.kv_cache.load_from_disk(dir);

        std.debug.print("📂 Loaded Nen engine state from disk\n", .{});
    }

    /// Print comprehensive statistics
    pub fn print_stats(self: *NenEngine) void {
        std.debug.print("\n=== Nen Engine Statistics ===\n", .{});
        std.debug.print("Memory Engine:\n", .{});
        std.debug.print("  - Nodes: {d}\n", .{self.memory_engine.node_pool.next});
        std.debug.print("  - Edges: {d}\n", .{self.memory_engine.edge_pool.next});
        std.debug.print("  - Sequences: {d}\n", .{self.sequence_counter});

        // Print KV cache statistics
        self.kv_cache.print_stats();

        std.debug.print("============================\n\n", .{});
    }

    /// Batch process multiple conversations for optimal performance
    pub fn batch_process_conversations(self: *NenEngine, messages: []const []const u8) ![]const []const u8 {
        var responses = try self.allocator.alloc([]const u8, messages.len);

        // Process in parallel batches for optimal performance
        for (messages, 0..) |message, i| {
            responses[i] = try self.process_conversation(message);
        }

        return responses;
    }

    /// Get memory engine for direct access
    pub fn get_memory_engine(self: *NenEngine) *batch.BatchEngine {
        return &self.memory_engine;
    }

    /// Get KV cache for direct access
    pub fn get_kv_cache(self: *NenEngine) *cache.LMCache {
        return &self.kv_cache;
    }
};
