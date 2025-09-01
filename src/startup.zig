const std = @import("std");
const main = @import("main.zig");

extern var _sdata: u32;
extern var _edata: u32;
extern var __bss_start__: u32;
extern var __bss_end__: u32;
extern var _sidata: u32; // flash copy of .data

extern var _estack: u32;

extern fn NMI_Handler() callconv(.C) void;
extern fn HardFault_Handler() callconv(.C) void;
extern fn MemManage_Handler() callconv(.C) void;
extern fn BusFault_Handler() callconv(.C) void;
extern fn UsageFault_Handler() callconv(.C) void;
extern fn SVC_Handler() callconv(.C) void;
extern fn DebugMon_Handler() callconv(.C) void;
extern fn PendSV_Handler() callconv(.C) void;
extern fn SysTick_Handler() callconv(.C) void;
extern fn WWDG_Handler() callconv(.C) void;
extern fn PVD_Handler() callconv(.C) void;
extern fn TAMPER_Handler() callconv(.C) void;
extern fn RTC_Handler() callconv(.C) void;
extern fn FLASH_Handler() callconv(.C) void;
extern fn RCC_Handler() callconv(.C) void;
extern fn EXTI0_Handler() callconv(.C) void;
extern fn EXTI1_Handler() callconv(.C) void;
extern fn EXTI2_Handler() callconv(.C) void;
extern fn EXTI3_Handler() callconv(.C) void;
extern fn EXTI4_Handler() callconv(.C) void;
extern fn DMA1_Channel1_Handler() callconv(.C) void;
extern fn DMA1_Channel2_Handler() callconv(.C) void;
extern fn DMA1_Channel3_Handler() callconv(.C) void;
extern fn DMA1_Channel4_Handler() callconv(.C) void;
extern fn DMA1_Channel5_Handler() callconv(.C) void;
extern fn DMA1_Channel6_Handler() callconv(.C) void;
extern fn DMA1_Channel7_Handler() callconv(.C) void;
extern fn ADC1_2_Handler() callconv(.C) void;
extern fn TIM1_BRK_Handler() callconv(.C) void;
extern fn TIM1_UP_Handler() callconv(.C) void;
extern fn TIM1_TRG_COM_Handler() callconv(.C) void;
extern fn TIM1_CC_Handler() callconv(.C) void;
extern fn TIM2_IRQHandler() callconv(.C) void; // <--- IRQ #28

fn Default_Handler() callconv(.C) void {
    while (true) {}
}

pub fn panic(msg: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @branchHint(.cold);
    _ = msg;
    while (true) {}
}

export fn Reset_Handler() callconv(.C) void {
    // Copy .data from flash to RAM
    var src: [*]u32 = @ptrCast(@as(*u32, &_sidata));
    var dst: [*]u32 = @ptrCast(@as(*u32, &_sdata));
    while (@intFromPtr(dst) < @intFromPtr(&_edata)) : (dst += 1) {
        dst[0] = src[0];
        src += 1;
    }

    // Zero .bss
    dst = @ptrCast(@as(*u32, &__bss_start__));
    while (@intFromPtr(dst) < @intFromPtr(&__bss_end__)) : (dst += 1) {
        dst[0] = 0;
    }

    // Enable global interrupts
    asm volatile ("cpsie i");

    main._start();

    while (true) {}
}

export var vector_table linksection(".isr_vector") = [_]?*const fn () callconv(.C) void{
    // Initial stack pointer (provided by linker script)
    @as(*const fn () callconv(.C) void, @ptrCast(&_estack)),
    Reset_Handler,
    Default_Handler, //NMI_Handler,
    Default_Handler, //HardFault_Handler,
    Default_Handler, //MemManage_Handler,
    Default_Handler, //BusFault_Handler,
    Default_Handler, //UsageFault_Handler,
    null,        null, null, null, // reserved
    SVC_Handler,
    Default_Handler, //DebugMon_Handler,
    null, // reserved
    Default_Handler, //PendSV_Handler,
    SysTick_Handler,

    // External interrupts
    Default_Handler, //WWDG_Handler,
    Default_Handler, //PVD_Handler,
    Default_Handler, //TAMPER_Handler,
    Default_Handler, //RTC_Handler,
    Default_Handler, //FLASH_Handler,
    Default_Handler, //RCC_Handler,
    Default_Handler, //EXTI0_Handler,
    Default_Handler, //EXTI1_Handler,
    Default_Handler, //EXTI2_Handler,
    Default_Handler, //EXTI3_Handler,
    Default_Handler, //EXTI4_Handler,
    Default_Handler, //DMA1_Channel1_Handler,
    Default_Handler, //DMA1_Channel2_Handler,
    Default_Handler, //DMA1_Channel3_Handler,
    Default_Handler, //DMA1_Channel4_Handler,
    Default_Handler, //DMA1_Channel5_Handler,
    Default_Handler, //DMA1_Channel6_Handler,
    Default_Handler, //DMA1_Channel7_Handler,
    Default_Handler, //ADC1_2_Handler,
    Default_Handler, //TIM1_BRK_Handler,
    Default_Handler, //TIM1_UP_Handler,
    Default_Handler, //TIM1_TRG_COM_Handler,
    Default_Handler, //TIM1_CC_Handler,
    Default_Handler, //TIM2_IRQHandler, // <--- IRQ #28
};
