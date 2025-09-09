const mcu = @import("mcu");

const gpio = mcu.peripherals.gpio;
const afio = mcu.peripherals.afio;
const Dimmer = mcu.drivers.actuators.Dimmer;

var dimmer: ?Dimmer = null;
const pin: afio.Pin = .{ .num = 7, .port = .A };

pub fn init() void {
    dimmer = Dimmer.init(.TIM3, .CH2, .NO_REMAP);
}

pub fn run() void {
    var percent: i32 = 0;
    var step: i32 = 1;
    while (true) {
        dimmer.?.set_brightness(percent);
        mcu.core.delay_ms(200);
        percent += step;
        if (percent == 0 or percent == 100) {
            step *= -1;
        }
    }
}
