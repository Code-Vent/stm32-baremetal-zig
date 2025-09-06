const gpio = @import("../peripherals/gpio.zig");
const core = @import("../core/core.zig");

pub const LED = struct {
    pin: gpio.Pin,

    pub fn init(port: gpio.Port, comptime pin: u8) LED {
        const cfgs = [_]gpio.Config{
            gpio.Config.init(pin, port, .Output50MHz, .Floating_OR_GpioOD, .NONE),
        };
        const ports = [_]gpio.Port{
            port,
        };
        gpio.config_gpio(&ports, &cfgs);

        return LED{ .pin = gpio.Pin{
            .port = port,
            .mask = (1 << pin),
        } };
    }
};
