const mcu = @import("mcu");

pub export fn entry() void {
    const gpio = mcu.peripherals.gpio;
    mcu.core.start(16);
    const led = mcu.drivers.blinky.init(.{
        .port = gpio.Port.C,
        .pin = 13,
        .on_time_Ms = 500,
        .off_time_Ms = 500,
    });

    mcu.peripherals.timers.start(.{ .timer = .TIM2, .cfg = .{
        .auto_reload = 499,
        .prescaler = 15999,
        .counter_mode = .Up,
        .clock_division = 0,
        .repetition_counter = 0,
    } });

    while (true) {
        mcu.drivers.blinky.led_toggle(led);
        mcu.peripherals.timers.wait_for_event(.TIM2);
    }
}
