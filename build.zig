const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = std.zig.CrossTarget{
        .cpu_arch = .thumb,
        .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_m3 },
        .os_tag = .freestanding,
        .abi = .eabi,
    };

    const optimize = b.standardOptimizeOption(.{});

    const obj = b.addObject(.{
        .name = "firmware",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    obj.addModule("mcu", b.createModule(.{
        .source_file = .{ .path = "src/stm32f103c8/mcu.zig" },
    }));

    const obj_path = obj.getEmittedBin();
    const install_step = b.addInstallFile(obj_path, "lib/firmware.o");
    b.getInstallStep().dependOn(&install_step.step);
}
