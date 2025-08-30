const core = @import("../core/core.zig");

pub const Config = struct {
    prescaler: u16,
    auto_reload: u16,
    repetition_counter: u8,
    clock_division: u2,
    counter_mode: CounterMode,
};

pub const CounterMode = enum(u3) {
    Up = 0b00,
    Down = 0b01,
    CenterAligned1 = 0b10,
    CenterAligned2 = 0b11,
    CenterAligned3 = 0b100,
};

pub const TimerOptions = enum(u32) {
    //APB2 enable bit for tim1
    TIM1 = 11,
    //APB1 enable bit for tim2
    TIM2 = 0,
    //APB1 enable bit for tim3
    TIM3 = 1,
    //APB1 enable bit for tim4
    TIM4 = 2,
    //APB1 enable bit for tim6
    TIM6 = 4,
    //APB1 enable bit for tim7
    TIM7 = 5,
};

pub const Timer = union(TimerOptions) {
    TIM1: Config,
    TIM2: Config,
    TIM3: Config,
    TIM4: Config,
    TIM6: Config,
    TIM7: Config,
};

fn timer_reg(timer: TimerOptions, offset: u32) *volatile u32 {
    return switch (timer) {
        .TIM1 => @ptrFromInt(0x4001_2C00 + offset),
        .TIM2 => @ptrFromInt(0x4000_0000 + offset),
        .TIM3 => @ptrFromInt(0x4000_0400 + offset),
        .TIM4 => @ptrFromInt(0x4000_0800 + offset),
        .TIM6 => @ptrFromInt(0x4000_1000 + offset),
        .TIM7 => @ptrFromInt(0x4000_1400 + offset),
    };
}

pub fn start(timer: Config) void {
    if (timer == .TIM1) {
        core.enable_peripheral(.APB2, 1 << @intFromEnum(timer));
    } else {
        core.enable_peripheral(.APB1, 1 << @intFromEnum(timer));
    }

    const reg_cr1 = timer_reg(timer, 0x00);
    const reg_psc = timer_reg(timer, 0x28);
    const reg_arr = timer_reg(timer, 0x2C);
    const reg_rcr = if (timer == .TIM1) timer_reg(timer, 0x10) else null;

    // Disable the counter
    reg_cr1.* = 0;

    // Set prescaler
    reg_psc.* = @as(u32, timer.prescaler);

    // Set auto-reload value
    reg_arr.* = @as(u32, timer.auto_reload);

    // Set repetition counter if applicable
    if (reg_rcr) |rcr| {
        rcr.* = @as(u32, timer.repetition_counter);
    }

    // Set clock division and counter mode
    reg_cr1.* = (@as(u32, timer.clock_division) << 8) | @as(u32, timer.counter_mode);

    // Enable the counter
    reg_cr1.* |= 1;
}
