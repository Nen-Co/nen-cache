const std = @import("std");

pub const NODE_POOL_SIZE = 128;
pub const EDGE_POOL_SIZE = 128;
pub const EMBEDDING_DIM = 1024;
pub const EMBEDDING_POOL_SIZE = 128;

pub const Node = struct {
    id: u64,
    kind: u8,
    props: [64]u8,
};

pub const Edge = struct {
    from: u64,
    to: u64,
    label: u16,
    props: [32]u8,
};

pub const Embedding = struct {
    node_id: u64,
    vector: [EMBEDDING_DIM]f32,
};

pub const NodePool = struct {
    nodes: [NODE_POOL_SIZE]Node = undefined,
    next: usize = 0,

    pub fn alloc(self: *NodePool, node: Node) ?usize {
        if (self.next >= NODE_POOL_SIZE) return null;
        self.nodes[self.next] = node;
        const idx = self.next;
        self.next += 1;
        return idx;
    }

    pub fn get(self: *NodePool, idx: usize) ?*Node {
        if (idx >= NODE_POOL_SIZE) return null;
        return &self.nodes[idx];
    }

    /// Save the node pool to disk as a binary file (nodes.bin in given dir)
    pub fn save_to_disk(self: *NodePool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/nodes.bin", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true, .read = false });
        defer file.close();
        try file.writer().writeAll(std.mem.sliceAsBytes(self.nodes[0..self.next]));
    }

    /// Load the node pool from disk (nodes.bin in given dir)
    pub fn load_from_disk(self: *NodePool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/nodes.bin", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const file_size = (try file.stat()).size;
        const count = file_size / @sizeOf(Node);
        if (count > NODE_POOL_SIZE) return error.Overflow;
        const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
        defer std.heap.page_allocator.free(buf);
        @memcpy(self.nodes[0..count], std.mem.bytesAsSlice(Node, buf));
        self.next = count;
    }

    /// Append a WAL entry for node allocation
    pub fn wal_append(node: Node, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/nodes.wal", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
        defer file.close();
        try file.writer().writeAll(std.mem.sliceAsBytes(&[1]Node{node}));
    }

    /// Replay the WAL to restore state after loading snapshot
    pub fn wal_replay(self: *NodePool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/nodes.wal", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const file_size = (try file.stat()).size;
        const count = file_size / @sizeOf(Node);
        if (self.next + count > NODE_POOL_SIZE) return error.Overflow;
        const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
        defer std.heap.page_allocator.free(buf);
        for (0..count) |i| {
            self.nodes[self.next] = std.mem.bytesAsValue(Node, buf[i*@sizeOf(Node)..][0..@sizeOf(Node)]).*;
            self.next += 1;
        }
    }
};

pub const EdgePool = struct {
    edges: [EDGE_POOL_SIZE]Edge = undefined,
    next: usize = 0,

    pub fn alloc(self: *EdgePool, edge: Edge) ?usize {
        if (self.next >= EDGE_POOL_SIZE) return null;
        self.edges[self.next] = edge;
        const idx = self.next;
        self.next += 1;
        return idx;
    }

    pub fn get(self: *EdgePool, idx: usize) ?*Edge {
        if (idx >= EDGE_POOL_SIZE) return null;
        return &self.edges[idx];
    }

    /// Save the edge pool to disk as a binary file (edges.bin in given dir)
    pub fn save_to_disk(self: *EdgePool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/edges.bin", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true, .read = false });
        defer file.close();
        try file.writer().writeAll(std.mem.sliceAsBytes(self.edges[0..self.next]));
    }

    /// Load the edge pool from disk (edges.bin in given dir)
    pub fn load_from_disk(self: *EdgePool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/edges.bin", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const file_size = (try file.stat()).size;
        const count = file_size / @sizeOf(Edge);
        if (count > EDGE_POOL_SIZE) return error.Overflow;
        const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
        defer std.heap.page_allocator.free(buf);
        @memcpy(self.edges[0..count], std.mem.bytesAsSlice(Edge, buf));
        self.next = count;
    }

    /// Append a WAL entry for edge allocation
    pub fn wal_append(edge: Edge, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/edges.wal", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
        defer file.close();
        try file.writer().writeAll(std.mem.sliceAsBytes(&[1]Edge{edge}));
    }

    /// Replay the WAL to restore state after loading snapshot
    pub fn wal_replay(self: *EdgePool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/edges.wal", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const file_size = (try file.stat()).size;
        const count = file_size / @sizeOf(Edge);
        if (self.next + count > EDGE_POOL_SIZE) return error.Overflow;
        const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
        defer std.heap.page_allocator.free(buf);
        for (0..count) |i| {
            self.edges[self.next] = std.mem.bytesAsValue(Edge, buf[i*@sizeOf(Edge)..][0..@sizeOf(Edge)]).*;
            self.next += 1;
        }
    }
};

