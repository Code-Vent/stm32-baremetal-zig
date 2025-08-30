const core = @import("../core/core.zig");
const timN = @import("timer_backend.zig");

pub const Config = timN.Config;
pub const Timer = timN.Timer;

pub fn start_timer(comptime timer: timN.Timer) timN.TimerOptions {
    timN.start(timer, timer);
    return timer;
}

pub fn init() void {
    const tim = Timer{ .TIM1 = Config{} };
    start_timer(tim);
}
