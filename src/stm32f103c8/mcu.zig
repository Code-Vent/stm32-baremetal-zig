pub const core = @import("core/core.zig");

pub const peripherals = struct {
    pub const gpio = @import("peripherals/gpio.zig");
    pub const afio = @import("peripherals/afio.zig").init;
    pub const uart = @import("peripherals/uart.zig");
    pub const timers = @import("peripherals/timers.zig");
};

pub const drivers = struct {
    pub const actuators = @import("drivers/actuators.zig");
    pub const sensors = @import("drivers/sensors.zig");
    pub const serial = @import("drivers/serial.zig");
};

pub fn name() []const u8 {
    return "STM32F103";
}
