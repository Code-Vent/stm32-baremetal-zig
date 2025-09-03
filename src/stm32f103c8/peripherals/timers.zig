const std = @import("std");
const core = @import("../core/core.zig");
const afio = @import("afio.zig");

pub const CounterMode = enum(u3) {
    Up = 0b00,
    Down = 0b01,
    CenterAligned1 = 0b10,
    CenterAligned2 = 0b11,
    CenterAligned3 = 0b100,
};

pub const Config = struct {
    prescaler: u16,
    auto_reload: u16,
    repetition_counter: u8,
    clock_division: u2,
    counter_mode: CounterMode,
};

pub const Channel = enum { CH1, CH2, CH3, CH4 };

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

fn enable(comptime tim: TimerOptions) void {
    if (tim == .TIM1) {
        core.enable_peripheral(.APB2, 1 << @intFromEnum(tim));
    } else {
        core.enable_peripheral(.APB1, 1 << @intFromEnum(tim));
    }
}

pub fn start(comptime arg: struct {
    timer: TimerOptions,
    cfg: Config,
}) void {
    enable(arg.timer);
    const cr1 = timer_reg(arg.timer, 0x00);
    const psc = timer_reg(arg.timer, 0x28);
    const arr = timer_reg(arg.timer, 0x2C);
    const rcr = if (arg.timer == .TIM1) timer_reg(arg.timer, 0x10) else null;

    // Disable the counter
    cr1.* = 0;

    // Set prescaler
    psc.* = @as(u32, arg.cfg.prescaler);

    // Set auto-reload value
    arr.* = @as(u32, arg.cfg.auto_reload);

    // Set repetition counter if applicable
    if (rcr) |rcr_| {
        rcr_.* = @as(u32, arg.cfg.repetition_counter);
    }

    // Set clock division and counter mode
    cr1.* = (@as(u32, arg.cfg.clock_division) << 8) | @as(u32, @intFromEnum(arg.cfg.counter_mode));

    // Enable the counter
    cr1.* |= 1;
}

pub fn stop(comptime timer: TimerOptions) void {
    const cr1 = timer_reg(timer, 0x00);
    cr1.* &= ~1; // Disable the counter
}

pub fn reset(comptime timer: TimerOptions) void {
    const egr = timer_reg(timer, 0x14);
    egr.* |= 1; // Generate an update event to reset the counter
}

pub fn wait_for_event(comptime timer: TimerOptions) void {
    const sr = timer_reg(timer, 0x10);
    while (sr.* & @as(u32, 1 << 0) == 0) {} // Wait for update event
    sr.* &= ~@as(u32, 1 << 0); // Clear update flag
}

pub fn get_counter(comptime timer: TimerOptions) u32 {
    const cnt = timer_reg(timer, 0x24);
    return cnt.*;
}

pub fn set_counter(comptime timer: TimerOptions, value: u32) void {
    const cnt = timer_reg(timer, 0x24);
    cnt.* = value;
}

//PMW
pub fn init_pwm(comptime timer: TimerOptions, channel: u8) void {
    enable(timer);
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

    // Enable the counter
    const cr1 = timer_reg(timer, 0x00);
    cr1.* |= 1;
}

pub fn set_pwm_duty(comptime timer: TimerOptions, channel: u8, duty: u16) void {
    const ccr = switch (channel) {
        1 => timer_reg(timer, 0x34),
        2 => timer_reg(timer, 0x38),
        3 => timer_reg(timer, 0x3C),
        4 => timer_reg(timer, 0x40),
        else => return,
    };
    ccr.* = @as(u32, duty);
}

pub fn enable_pmw_outputs(comptime timer: TimerOptions) void {
    if (timer == .TIM1) {
        const bdtr = timer_reg(timer, 0x44);
        bdtr.* |= 1 << 15; // MOE: Main Output Enable
    }
}

pub fn disable_pwm_outputs(comptime timer: TimerOptions) void {
    if (timer == .TIM1) {
        const bdtr = timer_reg(timer, 0x44);
        bdtr.* &= ~(1 << 15); // MOE: Main Output Disable
    }
}

pub fn enable_interrupt(comptime timer: TimerOptions, update: bool) void {
    const dier = timer_reg(timer, 0x0C);
    if (update) {
        dier.* |= 1; // Enable update interrupt
    }
}

