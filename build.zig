const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add Nen ecosystem dependencies using relative paths
    const nen_io_dep = b.addModule("nen-io", .{
        .root_source_file = .{ .cwd_relative = "../nen-io/src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // nen-json has structural issues, using only nen-io for now
    // const nen_json_dep = b.addModule("nen-json", .{
    //     .root_source_file = .{ .cwd_relative = "src/vendor/nen-json/lib.zig" },
    //     .target = target,
    //     .optimize = optimize,
    // });
    
    // Add nen-io as a dependency to nen-json to resolve the conflict
    // nen_json_dep.addImport("nen-io", nen_io_dep);

    // Main NenCache library
    const lib = b.addStaticLibrary(.{
        .name = "nencache",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    
    // Add Nen ecosystem modules to the library
    lib.root_module.addImport("nen_io", nen_io_dep);
    // lib.root_module.addImport("nen_json", nen_json_dep);
    
    b.installArtifact(lib);

    // NenCache module for other projects
    const nencache_mod = b.addModule("nencache", .{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "nencache",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    // Run command
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run NenCache");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.addImport("nencache", nencache_mod);
    unit_tests.root_module.addImport("nen_io", nen_io_dep);
    // unit_tests.root_module.addImport("nen_json", nen_json_dep);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Performance tests
    const perf_tests = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "tests/test_performance.zig" },
        .target = target,
        .optimize = optimize,
    });
    perf_tests.root_module.addImport("nencache", nencache_mod);

    const run_perf_tests = b.addRunArtifact(perf_tests);
    const perf_step = b.step("perf", "Run performance tests");
    perf_step.dependOn(&run_perf_tests.step);

    // Performance benchmark
    const perf_bench = b.addTest(.{
        .root_source_file = .{ .cwd_relative = "tests/performance_benchmark.zig" },
        .target = target,
        .optimize = optimize,
    });
    perf_bench.root_module.addImport("nencache", nencache_mod);

    const run_perf_bench = b.addRunArtifact(perf_bench);
    const perf_bench_step = b.step("perf-bench", "Run performance benchmark");
    perf_bench_step.dependOn(&run_perf_bench.step);

    // Benchmarks
    const bench_exe = b.addExecutable(.{
        .name = "nencache-benchmark",
        .root_source_file = .{ .cwd_relative = "tests/benchmark.zig" },
        .target = target,
        .optimize = optimize,
    });
    bench_exe.root_module.addImport("nencache", nencache_mod);

    const run_bench = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // LMCache comparison benchmark
    const lmcache_bench_exe = b.addExecutable(.{
        .name = "nencache-vs-lmcache",
        .root_source_file = .{ .cwd_relative = "tests/lmcache_comparison.zig" },
        .target = target,
        .optimize = optimize,
    });
    lmcache_bench_exe.root_module.addImport("nencache", nencache_mod);

    const run_lmcache_bench = b.addRunArtifact(lmcache_bench_exe);
    const lmcache_bench_step = b.step("lmcache-bench", "Run LMCache comparison benchmark");
    lmcache_bench_step.dependOn(&run_lmcache_bench.step);

    // Examples
    const basic_example = b.addExecutable(.{
        .name = "basic-example",
        .root_source_file = .{ .cwd_relative = "examples/basic_usage.zig" },
        .target = target,
        .optimize = optimize,
    });
    basic_example.root_module.addImport("nencache", nencache_mod);

    const run_basic_example = b.addRunArtifact(basic_example);
    const basic_example_step = b.step("basic-example", "Run basic usage example");
    basic_example_step.dependOn(&run_basic_example.step);

    // Documentation
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&lib.step);
}
