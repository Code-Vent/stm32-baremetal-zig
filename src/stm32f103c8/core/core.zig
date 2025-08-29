const Organs = struct {
    pub const clock = @import("clock.zig");
    pub const handlers = @import("handlers.zig");
    pub const sys_timer = @import("sys_timer.zig");
};

const Vitals = struct {
    pub var clock_freq: u32 = 8_000_000;
    pub const systick_ptr: *volatile u32 = &Organs.handlers.systick;
};

pub fn start(comptime freq_in_MHZ: u8) void {
    const Config = Organs.clock.Config;
    Vitals.clock_freq = Organs.clock.start(Config.init(freq_in_MHZ));
}

pub fn enable_peripheral(clock: Organs.clock.ClockSrc, mask: u32) void {
    Organs.clock.enable(clock, mask);
}

pub fn delay_ms(time: u32) void {
    Organs.sys_timer.init_delay(Vitals.clock_freq, 1000);
    delay(time);
}

pub fn delay_us(time: u32) void {
    Organs.sys_timer.init_delay(Vitals.clock_freq, 1000_000);
    delay(time);
}

inline fn delay(time: u32) void {
    const start_time: u32 = Vitals.systick_ptr.*;
    while ((Vitals.systick_ptr.* - start_time) < time) {}
}
