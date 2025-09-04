// Minimal DOD Test
// Test basic DOD functionality

const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    std.debug.print("Testing DOD initialization...\n", .{});
    
    // Test DOD layout initialization
    var cache_layout = nencache.dod_layout.DODCacheLayout.init();
    std.debug.print("✅ DOD layout initialized\n", .{});
    
    // Test adding a key
    const key = "test_key";
    const key_index = try cache_layout.addKey(key, 1);
    std.debug.print("✅ Added key at index {d}\n", .{key_index});
    
    // Test adding a value
    const value = "test_value";
    const value_index = try cache_layout.addValue(value, 1, false);
    std.debug.print("✅ Added value at index {d}\n", .{value_index});
    
    // Test getting stats
    const stats = cache_layout.getStats();
    std.debug.print("✅ Got stats: {d} keys, {d} values\n", .{stats.key_count, stats.value_count});
    
    std.debug.print("🎉 All DOD tests passed!\n", .{});
}
