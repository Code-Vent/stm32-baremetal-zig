const mcu = @import("mcu");

const gpio = mcu.peripherals.gpio;

const LED = mcu.drivers.actuators.LED;

var _led: ?LED = null;

pub fn get_built_in_led() LED {
    if (_led == null) {
        _led = LED.init(
            gpio.Port.C,
            13,
        );
    }
    return _led.?;
}

pub fn run(led: LED, on_time_Ms: u32, off_time_Ms: u32) void {
    while (true) {
        gpio.write_pin(led.pin, false);
        mcu.core.delay_ms(off_time_Ms);
        gpio.write_pin(led.pin, true);
        mcu.core.delay_ms(on_time_Ms);
    }
}

pub fn toggle(led: LED) void {
    gpio.toggle_pin(led.pin);
}