pub const EmbeddingPool = struct {
    embeddings: [EMBEDDING_POOL_SIZE]Embedding = undefined,
    next: usize = 0,

    pub fn alloc(self: *EmbeddingPool, emb: Embedding) ?usize {
        if (self.next >= EMBEDDING_POOL_SIZE) return null;
        self.embeddings[self.next] = emb;
        const idx = self.next;
        self.next += 1;
        return idx;
    }

    pub fn get(self: *EmbeddingPool, idx: usize) ?*Embedding {
        if (idx >= EMBEDDING_POOL_SIZE) return null;
        return &self.embeddings[idx];
    }

    /// Save the embedding pool to disk as a binary file (embeddings.bin in given dir)
    pub fn save_to_disk(self: *EmbeddingPool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/embeddings.bin", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true, .read = false });
        defer file.close();
        try file.writer().writeAll(std.mem.sliceAsBytes(self.embeddings[0..self.next]));
    }

    /// Load the embedding pool from disk (embeddings.bin in given dir)
    pub fn load_from_disk(self: *EmbeddingPool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/embeddings.bin", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const file_size = (try file.stat()).size;
        const count = file_size / @sizeOf(Embedding);
        if (count > EMBEDDING_POOL_SIZE) return error.Overflow;
        const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
        defer std.heap.page_allocator.free(buf);
        @memcpy(self.embeddings[0..count], std.mem.bytesAsSlice(Embedding, buf));
        self.next = count;
    }

    /// Append a WAL entry for embedding allocation
    pub fn wal_append(emb: Embedding, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/embeddings.wal", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
        defer file.close();
        try file.writer().writeAll(std.mem.sliceAsBytes(&[1]Embedding{emb}));
    }

    /// Replay the WAL to restore state after loading snapshot
    pub fn wal_replay(self: *EmbeddingPool, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/embeddings.wal", .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        const file_size = (try file.stat()).size;
        const count = file_size / @sizeOf(Embedding);
        if (self.next + count > EMBEDDING_POOL_SIZE) return error.Overflow;
        const buf = try file.reader().readAllAlloc(std.heap.page_allocator, file_size);
        defer std.heap.page_allocator.free(buf);
        for (0..count) |i| {
            self.embeddings[self.next] = std.mem.bytesAsValue(Embedding, buf[i*@sizeOf(Embedding)..][0..@sizeOf(Embedding)]).*;
            self.next += 1;
        }
    }
}; 

pub fn wal_append_node(node: Node, dir: []const u8) !void {
    const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/nodes.wal", .{dir});
    defer std.heap.page_allocator.free(file_path);
    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
    defer file.close();
    try file.writer().writeAll(std.mem.sliceAsBytes(&[1]Node{node}));
}

pub fn wal_append_edge(edge: Edge, dir: []const u8) !void {
    const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/edges.wal", .{dir});
    defer std.heap.page_allocator.free(file_path);
    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
    defer file.close();
    try file.writer().writeAll(std.mem.sliceAsBytes(&[1]Edge{edge}));
}

pub fn wal_append_embedding(emb: Embedding, dir: []const u8) !void {
    const file_path = try std.fmt.allocPrint(std.heap.page_allocator, "{s}/embeddings.wal", .{dir});
    defer std.heap.page_allocator.free(file_path);
    var file = try std.fs.cwd().createFile(file_path, .{ .truncate = false });
    defer file.close();
    try file.writer().writeAll(std.mem.sliceAsBytes(&[1]Embedding{emb}));
} 