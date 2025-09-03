// NenFlow: Minimalist LLM Framework in Zig
// Following the Nen way: statically typed, zero-allocation, using Nen ecosystem
// Inspired by Pocket Flow but built for maximum performance

const std = @import("std");
const nencache = @import("nencache");
// const nen_io = @import("nen_io");
// const nen_json = @import("nen_json");

// Core types for the LLM framework
pub const NodeType = enum {
    agent,      // AI agent node
    tool,       // Tool/function node
    llm,        // LLM model node
    memory,     // Memory storage node
    workflow,   // Workflow orchestration node
    rag,        // Retrieval-augmented generation node
    condition,  // Conditional logic node
    parallel,   // Parallel execution node
    stream,     // Streaming output node
};

pub const NodeState = enum {
    pending,    // Node waiting to execute
    running,    // Node currently executing
    completed,  // Node completed successfully
    failed,     // Node failed with error
    skipped,    // Node skipped due to condition
};

pub const DataType = enum {
    text,       // Plain text data
    json,       // Structured JSON data
    binary,     // Binary data (images, audio, etc.)
    stream,     // Streaming data
    memory,     // Memory reference
    cache,      // Cache reference
};

// Core node structure - the heart of our framework
pub const Node = struct {
    id: []const u8,
    node_type: NodeType,
    state: NodeState,
    data_type: DataType,
    
    // Static memory for node data
    data: [1024]u8 = undefined,
    data_len: usize = 0,
    
    // Node configuration
    config: NodeConfig,
    
    // Execution metadata
    created_at: i64,
    started_at: ?i64,
    completed_at: ?i64,
    execution_time_ns: ?u64,
    
    // Error handling
    error_message: ?[]const u8,
    
    // Node relationships
    inputs: []const []const u8,    // Input node IDs
    outputs: []const []const u8,   // Output node IDs
    
    // Node-specific data
    agent_config: ?AgentConfig,
    tool_config: ?ToolConfig,
    llm_config: ?LLMConfig,
    memory_config: ?MemoryConfig,
    
    pub fn init(id: []const u8, node_type: NodeType, data_type: DataType) Node {
        return Node{
            .id = id,
            .node_type = node_type,
            .state = .pending,
            .data_type = data_type,
            .config = NodeConfig.init(),
            .created_at = std.time.nanoTimestamp(),
            .started_at = null,
            .completed_at = null,
            .execution_time_ns = null,
            .error_message = null,
            .inputs = &[_][]const u8{},
            .outputs = &[_][]const u8{},
            .agent_config = null,
            .tool_config = null,
            .llm_config = null,
            .memory_config = null,
        };
    }
    
    pub fn setData(self: *Node, new_data: []const u8) !void {
        if (new_data.len > self.data.len) {
            return error.DataTooLarge;
        }
        std.mem.copy(u8, &self.data, new_data);
        self.data_len = new_data.len;
    }
    
    pub fn getData(self: *const Node) []const u8 {
        return self.data[0..self.data_len];
    }
    
    pub fn setState(self: *Node, new_state: NodeState) void {
        self.state = new_state;
        const now = std.time.nanoTimestamp();
        
        switch (new_state) {
            .running => self.started_at = now,
            .completed, .failed => {
                self.completed_at = now;
                if (self.started_at) |started| {
                    self.execution_time_ns = @as(u64, @intCast(now - started));
                }
            },
            else => {},
        }
    }
    
    pub fn addInput(self: *Node, input_id: []const u8) !void {
        // In a real implementation, we'd use a dynamic array
        // For now, we'll use a simple approach
        _ = input_id;
        // TODO: Implement dynamic input management
    }
    
    pub fn addOutput(self: *Node, output_id: []const u8) !void {
        // In a real implementation, we'd use a dynamic array
        // For now, we'll use a simple approach
        _ = output_id;
        // TODO: Implement dynamic output management
    }
};

