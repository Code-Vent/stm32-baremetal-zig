const std = @import("std");

pub fn build(b: *std.Build) void {
    // Define Bluepill (STM32F103, Cortex-M3, Thumb instruction set)
    const query = std.Target.Query{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m3 },
        .os_tag = .freestanding,
        .abi = .eabi,
    };
    const target = b.resolveTargetQuery(query);

    const optimize = b.standardOptimizeOption(.{});

    // Build object file from main.zig
    const obj = b.addObject(.{
        .name = "firmware",
        .root_source_file = b.path("src/startup.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add MCU module
    obj.root_module.addImport("mcu", b.createModule(.{
        .root_source_file = b.path("src/stm32f103c8/mcu.zig"),
    }));

    obj.root_module.strip = true;
    obj.root_module.single_threaded = true;
    obj.root_module.unwind_tables = .none;
    obj.root_module.stack_protector = false; // optional

    // Install firmware.o into lib/
    const obj_path = obj.getEmittedBin();
    const install_step = b.addInstallFile(obj_path, "lib/firmware.o");
    b.getInstallStep().dependOn(&install_step.step);

    // Post-build: run build.bat after generating ELF
    // Post build step: run build.bat after linking
    const post = b.addSystemCommand(&.{
        "cmd", "/C", "build.bat",
    });
    post.step.dependOn(&obj.step);

    // Option A: always run build.bat after zig build
    b.getInstallStep().dependOn(&post.step);
}
