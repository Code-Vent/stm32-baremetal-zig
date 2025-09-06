const mcu = @import("mcu");
const blink = @import("examples/blink.zig");

pub export fn entry() void {
    mcu.core.start(16);
    const led = blink.get_built_in_led();

    mcu.peripherals.timers.config_counter(.{ .timer = .TIM2, .cfg = .{
        .auto_reload = 499,
        .prescaler = 15999,
        .counter_mode = .Up,
        .clock_division = 0,
        .repetition_counter = 0,
    } });
    mcu.peripherals.timers.start_counter(.TIM2);

    while (true) {
        blink.toggle(led);
        mcu.peripherals.timers.event_wait(.TIM2, .Update);
    }
}
