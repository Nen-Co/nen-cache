// Stub implementation of nen-io for CI builds
// This provides minimal functionality to allow nen-cache to build without external dependencies

const std = @import("std");

// Minimal stub implementations
pub const File = struct {
    pub fn readAll(self: *@This(), buffer: []u8) !usize {
        _ = self;
        _ = buffer;
        return 0;
    }

    pub fn writeAll(self: *@This(), data: []const u8) !void {
        _ = self;
        _ = data;
    }

    pub fn sync(self: *@This()) !void {
        _ = self;
    }
};

pub const Network = struct {
    pub fn connect(self: *@This(), host: []const u8, port: u16) !void {
        _ = self;
        _ = host;
        _ = port;
    }
};

pub const Performance = struct {
    pub fn startTimer(self: *@This()) void {
        _ = self;
    }

    pub fn endTimer(self: *@This()) u64 {
        _ = self;
        return 0;
    }
};

pub const Validation = struct {
    pub fn validate(self: *@This(), data: []const u8) !void {
        _ = self;
        _ = data;
    }
};

pub const Error = struct {
    pub const IoError = error{FileNotFound};
    pub const NetworkError = error{ConnectionFailed};
    pub const ValidationError = error{InvalidData};
};

pub const Log = struct {
    pub fn info(self: *@This(), message: []const u8) void {
        _ = self;
        _ = message;
    }

    pub fn logError(self: *@This(), message: []const u8) void {
        _ = self;
        _ = message;
    }
};

// Batching functionality
pub const batching = struct {
    pub const MemoryBatch = struct {
        pub fn init(allocator: std.mem.Allocator) !@This() {
            _ = allocator;
            return MemoryBatch{};
        }

        pub fn deinit(self: *@This()) void {
            _ = self;
        }

        pub fn add(self: *@This(), data: []const u8) !void {
            _ = self;
            _ = data;
        }
    };

    pub const NetworkBatch = struct {
        pub fn init(allocator: std.mem.Allocator) !@This() {
            _ = allocator;
            return NetworkBatch{};
        }

        pub fn deinit(self: *@This()) void {
            _ = self;
        }

        pub fn send(self: *@This(), data: []const u8) !void {
            _ = self;
            _ = data;
        }
    };
};

// File operations
pub fn readJson(path: []const u8) ![]const u8 {
    _ = path;
    return "{}";
}

pub fn writeJson(path: []const u8, content: []const u8) !void {
    _ = path;
    _ = content;
}

pub fn validateJson(path: []const u8) !void {
    _ = path;
}

pub const FileStats = struct {
    size: usize = 0,
    modified: u64 = 0,
};

pub fn getFileStats(path: []const u8) !FileStats {
    _ = path;
    return FileStats{};
}

pub fn isReadable(path: []const u8) !bool {
    _ = path;
    return true;
}

pub fn getFileSize(path: []const u8) !usize {
    _ = path;
    return 0;
}

// Streaming JSON parser
pub const StreamingJsonParser = struct {
    pub fn init() @This() {
        return StreamingJsonParser{};
    }

    pub const Stats = struct {
        bytes_processed: usize = 0,
        objects_parsed: usize = 0,
    };

    pub fn getStats(self: *@This()) Stats {
        _ = self;
        return Stats{};
    }
};