pub fn disable_interrupt(comptime timer: TimerOptions, update: bool) void {
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
pub fn init_input_capture(comptime timer: TimerOptions, channel: u8, edge: Edge) void {
    enable(timer);
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
    // Enable the counter
    const cr1 = timer_reg(timer, 0x00);
    cr1.* |= 1;
}

pub fn get_input_capture(comptime timer: TimerOptions, channel: u8) u32 {
    const ccr = switch (channel) {
        1 => timer_reg(timer, 0x34),
        2 => timer_reg(timer, 0x38),
        3 => timer_reg(timer, 0x3C),
        4 => timer_reg(timer, 0x40),
        else => return 0,
    };
    return ccr.*;
}

/// Define PWM-capable pins per timer
const timer_map = .{
    .TIM1 = .{
        .CH1 = .{.{ .port = .A, .num = 8 }},
        .CH2 = .{.{ .port = .A, .num = 9 }},
        .CH3 = .{.{ .port = .A, .num = 10 }},
        .CH4 = .{.{ .port = .A, .num = 11 }},
    },
    .TIM2 = .{
        .CH1 = .{.{ .port = .A, .num = 0 }},
        .CH2 = .{.{ .port = .A, .num = 1 }},
        .CH3 = .{.{ .port = .A, .num = 2 }},
        .CH4 = .{.{ .port = .A, .num = 3 }},
    },
    .TIM3 = .{
        .CH1 = .{.{ .port = .A, .num = 6 }},
        .CH2 = .{.{ .port = .A, .num = 7 }},
        .CH3 = .{.{ .port = .B, .num = 0 }},
        .CH4 = .{.{ .port = .B, .num = 1 }},
    },
    .TIM4 = .{
        .CH1 = .{.{ .port = .B, .num = 6 }},
        .CH2 = .{.{ .port = .B, .num = 7 }},
        .CH3 = .{.{ .port = .B, .num = 8 }},
        .CH4 = .{.{ .port = .B, .num = 9 }},
    },
};

const timer_partial_remap = .{
    .TIM2 = .{
        .CH1 = .{.{ .port = .A, .num = 15 }},
        .CH2 = .{.{ .port = .B, .num = 3 }},
        .CH3 = .{.{ .port = .A, .num = 2 }},
        .CH4 = .{.{ .port = .A, .num = 3 }},
    },
    .TIM3 = .{
        .CH1 = .{.{ .port = .B, .num = 4 }},
        .CH2 = .{.{ .port = .B, .num = 5 }},
        .CH3 = .{.{ .port = .B, .num = 0 }},
        .CH4 = .{.{ .port = .B, .num = 1 }},
    },
    .TIM4 = .{
        .CH1 = .{.{ .port = .B, .num = 6 }},
        .CH2 = .{.{ .port = .B, .num = 7 }},
        .CH3 = .{.{ .port = .B, .num = 8 }},
        .CH4 = .{.{ .port = .B, .num = 9 }},
    },
};

const timer_full_remap = .{
    .TIM2 = .{
        .CH1 = .{.{ .port = .A, .num = 15 }},
        .CH2 = .{.{ .port = .B, .num = 3 }},
        .CH3 = .{.{ .port = .B, .num = 10 }},
        .CH4 = .{.{ .port = .B, .num = 11 }},
    },
    .TIM3 = .{
        .CH1 = .{.{ .port = .C, .num = 6 }},
        .CH2 = .{.{ .port = .C, .num = 7 }},
        .CH3 = .{.{ .port = .C, .num = 8 }},
        .CH4 = .{.{ .port = .C, .num = 9 }},
    },
    .TIM4 = .{
        .CH1 = .{.{ .port = .D, .num = 12 }},
        .CH2 = .{.{ .port = .D, .num = 13 }},
        .CH3 = .{.{ .port = .D, .num = 14 }},
        .CH4 = .{.{ .port = .D, .num = 15 }},
    },
};

pub fn assertTimerCompatible(comptime p: afio.Pin, comptime t: TimerOptions, comptime c: Channel) void {
    const ch_pins = @field(@field(timer_map, @tagName(t)), @tagName(c));

    inline for (ch_pins) |valid_pin| {
        if (valid_pin.port == p.port and valid_pin.num == p.num) return;
    }

    @compileError("Pin " ++ @tagName(p.port) ++ std.fmt.comptimePrint("{d}", .{p.num}) ++
        " is not valid for " ++ @tagName(t) ++ " " ++ @tagName(c));
}

pub fn assertTimerPartialRemapCompatible(comptime p: afio.Pin, comptime t: TimerOptions, comptime c: Channel) void {
    const ch_pins = @field(@field(timer_partial_remap, @tagName(t)), @tagName(c));

    inline for (ch_pins) |valid_pin| {
        if (valid_pin.port == p.port and valid_pin.num == p.num) return;
    }

    @compileError("Pin " ++ @tagName(p.port) ++ std.fmt.comptimePrint("{d}", .{p.num}) ++
        " is not valid for " ++ @tagName(t) ++ " " ++ @tagName(c));
}

pub fn assertTimerFullRemapCompatible(comptime p: afio.Pin, comptime t: TimerOptions, comptime c: Channel) void {
    const ch_pins = @field(@field(timer_full_remap, @tagName(t)), @tagName(c));

    inline for (ch_pins) |valid_pin| {
        if (valid_pin.port == p.port and valid_pin.num == p.num) return;
    }

    @compileError("Pin " ++ @tagName(p.port) ++ std.fmt.comptimePrint("{d}", .{p.num}) ++
        " is not valid for " ++ @tagName(t) ++ " " ++ @tagName(c));
}