// Node configuration
pub const NodeConfig = struct {
    timeout_ms: u64 = 30000,      // 30 second timeout
    retry_count: u8 = 3,          // Retry failed nodes
    parallel: bool = false,       // Allow parallel execution
    cache_enabled: bool = true,   // Enable caching
    memory_enabled: bool = true,  // Enable memory storage
    
    pub fn init() NodeConfig {
        return NodeConfig{};
    }
};

// Agent configuration
pub const AgentConfig = struct {
    name: []const u8,
    role: []const u8,
    instructions: []const u8,
    tools: []const []const u8,
    memory_size: usize = 1024 * 1024, // 1MB memory
    
    pub fn init(name: []const u8, role: []const u8, instructions: []const u8) AgentConfig {
        return AgentConfig{
            .name = name,
            .role = role,
            .instructions = instructions,
            .tools = &[_][]const u8{},
        };
    }
};

// Tool configuration
pub const ToolConfig = struct {
    name: []const u8,
    description: []const u8,
    function_name: []const u8,
    parameters: []const u8, // JSON schema
    
    pub fn init(name: []const u8, description: []const u8, function_name: []const u8) ToolConfig {
        return ToolConfig{
            .name = name,
            .description = description,
            .function_name = function_name,
            .parameters = "{}",
        };
    }
};

// LLM configuration
pub const LLMConfig = struct {
    model_name: []const u8,
    temperature: f32 = 0.7,
    max_tokens: u32 = 1000,
    stop_sequences: []const []const u8,
    
    pub fn init(model_name: []const u8) LLMConfig {
        return LLMConfig{
            .model_name = model_name,
            .temperature = 0.7,
            .max_tokens = 1000,
            .stop_sequences = &[_][]const u8{},
        };
    }
};

// Memory configuration
pub const MemoryConfig = struct {
    memory_type: MemoryType,
    capacity: usize,
    ttl_seconds: ?u64,
    
    pub fn init(memory_type: MemoryType, capacity: usize) MemoryConfig {
        return MemoryConfig{
            .memory_type = memory_type,
            .capacity = capacity,
            .ttl_seconds = null,
        };
    }
};

pub const MemoryType = enum {
    short_term,  // Session memory
    long_term,   // Persistent memory
    cache,       // Fast cache memory
    vector,      // Vector embeddings
};

