const core = @import("../core/core.zig");
const gpio = @import("gpio.zig");
const timers = @import("timers.zig");

pub const Pin = struct {
    port: gpio.Port,
    num: u8,
};

pub const Remap = enum {
    NO_REMAP,
    PARTIAL_REMAP,
    FULL_REMAP,
};

//Write afio api and functionalities following the patterns
//of gpio.zig and timer.zig
pub fn init() void {
    core.enable_peripheral(.APB2, @as(u32, 1 << 0));
}

pub fn timer2_remap(remap: Remap) void {
    switch (remap) {
        .PARTIAL_REMAP => remap_tim2_partial(),
        .FULL_REMAP => remap_tim2_full(),
        else => {},
    }
}

pub fn timer3_remap(remap: Remap) void {
    switch (remap) {
        .PARTIAL_REMAP => remap_tim3_partial(),
        .FULL_REMAP => remap_tim3_full(),
        else => {},
    }
}

pub fn timer4_remap(remap: Remap) void {
    switch (remap) {
        .PARTIAL_REMAP => remap_tim4_partial(),
        .FULL_REMAP => remap_tim4_full(),
        else => {},
    }
}

fn afio_reg(offset: u32) *volatile u32 {
    return @ptrFromInt(0x4001_0000 + offset);
}

pub fn remap_spi1() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 0); // Set SPI1_REMAP bit
}

pub fn remap_i2c1() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 1); // Set I2C1_REMAP bit
}

pub fn remap_usart1() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 2); // Set USART1_REMAP bit
}

pub fn remap_usart2() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 3); // Set USART2_REMAP bit
}

pub fn remap_usart3_partial() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 4); // Set USART3_REMAP[1:0] to 01 (partial remap)
    mapr.* &= ~(1 << 5);
}

pub fn remap_usart3_full() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 4); // Set USART3_REMAP[1:0] to 11 (full remap)
    mapr.* |= (1 << 5);
}

fn remap_tim2_partial() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 8); // Set TIM2_REMAP[1:0] to 01 (partial remap)
    mapr.* &= ~(1 << 9);
}

fn remap_tim2_full() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 8); // Set TIM2_REMAP[1:0] to 10 (full remap)
    mapr.* |= (1 << 9);
}

fn remap_tim3_partial() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 11); // Set TIM3_REMAP[1:0] to 01 (partial remap)
    mapr.* &= ~(1 << 10);
}

fn remap_tim3_full() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 10); // Set TIM3_REMAP[1:0] to 11 (full remap)
    mapr.* |= (1 << 11);
}

fn remap_tim4_partial() void {}

fn remap_tim4_full() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 12); // Set TIM4_REMAP bit
}

pub fn remap_can() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 13); // Set CAN_REMAP bit
}

pub fn remap_pd01() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 15); // Set PD01_REMAP bit
}

pub fn remap_adc1_exttrig() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 17); // Set ADC1_ETRGINJ_REMAP bit
}

pub fn remap_adc2_exttrig() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 18); // Set ADC2_ETRGINJ_REMAP bit
}

pub fn remap_sw_jtag() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 24); // Set SWJ_CFG[2:0] to 010 (SW-DP enabled, JTAG-DP disabled)
    mapr.* &= ~((1 << 25) | (1 << 26));
}

pub fn remap_sw_jtag_no_njtrst() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 24); // Set SWJ_CFG[2:0] to 100 (SW-DP enabled, JTAG-DP disabled, NJTRST disabled)
    mapr.* |= (1 << 26);
    mapr.* &= ~(1 << 25);
}

pub fn remap_full_jtag() void {
    const mapr = afio_reg(0x04);
    mapr.* &= ~((1 << 24) | (1 << 25) | (1 << 26)); // Set SWJ_CFG[2:0] to 000 (Full SWJ (JTAG-DP + SW-DP) enabled)
}

pub fn remap_no_jtag() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 24); // Set SWJ_CFG[2:0] to 001 (JTAG-DP disabled and SW-DP enabled)
    mapr.* &= ~((1 << 25) | (1 << 26));
}

pub fn remap_eventout() void {
    const mapr = afio_reg(0x04);
    mapr.* |= (1 << 22); // Set EVENTOUT_REMAP bit
}

pub fn remap_can2() void {
    const mapr2 = afio_reg(0x1C);
    mapr2.* |= (1 << 9); // Set CAN2_REMAP bit
}

pub fn remap_fsmc_nadv() void {
    const mapr2 = afio_reg(0x1C);
    mapr2.* |= (1 << 23); // Set FSMC_NADV_REMAP bit
}

pub fn remap_eth() void {
    const mapr2 = afio_reg(0x1C);
    mapr2.* |= (1 << 28); // Set ETH_REMAP bit
}

pub fn remap_can3() void {
    const mapr2 = afio_reg(0x1C);
    mapr2.* |= (1 << 30); // Set CAN3_REMAP bit
}

pub fn reset() void {
    const mapr = afio_reg(0x04);
    mapr.* = 0x0000_0000; // Reset MAPR register to default
    const mapr2 = afio_reg(0x1C);
    mapr2.* = 0x0000_0000; // Reset MAPR2 register to default
}
