// Stub implementation of nen-json for CI builds
// This provides minimal functionality to allow nen-cache to build without external dependencies

const std = @import("std");

// Minimal stub implementations
pub const Parser = struct {
    pub fn init(allocator: std.mem.Allocator) !@This() {
        _ = allocator;
        return Parser{};
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }

    pub fn parse(self: *@This(), json: []const u8) !void {
        _ = self;
        _ = json;
    }
};

pub const Serializer = struct {
    pub fn init(allocator: std.mem.Allocator) !@This() {
        _ = allocator;
        return Serializer{};
    }

    pub fn deinit(self: *@This()) void {
        _ = self;
    }

    pub fn serialize(self: *@This(), data: anytype) ![]const u8 {
        _ = self;
        _ = data;
        return "{}";
    }
};

pub const Validator = struct {
    pub fn init() @This() {
        return Validator{};
    }

    pub fn validate(self: *@This(), json: []const u8) !void {
        _ = self;
        _ = json;
    }
};

pub const Error = struct {
    pub const ParseError = error{InvalidJson};
    pub const SerializeError = error{SerializationFailed};
    pub const ValidationError = error{ValidationFailed};
};

// File operations
pub fn readFromFile(path: []const u8) ![]const u8 {
    _ = path;
    return "{}";
}

pub fn writeToFile(path: []const u8, json: []const u8) !void {
    _ = path;
    _ = json;
}

pub fn validateFile(path: []const u8) !void {
    _ = path;
}

// Utility functions
pub fn isValidJson(json: []const u8) bool {
    _ = json;
    return true;
}

pub fn minifyJson(json: []const u8) ![]const u8 {
    return json;
}

pub fn prettifyJson(json: []const u8) ![]const u8 {
    return json;
}
