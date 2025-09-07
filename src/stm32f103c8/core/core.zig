const Units = struct {
    pub const clock = @import("clock.zig");
    pub const handlers = @import("handlers.zig");
    pub const sys_timer = @import("sys_timer.zig");
};

const Env = struct {
    pub var sys_clock_freq: u32 = 8_000_000;
    pub var apb1_clock_freq: u32 = 8_000_000;
    pub const systick_ptr: *volatile u32 = &Units.handlers.systick;
};

pub fn start(comptime freq_in_MHZ: u8) void {
    const Config = Units.clock.Config;
    Units.handlers.init();
    const freqs = Units.clock.start(Config.init(freq_in_MHZ));
    Env.sys_clock_freq = freqs.sys_clock_freq;
    Env.apb1_clock_freq = freqs.apb1_freq;
}

pub fn enable_peripheral(clock: Units.clock.ClockSrc, bit: u5) void {
    Units.clock.enable(clock, bit);
}

pub fn delay_ms(time: u32) void {
    Units.sys_timer.init_delay(Env.sys_clock_freq, 1000);
    delay(time);
}

pub fn delay_us(time: u32) void {
    Units.sys_timer.init_delay(Env.sys_clock_freq, 1000_000);
    delay(time);
}

inline fn delay(time: u32) void {
    const start_time: u32 = Env.systick_ptr.*;
    while ((Env.systick_ptr.* - start_time) < time) {}
}

pub fn get_clock_freq() u32 {
    return Env.sys_clock_freq;
}

pub fn get_apb1_clock_freq() u32 {
    return Env.apb1_clock_freq;
}