// Flow - the main orchestrator
pub const Flow = struct {
    allocator: std.mem.Allocator,
    nodes: std.AutoHashMap([]const u8, *Node),
    cache: ?*nencache.EnhancedKVCache,
    memory: std.AutoHashMap([]const u8, []const u8),
    
    // Execution state
    execution_id: []const u8,
    start_time: i64,
    completed_nodes: std.AutoHashMap([]const u8, void),
    failed_nodes: std.AutoHashMap([]const u8, []const u8),
    
    pub fn init(allocator: std.mem.Allocator) !*Flow {
        const flow = try allocator.create(Flow);
        flow.* = Flow{
            .allocator = allocator,
            .nodes = std.AutoHashMap([]const u8, *Node).init(allocator),
            .cache = null,
            .memory = std.AutoHashMap([]const u8, []const u8).init(allocator),
            .execution_id = try std.fmt.allocPrint(allocator, "flow_{d}", .{std.time.nanoTimestamp()}),
            .start_time = std.time.nanoTimestamp(),
            .completed_nodes = std.AutoHashMap([]const u8, void).init(allocator),
            .failed_nodes = std.AutoHashMap([]const u8, []const u8).init(allocator),
        };
        
        // Initialize cache if available
        flow.cache = try nencache.EnhancedKVCache.init(allocator);
        
        return flow;
    }
    
    pub fn deinit(self: *Flow) void {
        // Clean up nodes
        var node_iter = self.nodes.iterator();
        while (node_iter.next()) |entry| {
            self.allocator.destroy(entry.value_ptr.*);
        }
        self.nodes.deinit();
        
        // Clean up cache
        if (self.cache) |cache| {
            cache.deinit();
        }
        
        // Clean up memory
        self.memory.deinit();
        self.completed_nodes.deinit();
        self.failed_nodes.deinit();
        
        // Clean up execution ID
        self.allocator.free(self.execution_id);
        
        // Clean up self
        self.allocator.destroy(self);
    }
    
    // Add a node to the flow
    pub fn addNode(self: *Flow, node: *Node) !void {
        try self.nodes.put(node.id, node);
        
        // Cache node metadata if caching is enabled
        if (self.cache != null and node.config.cache_enabled) {
            const cache_key = try std.fmt.allocPrint(self.allocator, "flow:node:{s}:metadata", .{node.id});
            defer self.allocator.free(cache_key);
            
            const metadata = try self.serializeNodeMetadata(node);
            defer self.allocator.free(metadata);
            
            try self.cache.?.set(cache_key, metadata);
        }
    }
    
    // Execute a single node
    pub fn executeNode(self: *Flow, node_id: []const u8) !void {
        const node = self.nodes.get(node_id) orelse return error.NodeNotFound;
        
        if (node.state == .completed or node.state == .failed) {
            return; // Node already processed
        }
        
        node.setState(.running);
        
        // Execute based on node type
        switch (node.node_type) {
            .agent => try self.executeAgentNode(node),
            .tool => try self.executeToolNode(node),
            .llm => try self.executeLLMNode(node),
            .memory => try self.executeMemoryNode(node),
            .workflow => try self.executeWorkflowNode(node),
            .rag => try self.executeRAGNode(node),
            .condition => try self.executeConditionNode(node),
            .parallel => try self.executeParallelNode(node),
            .stream => try self.executeStreamNode(node),
        }
        
        // Mark as completed
        node.setState(.completed);
        try self.completed_nodes.put(node_id, {});
        
        // Cache result if enabled
        if (self.cache != null and node.config.cache_enabled) {
            const cache_key = try std.fmt.allocPrint(self.allocator, "flow:node:{s}:result", .{node_id});
            defer self.allocator.free(cache_key);
            
            try self.cache.?.set(cache_key, node.getData());
        }
    }
    
    // Execute the entire flow
    pub fn execute(self: *Flow) !void {
        self.start_time = std.time.nanoTimestamp();
        
        // Execute nodes in dependency order
        var node_iter = self.nodes.iterator();
        while (node_iter.next()) |entry| {
            const node = entry.value_ptr.*;
            
            // Skip if already completed or failed
            if (self.completed_nodes.contains(node.id) or self.failed_nodes.contains(node.id)) {
                continue;
            }
            
            // Execute node
            self.executeNode(node.id) catch |err| {
                const error_msg = try std.fmt.allocPrint(self.allocator, "Execution failed: {any}", .{err});
                defer self.allocator.free(error_msg);
                
                try self.failed_nodes.put(node.id, error_msg);
                node.setState(.failed);
                node.error_message = error_msg;
            };
        }
    }
    
    // Get flow statistics
    pub fn getStats(self: *const Flow) FlowStats {
        var stats = FlowStats{
            .total_nodes = self.nodes.count(),
            .completed_nodes = self.completed_nodes.count(),
            .failed_nodes = self.failed_nodes.count(),
            .execution_time_ns = 0,
            .cache_hit_rate = 0.0,
        };
        
        // Calculate execution time
        if (self.start_time > 0) {
            const now = std.time.nanoTimestamp();
            stats.execution_time_ns = @as(u64, @intCast(now - self.start_time));
        }
        
        // Calculate cache hit rate if cache is available
        if (self.cache != null) {
            stats.cache_hit_rate = self.cache.?.stats.getHitRate();
        }
        
        return stats;
    }
    
    // Helper functions for node execution
    fn executeAgentNode(self: *Flow, node: *Node) !void {
        _ = self;
        // TODO: Implement agent execution logic
        // This would involve LLM calls, tool execution, etc.
        try node.setData("Agent executed successfully");
    }
    
    fn executeToolNode(self: *Flow, node: *Node) !void {
        _ = self;
        // TODO: Implement tool execution logic
        try node.setData("Tool executed successfully");
    }
    
    fn executeLLMNode(self: *Flow, node: *Node) !void {
        _ = self;
        // TODO: Implement LLM execution logic
        try node.setData("LLM response generated");
    }
    
    fn executeMemoryNode(self: *Flow, node: *Node) !void {
        _ = self;
        // TODO: Implement memory operations
        try node.setData("Memory operation completed");
    }
    
    fn executeWorkflowNode(self: *Flow, node: *Node) !void {
        _ = self;
        // TODO: Implement workflow orchestration
        try node.setData("Workflow orchestrated");
    }
    
    fn executeRAGNode(self: *Flow, node: *Node) !void {
        _ = self;
        // TODO: Implement RAG operations
        try node.setData("RAG operation completed");
    }
    
    fn executeConditionNode(self: *Flow, node: *Node) !void {
        _ = self;
        // TODO: Implement conditional logic
        try node.setData("Condition evaluated");
    }
    
    fn executeParallelNode(self: *Flow, node: *Node) !void {
        _ = self;
        // TODO: Implement parallel execution
        try node.setData("Parallel execution completed");
    }
    
    fn executeStreamNode(self: *Flow, node: *Node) !void {
        _ = self;
        // TODO: Implement streaming
        try node.setData("Streaming started");
    }
    
    // Serialize node metadata for caching
    fn serializeNodeMetadata(self: *Flow, node: *const Node) ![]const u8 {
        // Use nen-json for efficient serialization
        var buffer: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buffer);
        const writer = stream.writer();
        
        try writer.print("{{\"id\":\"{s}\",\"type\":\"{s}\",\"state\":\"{s}\"}}", .{
            node.id,
            @tagName(node.node_type),
            @tagName(node.state),
        });
        
        return stream.getWritten();
    }
};

