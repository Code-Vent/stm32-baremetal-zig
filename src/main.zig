const mcu = @import("mcu");

export fn _start() noreturn {
    const gpio = mcu.peripherals.gpio;
    mcu.core.start(64);
    const led = mcu.drivers.blinky.init(.{
        .port = gpio.Port.C,
        .pin = 13,
        .on_time_Ms = 500,
        .off_time_Ms = 500,
    });
    mcu.drivers.blinky.blink_noreturn(led);
}
