const std = @import("std");
const core = @import("../core/core.zig");
const afio = @import("afio.zig");

pub const Channel = enum(u8) { CH1 = 1, CH2, CH3, CH4 };

const EnableMasks = enum(u32) {
    TIM1 = (1 << 11),
    TIM2 = (1 << 0),
    TIM3 = (1 << 1),
    TIM4 = (1 << 2),
    TIM6 = (1 << 4),
    TIM7 = (1 << 5),
};

pub const Timer = enum {
    TIM1,
    TIM2,
    TIM3,
    TIM4,
    TIM6,
    TIM7,
};

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

pub const EventMasks = enum(u32) {
    Update = 1 << 0,
    CC1 = 1 << 1,
    CC2 = 1 << 2,
    CC3 = 1 << 3,
    CC4 = 1 << 4,
    Trigger = 1 << 6,
    Break = 1 << 7,
};

pub const Edge = enum {
    Rising,
    Falling,
};

pub const CapConfig = struct {
    ch: Channel,
    edge: Edge,
};

pub const CmpConfig = struct {
    ch: Channel,
    cmp_out: enum(u3) { //BITS 6:4
        FROZEN,
        ACTIVE_HIGH,
        ACTIVE_LOW,
        TOGGLE,
        ALWAYS_LOW,
        ALWAYS_HIGH,
        PWM1,
        PWM2,
    },
    preload: enum { DISABLE, ENABLE },
    fast: enum { DISABLE, ENABLE },
    active_state: enum { HIGH, LOW },
};

pub const CaptureCompareMasks = struct {
    egr_mask: u16,
    ccmr_mask: u16,
    ccer_mask: u16,

    pub fn initCapture(comptime cfg: CapConfig) CaptureCompareMasks {
        return .{
            .egr_mask = 1 << @intFromEnum(cfg.ch),
            .ccmr_mask = 0x0001 << (((@intFromEnum(cfg.ch) % 2) - 1) * 8),
            .ccer_mask = ((@intFromEnum(cfg.edge) << 1) | (1 << 0)) << ((@intFromEnum(cfg.ch) - 1) * 4),
        };
    }

    pub fn initCompare(comptime cfg: CmpConfig) CaptureCompareMasks {
        return .{
            .egr_mask = 1 << @intFromEnum(cfg.ch),
            .ccmr_mask = (@intFromEnum(cfg.cmp_out) << 4 | @intFromEnum(cfg.preload) << 3 | @intFromEnum(cfg.fast) << 2) << (((@intFromEnum(cfg.ch) % 2) - 1) * 8), // configure compare mode as needed
            .ccer_mask = ((@intFromEnum(cfg.active_state) << 1) | (1 << 0)) << ((@intFromEnum(cfg.ch) - 1) * 4),
        };
    }
};

fn timer_reg(timer: Timer, offset: u32) *volatile u32 {
    return switch (timer) {
        .TIM1 => @ptrFromInt(0x4001_2C00 + offset),
        .TIM2 => @ptrFromInt(0x4000_0000 + offset),
        .TIM3 => @ptrFromInt(0x4000_0400 + offset),
        .TIM4 => @ptrFromInt(0x4000_0800 + offset),
        .TIM6 => @ptrFromInt(0x4000_1000 + offset),
        .TIM7 => @ptrFromInt(0x4000_1400 + offset),
    };
}

fn enable(timer: Timer) void {
    switch (timer) {
        .TIM1 => core.enable_peripheral(.APB2, @intFromEnum(EnableMasks.TIM1)),
        .TIM2 => core.enable_peripheral(.APB1, @intFromEnum(EnableMasks.TIM2)),
        .TIM3 => core.enable_peripheral(.APB1, @intFromEnum(EnableMasks.TIM3)),
        .TIM4 => core.enable_peripheral(.APB1, @intFromEnum(EnableMasks.TIM4)),
        .TIM6 => core.enable_peripheral(.APB1, @intFromEnum(EnableMasks.TIM6)),
        .TIM7 => core.enable_peripheral(.APB1, @intFromEnum(EnableMasks.TIM7)),
    }
}