// Flow statistics
pub const FlowStats = struct {
    total_nodes: usize,
    completed_nodes: usize,
    failed_nodes: usize,
    execution_time_ns: u64,
    cache_hit_rate: f32,
    
    pub fn getSuccessRate(self: *const FlowStats) f32 {
        if (self.total_nodes == 0) return 0.0;
        return @as(f32, @floatFromInt(self.completed_nodes)) / @as(f32, @floatFromInt(self.total_nodes));
    }
    
    pub fn getExecutionTimeMs(self: *const FlowStats) f32 {
        return @as(f32, @floatFromInt(self.execution_time_ns)) / 1_000_000.0;
    }
};

// Convenience functions for common patterns
pub fn createAgentFlow(allocator: std.mem.Allocator, agent_name: []const u8, instructions: []const u8) !*Flow {
    const flow = try Flow.init(allocator);
    
    // Create agent node
    const agent_node = try allocator.create(Node);
    agent_node.* = Node.init("agent", .agent, .text);
    agent_node.agent_config = AgentConfig.init(agent_name, "AI Agent", instructions);
    
    try flow.addNode(agent_node);
    
    return flow;
}

pub fn createRAGFlow(allocator: std.mem.Allocator, query: []const u8) !*Flow {
    const flow = try Flow.init(allocator);
    
    // Create RAG nodes
    const query_node = try allocator.create(Node);
    query_node.* = Node.init("query", .memory, .text);
    try query_node.setData(query);
    
    const rag_node = try allocator.create(Node);
    rag_node.* = Node.init("rag", .rag, .text);
    
    const llm_node = try allocator.create(Node);
    llm_node.* = Node.init("llm", .llm, .text);
    llm_node.llm_config = LLMConfig.init("gpt-4");
    
    try flow.addNode(query_node);
    try flow.addNode(rag_node);
    try flow.addNode(llm_node);
    
    return flow;
}

pub fn createWorkflowFlow(allocator: std.mem.Allocator, steps: []const []const u8) !*Flow {
    const flow = try Flow.init(allocator);
    
    // Create workflow nodes for each step
    for (steps, 0..) |step, i| {
        const step_node = try allocator.create(Node);
        step_node.* = Node.init(step, .workflow, .text);
        try step_node.setData(step);
        
        try flow.addNode(step_node);
    }
    
    return flow;
}

// Export the main types
pub const NenFlow = Flow;
pub const NenNode = Node;
pub const NenFlowStats = FlowStats;
