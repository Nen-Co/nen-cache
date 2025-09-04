const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add Nen ecosystem dependencies using stub implementations for CI
    const nen_io_dep = b.createModule(.{
        .root_source_file = b.path("../nen-io/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const nen_json_dep = b.createModule(.{
        .root_source_file = b.path("src/stubs/nen_json.zig"),
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
    lib.root_module.addImport("nen_json", nen_json_dep);

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
    exe.root_module.addImport("nen_json", nen_json_dep);
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
    unit_tests.root_module.addImport("nen_json", nen_json_dep);

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

    // Examples
    const basic_example = b.addExecutable(.{
        .name = "basic-example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic_usage.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    basic_example.root_module.addImport("nencache", nencache_mod);

    const run_basic_example = b.addRunArtifact(basic_example);
    const basic_example_step = b.step("basic-example", "Run basic usage example");
    basic_example_step.dependOn(&run_basic_example.step);

    // Full stack demo
    const full_stack_demo = b.addExecutable(.{
        .name = "full-stack-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/full_stack_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    full_stack_demo.root_module.addImport("nencache", nencache_mod);
    full_stack_demo.root_module.addImport("nen_io", nen_io_dep);

    const run_full_stack_demo = b.addRunArtifact(full_stack_demo);
    const full_stack_demo_step = b.step("full-stack-demo", "Run full stack Nen ecosystem demo");
    full_stack_demo_step.dependOn(&run_full_stack_demo.step);

    // NenDB integration demo
    const nendb_demo = b.addExecutable(.{
        .name = "nendb-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/nendb_integration_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    nendb_demo.root_module.addImport("nencache", nencache_mod);
    nendb_demo.root_module.addImport("nen_io", nen_io_dep);

    const run_nendb_demo = b.addRunArtifact(nendb_demo);
    const nendb_demo_step = b.step("nendb-demo", "Run NenCache + NenDB integration demo");
    nendb_demo_step.dependOn(&run_nendb_demo.step);

    // Simple test
    const simple_test = b.addExecutable(.{
        .name = "simple-test",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/simple_test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    simple_test.root_module.addImport("nencache", nencache_mod);

    const run_simple_test = b.addRunArtifact(simple_test);
    const simple_test_step = b.step("simple-test", "Run simple NenCache test");
    simple_test_step.dependOn(&run_simple_test.step);

    // Interactive chatbot demo
    const chatbot_demo = b.addExecutable(.{
        .name = "chatbot-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/chatbot_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    chatbot_demo.root_module.addImport("nencache", nencache_mod);

    const run_chatbot_demo = b.addRunArtifact(chatbot_demo);
    const chatbot_demo_step = b.step("chatbot-demo", "Run interactive chatbot demo");
    chatbot_demo_step.dependOn(&run_chatbot_demo.step);

    // Ecosystem demo (non-interactive)
    const ecosystem_demo = b.addExecutable(.{
        .name = "ecosystem-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/ecosystem_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    ecosystem_demo.root_module.addImport("nencache", nencache_mod);

    const run_ecosystem_demo = b.addRunArtifact(ecosystem_demo);
    const ecosystem_demo_step = b.step("ecosystem-demo", "Run comprehensive Nen ecosystem demo");
    ecosystem_demo_step.dependOn(&run_ecosystem_demo.step);

    // Working chatbot demo (simulated conversation)
    const working_chatbot = b.addExecutable(.{
        .name = "working-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/working_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    working_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_working_chatbot = b.addRunArtifact(working_chatbot);
    const working_chatbot_step = b.step("working-chatbot", "Run working chatbot demo with simulated conversation");
    working_chatbot_step.dependOn(&run_working_chatbot.step);

    // Interactive chatbot using nen-io
    const interactive_chatbot = b.addExecutable(.{
        .name = "interactive-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/interactive_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    interactive_chatbot.root_module.addImport("nencache", nencache_mod);
    interactive_chatbot.root_module.addImport("nen_io", nen_io_dep);

    const run_interactive_chatbot = b.addRunArtifact(interactive_chatbot);
    const interactive_chatbot_step = b.step("interactive-chatbot", "Run REAL interactive chatbot using nen-io");
    interactive_chatbot_step.dependOn(&run_interactive_chatbot.step);

    // Real chatbot (command line argument based)
    const real_chatbot = b.addExecutable(.{
        .name = "real-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/real_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    real_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_real_chatbot = b.addRunArtifact(real_chatbot);
    const real_chatbot_step = b.step("real-chatbot", "Run real chatbot with command line input");
    real_chatbot_step.dependOn(&run_real_chatbot.step);

    // Live interactive chatbot
    const live_chatbot = b.addExecutable(.{
        .name = "live-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/live_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    live_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_live_chatbot = b.addRunArtifact(live_chatbot);
    const live_chatbot_step = b.step("live-chatbot", "Run live interactive chatbot with menu system");
    live_chatbot_step.dependOn(&run_live_chatbot.step);

    // Simple interactive chatbot using standard library
    const simple_interactive_chatbot = b.addExecutable(.{
        .name = "simple-interactive-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/simple_interactive_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    simple_interactive_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_simple_interactive_chatbot = b.addRunArtifact(simple_interactive_chatbot);
    const simple_interactive_chatbot_step = b.step("simple-interactive-chatbot", "Run REAL interactive chatbot using standard library");
    simple_interactive_chatbot_step.dependOn(&run_simple_interactive_chatbot.step);

    // Real interactive chatbot
    const real_interactive_chatbot = b.addExecutable(.{
        .name = "real-interactive-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/real_interactive_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    real_interactive_chatbot.root_module.addImport("nencache", nencache_mod);
    real_interactive_chatbot.root_module.addImport("nen-io", nen_io_dep);

    const run_real_interactive_chatbot = b.addRunArtifact(real_interactive_chatbot);
    const real_interactive_chatbot_step = b.step("real-interactive-chatbot", "Run REAL interactive chatbot with stdin input");
    real_interactive_chatbot_step.dependOn(&run_real_interactive_chatbot.step);

    // Final interactive chatbot
    const interactive_chatbot_final = b.addExecutable(.{
        .name = "interactive-chatbot-final",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/interactive_chatbot_final.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    interactive_chatbot_final.root_module.addImport("nencache", nencache_mod);

    const run_interactive_chatbot_final = b.addRunArtifact(interactive_chatbot_final);
    const interactive_chatbot_final_step = b.step("interactive-chatbot-final", "Run FINAL interactive chatbot - you can actually type and chat!");
    interactive_chatbot_final_step.dependOn(&run_interactive_chatbot_final.step);

    // Chat with me - truly interactive chatbot
    const chat_with_me = b.addExecutable(.{
        .name = "chat-with-me",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/chat_with_me.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    chat_with_me.root_module.addImport("nencache", nencache_mod);

    const run_chat_with_me = b.addRunArtifact(chat_with_me);
    const chat_with_me_step = b.step("chat-with-me", "Run interactive chatbot - YOU can type and chat with it!");
    chat_with_me_step.dependOn(&run_chat_with_me.step);

    // Real chat - truly interactive
    const real_chat = b.addExecutable(.{
        .name = "real-chat",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/real_chat.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    real_chat.root_module.addImport("nencache", nencache_mod);

    const run_real_chat = b.addRunArtifact(real_chat);
    const real_chat_step = b.step("real-chat", "Run REAL interactive chatbot - you can actually type and chat!");
    real_chat_step.dependOn(&run_real_chat.step);

    // Simple chat - working interactive demo
    const simple_chat = b.addExecutable(.{
        .name = "simple-chat",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/simple_chat.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    simple_chat.root_module.addImport("nencache", nencache_mod);

    const run_simple_chat = b.addRunArtifact(simple_chat);
    const simple_chat_step = b.step("simple-chat", "Run simple interactive chatbot demo");
    simple_chat_step.dependOn(&run_simple_chat.step);

    // Chat demo - working interactive chatbot
    const chat_demo = b.addExecutable(.{
        .name = "chat-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/chat_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    chat_demo.root_module.addImport("nencache", nencache_mod);

    const run_chat_demo = b.addRunArtifact(chat_demo);
    const chat_demo_step = b.step("chat-demo", "Run working interactive chatbot demo");
    chat_demo_step.dependOn(&run_chat_demo.step);

    // Working chat - simple interactive chatbot
    const working_chat = b.addExecutable(.{
        .name = "working-chat",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/working_chat.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    working_chat.root_module.addImport("nencache", nencache_mod);

    const run_working_chat = b.addRunArtifact(working_chat);
    const working_chat_step = b.step("working-chat", "Run working interactive chatbot - you can see it in action!");
    working_chat_step.dependOn(&run_working_chat.step);

    // Conversation chatbot - stores all conversations
    const conversation_chatbot = b.addExecutable(.{
        .name = "conversation-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/conversation_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    conversation_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_conversation_chatbot = b.addRunArtifact(conversation_chatbot);
    const conversation_chatbot_step = b.step("conversation-chatbot", "Run conversation chatbot that stores ALL conversations in NenCache!");
    conversation_chatbot_step.dependOn(&run_conversation_chatbot.step);

    // Terminal chatbot - truly interactive terminal conversation
    const terminal_chatbot = b.addExecutable(.{
        .name = "terminal-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/terminal_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    terminal_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_terminal_chatbot = b.addRunArtifact(terminal_chatbot);
    const terminal_chatbot_step = b.step("terminal-chatbot", "Run truly interactive terminal chatbot - type and chat directly!");
    terminal_chatbot_step.dependOn(&run_terminal_chatbot.step);

    // Simple interactive chatbot - demonstrates conversation storage
    const simple_interactive = b.addExecutable(.{
        .name = "simple-interactive",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/simple_interactive.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    simple_interactive.root_module.addImport("nencache", nencache_mod);

    const run_simple_interactive = b.addRunArtifact(simple_interactive);
    const simple_interactive_step = b.step("simple-interactive", "Run simple interactive chatbot that demonstrates conversation storage!");
    simple_interactive_step.dependOn(&run_simple_interactive.step);

    // Interactive demo - demonstrates conversation storage
    const interactive_demo = b.addExecutable(.{
        .name = "interactive-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/interactive_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    interactive_demo.root_module.addImport("nencache", nencache_mod);

    const run_interactive_demo = b.addRunArtifact(interactive_demo);
    const interactive_demo_step = b.step("interactive-demo", "Run interactive demo that shows conversation storage in action!");
    interactive_demo_step.dependOn(&run_interactive_demo.step);

    // Working interactive chatbot - no build errors
    const working_interactive_chatbot = b.addExecutable(.{
        .name = "working-interactive-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/working_interactive_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    working_interactive_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_working_interactive_chatbot = b.addRunArtifact(working_interactive_chatbot);
    const working_interactive_chatbot_step = b.step("working-interactive-chatbot", "Run working interactive chatbot with no build errors!");
    working_interactive_chatbot_step.dependOn(&run_working_interactive_chatbot.step);

    // Simple conversation demo - no build errors, shows conversation storage
    const simple_conversation_demo = b.addExecutable(.{
        .name = "simple-conversation-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/simple_conversation_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    simple_conversation_demo.root_module.addImport("nencache", nencache_mod);

    const run_simple_conversation_demo = b.addRunArtifact(simple_conversation_demo);
    const simple_conversation_demo_step = b.step("simple-conversation-demo", "Run simple conversation demo that shows conversation storage working!");
    simple_conversation_demo_step.dependOn(&run_simple_conversation_demo.step);

    // Stay open chatbot - truly interactive, stays open for typing
    const stay_open_chatbot = b.addExecutable(.{
        .name = "stay-open-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/stay_open_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    stay_open_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_stay_open_chatbot = b.addRunArtifact(stay_open_chatbot);
    const stay_open_chatbot_step = b.step("stay-open-chatbot", "Run chatbot that STAYS OPEN so you can type and chat!");
    stay_open_chatbot_step.dependOn(&run_stay_open_chatbot.step);

    // Conversation storage demo - shows conversation storage working
    const conversation_storage_demo = b.addExecutable(.{
        .name = "conversation-storage-demo",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/conversation_storage_demo.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    conversation_storage_demo.root_module.addImport("nencache", nencache_mod);

    const run_conversation_storage_demo = b.addRunArtifact(conversation_storage_demo);
    const conversation_storage_demo_step = b.step("conversation-storage-demo", "Run conversation storage demo that shows conversations being stored!");
    conversation_storage_demo_step.dependOn(&run_conversation_storage_demo.step);

    // Truly interactive chatbot - STAYS OPEN for real typing
    const truly_interactive_chatbot = b.addExecutable(.{
        .name = "truly-interactive-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/truly_interactive_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    truly_interactive_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_truly_interactive_chatbot = b.addRunArtifact(truly_interactive_chatbot);
    const truly_interactive_chatbot_step = b.step("truly-interactive-chatbot", "Run TRULY interactive chatbot that STAYS OPEN for real typing!");
    truly_interactive_chatbot_step.dependOn(&run_truly_interactive_chatbot.step);

    // Live interactive chatbot - STAYS OPEN for real typing and chatting
    const live_interactive_chatbot = b.addExecutable(.{
        .name = "live-interactive-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/live_interactive_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    live_interactive_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_live_interactive_chatbot = b.addRunArtifact(live_interactive_chatbot);
    const live_interactive_chatbot_step = b.step("live-interactive-chatbot", "Run LIVE interactive chatbot that STAYS OPEN for real typing and chatting!");
    live_interactive_chatbot_step.dependOn(&run_live_interactive_chatbot.step);

    // Simple live chatbot - STAYS OPEN for real typing and chatting
    const simple_live_chatbot = b.addExecutable(.{
        .name = "simple-live-chatbot",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/simple_live_chatbot.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    simple_live_chatbot.root_module.addImport("nencache", nencache_mod);

    const run_simple_live_chatbot = b.addRunArtifact(simple_live_chatbot);
    const simple_live_chatbot_step = b.step("simple-live-chatbot", "Run SIMPLE live chatbot that STAYS OPEN for real typing and chatting!");
    simple_live_chatbot_step.dependOn(&run_simple_live_chatbot.step);

    // Chat now - STAYS OPEN for real typing and chatting
    const chat_now = b.addExecutable(.{
        .name = "chat-now",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/chat_now.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    chat_now.root_module.addImport("nencache", nencache_mod);

    const run_chat_now = b.addRunArtifact(chat_now);
    const chat_now_step = b.step("chat-now", "Run CHAT NOW - STAYS OPEN for real typing and chatting!");
    chat_now_step.dependOn(&run_chat_now.step);

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
