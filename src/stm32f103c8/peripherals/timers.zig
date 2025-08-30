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

    const cr1 = timer_reg(timer, 0x00);
    const psc = timer_reg(timer, 0x28);
    const arr = timer_reg(timer, 0x2C);
    const rcr = if (timer == .TIM1) timer_reg(timer, 0x10) else null;

    // Disable the counter
    cr1.* = 0;

    // Set prescaler
    psc.* = @as(u32, timer.prescaler);

    // Set auto-reload value
    arr.* = @as(u32, timer.auto_reload);

    // Set repetition counter if applicable
    if (rcr) |rcr_| {
        rcr_.* = @as(u32, timer.repetition_counter);
    }

    // Set clock division and counter mode
    cr1.* = (@as(u32, timer.clock_division) << 8) | @as(u32, timer.counter_mode);

    // Enable the counter
    cr1.* |= 1;
}

pub fn stop(timer: TimerOptions) void {
    const cr1 = timer_reg(timer, 0x00);
    cr1.* &= ~1; // Disable the counter
}

pub fn reset(timer: TimerOptions) void {
    const egr = timer_reg(timer, 0x14);
    egr.* |= 1; // Generate an update event to reset the counter
}

pub fn get_counter(timer: TimerOptions) u32 {
    const cnt = timer_reg(timer, 0x24);
    return cnt.*;
}

pub fn set_counter(timer: TimerOptions, value: u32) void {
    const cnt = timer_reg(timer, 0x24);
    cnt.* = value;
}

//PMW
pub fn init_pwm(timer: TimerOptions, channel: u8) void {
    const ccmr = switch (channel) {
        1 => timer_reg(timer, 0x18),
        2 => timer_reg(timer, 0x1C),
        3 => timer_reg(timer, 0x20),
        4 => timer_reg(timer, 0x24),
        else => return,
    };
    const ccer = timer_reg(timer, 0x20);
    // Set PWM mode 1 and enable output
    ccmr.* |= (0b110 << ((channel - 1) * 8)) | (1 << ((channel - 1) * 8 + 3));
    ccer.* |= (1 << ((channel - 1) * 4));
}

pub fn set_pwm_duty(timer: TimerOptions, channel: u8, duty: u16) void {
    const ccr = switch (channel) {
        1 => timer_reg(timer, 0x34),
        2 => timer_reg(timer, 0x38),
        3 => timer_reg(timer, 0x3C),
        4 => timer_reg(timer, 0x40),
        else => return,
    };
    ccr.* = @as(u32, duty);
}

pub fn enable_pmw_outputs(timer: TimerOptions) void {
    if (timer == .TIM1) {
        const bdtr = timer_reg(timer, 0x44);
        bdtr.* |= 1 << 15; // MOE: Main Output Enable
    }
}

pub fn disable_pwm_outputs(timer: TimerOptions) void {
    if (timer == .TIM1) {
        const bdtr = timer_reg(timer, 0x44);
        bdtr.* &= ~(1 << 15); // MOE: Main Output Disable
    }
}

pub fn enable_interrupt(timer: TimerOptions, update: bool) void {
    const dier = timer_reg(timer, 0x0C);
    if (update) {
        dier.* |= 1; // Enable update interrupt
    }
}

pub fn disable_interrupt(timer: TimerOptions, update: bool) void {
    const dier = timer_reg(timer, 0x0C);
    if (update) {
        dier.* &= ~1; // Disable update interrupt
    }
}

pub const Edge = enum {
    Rising,
    Falling,
    Both,
};

//Input capture
pub fn init_input_capture(timer: TimerOptions, channel: u8, edge: Edge) void {
    const ccmr = switch (channel) {
        1 => timer_reg(timer, 0x18),
        2 => timer_reg(timer, 0x1C),
        3 => timer_reg(timer, 0x20),
        4 => timer_reg(timer, 0x24),
        else => return,
    };
    const ccer = timer_reg(timer, 0x20);
    // Set input capture mode and edge detection
    ccmr.* |= (1 << ((channel - 1) * 8)); // CCxS: Capture/Compare x Selection
    switch (edge) {
        .Rising => ccer.* &= ~(1 << ((channel - 1) * 4 + 1)), // CCxP: Capture/Compare x Polarity
        .Falling => ccer.* |= (1 << ((channel - 1) * 4 + 1)),
        .Both => {
            // Additional configuration needed for both edges
            //ccer.* |= (1 << ((channel - 1) * 4 + 1));
            // STM32 timers do not natively support both edge capture; this
            // would typically require additional logic in the interrupt handler.
        },
    }
    ccer.* |= (1 << ((channel - 1) * 4)); // CCxE: Capture/Compare x Enable
}

pub fn get_input_capture(timer: TimerOptions, channel: u8) u32 {
    const ccr = switch (channel) {
        1 => timer_reg(timer, 0x34),
        2 => timer_reg(timer, 0x38),
        3 => timer_reg(timer, 0x3C),
        4 => timer_reg(timer, 0x40),
        else => return 0,
    };
    return ccr.*;
}
