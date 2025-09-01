const mcu = @import("mcu");
//const startup = @import("startup.zig");

pub export fn _start() void {
    const gpio = mcu.peripherals.gpio;
    mcu.core.start(64);
    const led = mcu.drivers.blinky.init(.{
        .port = gpio.Port.C,
        .pin = 13,
        .on_time_Ms = 500,
        .off_time_Ms = 500,
    });
    while (true) {
        mcu.drivers.blinky.blink(led, 10);
    }
}
