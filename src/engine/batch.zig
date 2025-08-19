const std = @import("std");
const pool = @import("pool.zig");

pub const NodeDef = struct { id: []const u8, kind: u8, props: [64]u8 };
pub const EdgeDef = struct { from: []const u8, to: []const u8, label: u16, props: [32]u8 };
const EdgeIndex = struct { from: usize, to: usize, label: u16 };

pub const BatchNodeInsert = struct {
    nodes: []const NodeDef,
};

pub const BatchEdgeInsert = struct {
    edges: []const EdgeDef,
};

pub const BatchEmbeddingInsert = struct {
    embeddings: []const struct { node_id: []const u8, vector: [pool.EMBEDDING_DIM]f32 },
};

pub const BatchEngine = struct {
    node_pool: *pool.NodePool,
    edge_pool: *pool.EdgePool,
    embedding_pool: *pool.EmbeddingPool,
    id_to_idx: std.StringHashMap(usize),
    edge_indices: std.ArrayList(EdgeIndex),

    pub fn init(allocator: *std.mem.Allocator, node_pool: *pool.NodePool, edge_pool: *pool.EdgePool, embedding_pool: *pool.EmbeddingPool) !BatchEngine {
        return BatchEngine{
            .node_pool = node_pool,
            .edge_pool = edge_pool,
            .embedding_pool = embedding_pool,
            .id_to_idx = std.StringHashMap(usize).init(allocator.*),
            .edge_indices = std.ArrayList(EdgeIndex).init(allocator.*),
        };
    }

    pub fn batch_insert_nodes(self: *BatchEngine, batch: BatchNodeInsert) ![]?usize {
        var results = try self.id_to_idx.allocator.alloc(?usize, batch.nodes.len);
        for (batch.nodes, 0..) |n, i| {
            const node = pool.Node{ .id = @as(u64, self.id_to_idx.count()), .kind = n.kind, .props = n.props };
            // WAL: log before allocation
            try pool.wal_append_node(node, ".");
            const idx = self.node_pool.alloc(node);
            if (idx) |real_idx| {
                try self.id_to_idx.put(n.id, real_idx);
                results[i] = real_idx;
            } else {
                results[i] = null;
            }
        }
        return results;
    }

    pub fn batch_insert_edges(self: *BatchEngine, batch: BatchEdgeInsert) ![]?usize {
        var results = try self.id_to_idx.allocator.alloc(?usize, batch.edges.len);
        for (batch.edges, 0..) |e, i| {
            const from_idx = self.id_to_idx.get(e.from) orelse null;
            const to_idx = self.id_to_idx.get(e.to) orelse null;
            if (from_idx == null or to_idx == null) {
                results[i] = null;
                continue;
            }
            const edge = pool.Edge{ .from = @as(u64, from_idx.?), .to = @as(u64, to_idx.?), .label = e.label, .props = e.props };
            // WAL: log before allocation
            try pool.wal_append_edge(edge, ".");
            const idx = self.edge_pool.alloc(edge);
            if (idx) |real_idx| {
                try self.edge_indices.append(.{ .from = from_idx.?, .to = to_idx.?, .label = e.label });
                results[i] = real_idx;
            } else {
                results[i] = null;
            }
        }
        return results;
    }

    pub fn batch_insert_embeddings(self: *BatchEngine, batch: BatchEmbeddingInsert) ![]?usize {
        var results = try self.id_to_idx.allocator.alloc(?usize, batch.embeddings.len);
        for (batch.embeddings, 0..) |e, i| {
            const node_idx = self.id_to_idx.get(e.node_id) orelse null;
            if (node_idx == null) {
                results[i] = null;
                continue;
            }
            const emb = pool.Embedding{ .node_id = @as(u64, node_idx.?), .vector = e.vector };
            // WAL: log before allocation
            try pool.wal_append_embedding(emb, ".");
            const idx = self.embedding_pool.alloc(emb);
            results[i] = idx;
        }
        return results;
    }

    pub fn assemble_context(self: *BatchEngine, id: []const u8, buf: []u8) !usize {
        // Simple context: node info and connected nodes
        var written: usize = 0;
        const idx = self.id_to_idx.get(id) orelse return 0;
        const node = self.node_pool.get(idx) orelse return 0;
        const n = node.*;
        const out = try std.fmt.bufPrint(buf[written..], "Node {} (kind: {}): ", .{ n.id, n.kind });
        written += out.len;
        // Add properties as string
        var prop_end: usize = 0;
        while (prop_end < node.props.len and node.props[prop_end] != 0) : (prop_end += 1) {}
        const out2 = try std.fmt.bufPrint(buf[written..], "{s}\n", .{ n.props[0..prop_end] });
        written += out2.len;
        // Add neighbors
        var found = false;
        for (self.edge_indices.items) |edge| {
            if (edge.from == idx) {
                if (!found) {
                    const out3 = try std.fmt.bufPrint(buf[written..], "  Connected to: ", .{});
                    written += out3.len;
                    found = true;
                }
                const out4 = try std.fmt.bufPrint(buf[written..], "{} ", .{edge.to});
                written += out4.len;
            }
        }
        if (found) {
            const out5 = try std.fmt.bufPrint(buf[written..], "\n", .{});
            written += out5.len;
        }
        return written;
    }

    pub fn load_persistent_state(self: *BatchEngine, dir: []const u8) !void {
        // Load snapshot, then replay WAL for all pools
        try self.node_pool.load_from_disk(dir);
        try self.edge_pool.load_from_disk(dir);
        try self.embedding_pool.load_from_disk(dir);
        try self.node_pool.wal_replay(dir);
        try self.edge_pool.wal_replay(dir);
        try self.embedding_pool.wal_replay(dir);
    }

    pub fn save_persistent_state(self: *BatchEngine, dir: []const u8) !void {
        // Save snapshot, then truncate WAL for all pools
        try self.node_pool.save_to_disk(dir);
        try self.edge_pool.save_to_disk(dir);
        try self.embedding_pool.save_to_disk(dir);
        // Truncate WAL files
        try truncate_file("{s}/nodes.wal", dir);
        try truncate_file("{s}/edges.wal", dir);
        try truncate_file("{s}/embeddings.wal", dir);
    }

    fn truncate_file(comptime fmt: []const u8, dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(std.heap.page_allocator, fmt, .{dir});
        defer std.heap.page_allocator.free(file_path);
        var file = try std.fs.cwd().createFile(file_path, .{ .truncate = true, .read = false });
        file.close();
    }
}; 