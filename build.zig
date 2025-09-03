const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add Nen ecosystem dependencies using relative paths
    const nen_io_dep = b.createModule(.{
        .root_source_file = b.path("../nen-io/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    // nen-json has structural issues, using only nen-io for now
    // const nen_json_dep = b.addModule("nen-json", .{
    //     .root_source_file = b.path("src/vendor/nen-json/lib.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // Add nen-io as a dependency to nen-json to resolve the conflict
    // nen_json_dep.addImport("nen-io", nen_io_dep);

    // Main NenCache library
    const lib = b.addExecutable(.{
        .name = "nencache-lib",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Add Nen ecosystem modules to the library
    lib.root_module.addImport("nen_io", nen_io_dep);
    // lib.root_module.addImport("nen_json", nen_json_dep);

    b.installArtifact(lib);

    // NenCache module for other projects
    const nencache_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Main executable
    const exe = b.addExecutable(.{
        .name = "nencache",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("nen_io", nen_io_dep);
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
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    unit_tests.root_module.addImport("nencache", nencache_mod);
    unit_tests.root_module.addImport("nen_io", nen_io_dep);
    // unit_tests.root_module.addImport("nen_json", nen_json_dep);

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    // Performance tests
    const perf_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/performance_benchmark.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    perf_tests.root_module.addImport("nencache", nencache_mod);

    const run_perf_tests = b.addRunArtifact(perf_tests);
    const perf_step = b.step("perf", "Run performance tests");
    perf_step.dependOn(&run_perf_tests.step);

    // Performance benchmark
    const perf_bench = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/performance_benchmark.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    perf_bench.root_module.addImport("nencache", nencache_mod);

    const run_perf_bench = b.addRunArtifact(perf_bench);
    const perf_bench_step = b.step("perf-bench", "Run performance benchmark");
    perf_bench_step.dependOn(&run_perf_bench.step);

    // Benchmarks
    const bench_exe = b.addExecutable(.{
        .name = "nencache-benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/benchmark.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    bench_exe.root_module.addImport("nencache", nencache_mod);

    const run_bench = b.addRunArtifact(bench_exe);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // LMCache comparison benchmark - commented out for now
    // const lmcache_bench_exe = b.addExecutable(.{
    //     .name = "nencache-vs-lmcache",
    //     .root_source_file = b.path("tests/lmcache_comparison.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // lmcache_bench_exe.root_module.addImport("nencache", nencache_mod);

    // const run_lmcache_bench = b.addRunArtifact(lmcache_bench_exe);
    // const lmcache_bench_step = b.step("lmcache-bench", "Run LMCache comparison benchmark");
    // lmcache_bench_step.dependOn(&run_lmcache_bench.step);

    // Examples - commented out for now
    // const basic_example = b.addExecutable(.{
    //     .name = "basic-example",
    //     .root_source_file = b.path("examples/basic_usage.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // basic_example.root_module.addImport("nencache", nencache_mod);

    // const run_basic_example = b.addRunArtifact(basic_example);
    // const basic_example_step = b.step("basic-example", "Run basic usage example");
    // basic_example_step.dependOn(&run_basic_example.step);

    // Full stack demo - commented out for now
    // const full_stack_demo = b.addExecutable(.{
    //     .name = "full-stack-demo",
    //     .root_source_file = b.path("examples/full_stack_demo.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // full_stack_demo.root_module.addImport("nencache", nencache_mod);
    // full_stack_demo.root_module.addImport("nen_io", nen_io_dep);

    // const run_full_stack_demo = b.addRunArtifact(full_stack_demo);
    // const full_stack_demo_step = b.step("full-stack-demo", "Run full stack Nen ecosystem demo");
    // full_stack_demo_step.dependOn(&run_full_stack_demo.step);

    // NenDB integration demo - commented out for now
    // const nendb_demo = b.addExecutable(.{
    //     .name = "nendb-demo",
    //     .root_source_file = b.path("examples/nendb_integration_demo.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // nendb_demo.root_module.addImport("nencache", nencache_mod);
    // nendb_demo.root_module.addImport("nen_io", nen_io_dep);

    // const run_nendb_demo = b.addRunArtifact(nendb_demo);
    // const nendb_demo_step = b.step("nendb-demo", "Run NenCache + NenDB integration demo");
    // nendb_demo_step.dependOn(&run_nendb_demo.step);

    // NenDB cache layer demo - commented out for now
    // const nendb_cache_demo = b.addExecutable(.{
    //     .name = "nendb-cache-demo",
    //     .root_source_file = b.path("examples/nendb_cache_layer_demo.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // nendb_cache_demo.root_module.addImport("nencache", nencache_mod);
    // nendb_cache_demo.root_module.addImport("nen_io", nen_io_dep);

    // const run_nendb_cache_demo = b.addRunArtifact(nendb_cache_demo);
    // const nendb_cache_demo_step = b.step("nendb-cache-demo", "Run NenDB + NenCache cache layer demo");
    // nendb_cache_demo_step.dependOn(&run_nendb_cache_demo.step);

    // Nen integration test - commented out for now
    // const nen_test = b.addExecutable(.{
    //     .name = "nen-test",
    //     .root_source_file = b.path("test_nen_integration.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // nen_test.root_module.addImport("nencache", nencache_mod);
    // nen_test.root_module.addImport("nen_io", nen_io_dep);

    // const run_nen_test = b.addRunArtifact(nen_test);
    // const nen_test_step = b.step("nen-test", "Run Nen ecosystem integration test");
    // nen_test_step.dependOn(&run_nen_test.step);

    // Llama integration test - commented out for now
    // const llama_test = b.addExecutable(.{
    //     .name = "llama-test",
    //     .root_source_file = b.path("test_llama_integration.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // llama_test.root_module.addImport("nencache", nencache_mod);
    // llama_test.root_module.addImport("nen_io", nen_io_dep);

    // const run_llama_test = b.addRunArtifact(llama_test);
    // const llama_test_step = b.step("llama-test", "Run Llama model integration test");
    // llama_test_step.dependOn(&run_llama_test.step);

    // Documentation
    const docs_step = b.step("docs", "Generate documentation");
    docs_step.dependOn(&lib.step);
}
