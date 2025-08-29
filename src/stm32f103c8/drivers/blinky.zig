const gpio = @import("../peripherals/gpio.zig");
const core = @import("../core/core.zig");

pub const LED = struct {
    pin: gpio.Pin,
    on_time: u32,
    off_time: u32,
};

pub fn init(comptime params: struct {
    port: gpio.Port,
    pin: u8,
    on_time_Ms: u32,
    off_time_Ms: u32,
}) LED {
    const cfgs = [_]gpio.Config{
        gpio.Config.init(params.pin, params.port, .Output50MHz, .Floating_OR_GpioOD, .NONE),
    };

    gpio.config_gpio(1, .{params.port}, &cfgs);

    return LED{
        .pin = gpio.Pin{
            .port = params.port,
            .mask = (1 << params.pin),
        },
        .on_time = params.on_time_Ms,
        .off_time = params.off_time_Ms,
    };
}

pub fn blink_noreturn(led: LED) noreturn {
    //core.
    while (true) {
        gpio.write_pin(led.pin, false);
        core.delay_ms(led.off_time);
        gpio.write_pin(led.pin, true);
        core.delay_ms(led.on_time);
    }
}
