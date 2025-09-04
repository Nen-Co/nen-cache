// Simple DOD Test
// Test basic DOD functionality with minimal data

const std = @import("std");
const nencache = @import("nencache");

pub fn main() !void {
    std.debug.print("Testing simple DOD...\n", .{});
    
    // Test DOD config
    const config = nencache.dod_config.DOD_CONSTANTS;
    std.debug.print("✅ DOD config loaded: MAX_KEYS={d}\n", .{config.MAX_KEYS});
    
    // Test DOD layout initialization
    _ = nencache.dod_layout.DODCacheLayout.init();
    std.debug.print("✅ DOD layout initialized\n", .{});
    
    std.debug.print("🎉 Simple DOD test passed!\n", .{});
}