pub fn config_counter(arg: struct {
    timer: Timer,
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
}

pub fn start_counter(timer: Timer) void {
    const cr1 = timer_reg(timer, 0x00);
    const egr = timer_reg(timer, 0x14);
    egr.* |= @as(u32, @intFromEnum(EventMasks.Update)); // Generate an update event to load the prescaler value
    // Enable the counter
    cr1.* |= 1;
}

pub fn stop(timer: Timer) void {
    const cr1 = timer_reg(timer, 0x00);
    cr1.* &= ~1; // Disable the counter
}

pub fn reset(timer: Timer) void {
    const egr = timer_reg(timer, 0x14);
    egr.* |= 1; // Generate an update event to reset the counter
}

pub fn event_wait(timer: Timer, e: EventMasks) void {
    const sr = timer_reg(timer, 0x10);
    const mask: u32 = @as(u32, @intFromEnum(e));
    while (sr.* & mask == 0) {} // Wait for event
    sr.* &= ~mask; // Clear event flag
}

pub fn get_counter(timer: Timer) u32 {
    const cnt = timer_reg(timer, 0x24);
    return cnt.*;
}

pub fn set_counter(timer: Timer, value: u32) void {
    const cnt = timer_reg(timer, 0x24);
    cnt.* = value;
}

pub fn set_pwm_duty(timer: Timer, channel: u8, duty: u16) void {
    const ccr = switch (channel) {
        1 => timer_reg(timer, 0x34),
        2 => timer_reg(timer, 0x38),
        3 => timer_reg(timer, 0x3C),
        4 => timer_reg(timer, 0x40),
        else => return,
    };
    ccr.* = @as(u32, duty);
}

pub fn enable_pmw_outputs(timer: Timer) void {
    if (timer == .TIM1) {
        const bdtr = timer_reg(timer, 0x44);
        bdtr.* |= 1 << 15; // MOE: Main Output Enable
    }
}

pub fn disable_pwm_outputs(timer: Timer) void {
    if (timer == .TIM1) {
        const bdtr = timer_reg(timer, 0x44);
        bdtr.* &= ~(1 << 15); // MOE: Main Output Disable
    }
}

pub fn enable_interrupt(timer: Timer, update: bool) void {
    const dier = timer_reg(timer, 0x0C);
    if (update) {
        dier.* |= 1; // Enable update interrupt
    }
}

pub fn disable_interrupt(timer: Timer, update: bool) void {
    const dier = timer_reg(timer, 0x0C);
    if (update) {
        dier.* &= ~1; // Disable update interrupt
    }
}

//Input capture
pub fn start_capture_compare(timer: Timer, c: Channel, masks: CaptureCompareMasks, ccr: ?u16) void {
    config_counter(.{
        .timer = timer,
        .cfg = .{
            .prescaler = (core.get_apb1_clock_freq() / 1_000_000) - 1,
            .auto_reload = 0xFFFF,
            .repetition_counter = 0,
            .clock_division = 0,
            .counter_mode = .Up,
        },
    });
    const cr1 = timer_reg(timer, 0x00);
    const egr = timer_reg(timer, 0x14);
    const ccmr1 = timer_reg(timer, 0x18);
    const ccmr2 = timer_reg(timer, 0x1C);
    const ccmr = if (@as(u32, @intFromEnum(c)) <= 2) ccmr1 else ccmr2;
    const ccer = timer_reg(timer, 0x20);

    egr.* |= masks.egr_mask; // Generate an update event to load the prescaler value
    ccmr.* |= masks.ccmr_mask; // Configure as input, no prescaler
    ccer.* |= masks.ccer_mask; // Enable capture on the channel
    if (ccr) |ccr_| {
        const ccr_reg = switch (c) {
            .CH1 => timer_reg(timer, 0x34),
            .CH2 => timer_reg(timer, 0x38),
            .CH3 => timer_reg(timer, 0x3C),
            .CH4 => timer_reg(timer, 0x40),
        };
        ccr_reg.* = @as(u32, ccr_);
    }
    cr1.* |= (1 << 7); // Enable auto-reload preload
    //Start timer counter here
    start_counter(timer);
}

pub fn get_input_capture(comptime timer: Timer, channel: u8) u32 {
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

pub fn assertTimerCompatible(comptime p: afio.Pin, comptime t: Timer, comptime c: Channel) void {
    const ch_pins = @field(@field(timer_map, @tagName(t)), @tagName(c));

    inline for (ch_pins) |valid_pin| {
        if (valid_pin.port == p.port and valid_pin.num == p.num) return;
    }

    @compileError("Pin " ++ @tagName(p.port) ++ std.fmt.comptimePrint("{d}", .{p.num}) ++
        " is not valid for " ++ @tagName(t) ++ " " ++ @tagName(c));
}

pub fn assertTimerPartialRemapCompatible(comptime p: afio.Pin, comptime t: Timer, comptime c: Channel) void {
    const ch_pins = @field(@field(timer_partial_remap, @tagName(t)), @tagName(c));

    inline for (ch_pins) |valid_pin| {
        if (valid_pin.port == p.port and valid_pin.num == p.num) return;
    }

    @compileError("Pin " ++ @tagName(p.port) ++ std.fmt.comptimePrint("{d}", .{p.num}) ++
        " is not valid for " ++ @tagName(t) ++ " " ++ @tagName(c));
}

pub fn assertTimerFullRemapCompatible(comptime p: afio.Pin, comptime t: Timer, comptime c: Channel) void {
    const ch_pins = @field(@field(timer_full_remap, @tagName(t)), @tagName(c));

    inline for (ch_pins) |valid_pin| {
        if (valid_pin.port == p.port and valid_pin.num == p.num) return;
    }

    @compileError("Pin " ++ @tagName(p.port) ++ std.fmt.comptimePrint("{d}", .{p.num}) ++
        " is not valid for " ++ @tagName(t) ++ " " ++ @tagName(c));
}
