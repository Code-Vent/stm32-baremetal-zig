const gpio = @import("../peripherals/gpio.zig");
const timers = @import("../peripherals/timers.zig");
const afio = @import("../peripherals/afio.zig");

const SensorPin = struct {
    pin: afio.Pin,
    pull: gpio.Pull,
};

/// ==============================
/// DIGITAL SENSOR
/// ==============================
pub const DigitalSensor = struct {
    pin: gpio.Pin,

    pub fn init(in: SensorPin) DigitalSensor {
        const cfgs = [_]gpio.Config{
            gpio.Config.init(in.pin.num, in.pin.port, .Input, .Input_OR_AltPP, in.pull),
        };

        const ports = [_]gpio.Port{
            in.pin.port,
        };
        gpio.config_gpio(&ports, &cfgs);

        return DigitalSensor{
            .pin = gpio.Pin{
                .port = in.pin.port,
                .mask = (1 << in.pin.num),
            },
        };
    }

    pub fn read(self: DigitalSensor) bool {
        return gpio.read_pin(self.pin);
    }
};

/// Specializations (aliases for readability)
pub const Button = DigitalSensor;
pub const PIR = DigitalSensor;
pub const Hall = DigitalSensor;

/// ==============================
/// ANALOG SENSOR
/// ==============================
pub const AnalogSensor = struct {
    channel: u8, // ADC channel index

    pub fn init(channel: u8) AnalogSensor {
        return .{ .channel = channel };
    }

    pub fn read(self: *AnalogSensor) u16 {
        _ = self;
        return 0;
    }
};

/// Specializations
pub const LDR = AnalogSensor;
pub const Potentiometer = AnalogSensor;
pub const TempSensor = AnalogSensor;

/// ==============================
/// TimeIntervalSensor
/// ==============================
pub const TimeIntervalSensor = struct {
    echo: gpio.Pin,
    trig: ?gpio.Pin,
    channel: u8,
    timer: timers.TimerOptions,

    pub fn init(comptime timer: timers.TimerOptions, comptime echo: SensorPin, comptime echo_channel: timers.Channel, comptime trig: ?SensorPin, comptime trig_channel: ?timers.Channel, comptime remap: afio.Remap) TimeIntervalSensor {
        switch (remap) {
            .NO_REMAP => {
                timers.assertTimerCompatible(echo.pin, timer, echo_channel);
            },
            .PARTIAL_REMAP => {
                timers.assertTimerPartialRemapCompatible(echo.pin, timer, echo_channel);
                TimeIntervalSensor.remap_timer(timer, remap);
            },
            .FULL_REMAP => {
                timers.assertTimerFullRemapCompatible(echo.pin, timer, echo_channel);
                TimeIntervalSensor.remap_timer(timer, remap);
            },
        }

        const echo_cfg = [_]gpio.Config{
            gpio.Config.init(echo.pin.num, echo.pin.port, .Input, .Input_OR_AltPP, echo.pull),
        };
        gpio.config_gpio(1, .{echo.pin.port}, &echo_cfg);

        if (trig != null) {
            switch (remap) {
                .NO_REMAP => {
                    timers.assertTimerCompatible(trig.?.pin, timer, trig_channel);
                },
                .PARTIAL_REMAP => {
                    timers.assertTimerPartialRemapCompatible(trig.?.pin, timer, trig_channel);
                    TimeIntervalSensor.remap_timer(timer, remap);
                },
                .FULL_REMAP => {
                    timers.assertTimerFullRemapCompatible(trig.?.pin, timer, trig_channel);
                    TimeIntervalSensor.remap_timer(timer, remap);
                },
            }
            const trig_cfg = [_]gpio.Config{
                gpio.Config.init(trig.?.pin.num, trig.?.pin.port, .Output50MHz, .PushPull_OR_AltPP, trig.?.pull),
            };
            gpio.config_gpio(1, .{trig.?.pin.port}, &trig_cfg);
        }

        const echo_pin = gpio.Pin{
            .port = echo.pin.port,
            .mask = (1 << echo.pin.num),
        };

        if (trig == null) {
            return TimeIntervalSensor{
                .trig = null,
                .echo = echo_pin,
            };
        } else {
            return TimeIntervalSensor{
                .trig = gpio.Pin{
                    .port = trig.port,
                    .mask = (1 << trig.?.pin.num),
                },
                .echo = echo_pin,
            };
        }
    }

    fn remap_timer(timer: timers.TimerOptions, remap: afio.Remap) void {
        switch (timer) {
            .TIM2 => afio.timer2_remap(remap),
            .TIM1 => afio.timer2_remap(remap),
            .TIM2 => afio.timer4_remap(remap),
            else => {},
        }
    }

    fn trigger(self: TimeIntervalSensor, trigger_pulse_width: u8) void {
        gpio.write_pin(self.trig, true);
        timers.busy_wait_us(trigger_pulse_width);
        gpio.write_pin(self.trig, false);
    }

    pub fn measure_pulse(self: TimeIntervalSensor, trigger_pulse_width: u8, timer: timers.TimerOptions) u32 {
        // Configure input capture for the echo pin
        timers.init_input_capture(timer, 1, .Both); // Assuming channel 1 for echo

        if (self.trig != null)
            self.trigger(trigger_pulse_width); // Trigger with 10µs pulse
        // Wait for echo HIGH
        while (!gpio.read_pin(self.echo)) {}
        const start = timers.get_counter(timer);

        // Wait for echo LOW
        while (gpio.read_pin(self.echo)) {}
        const end = timers.get_counter(timer);

        return end - start;
    }
};

/// Specialization: Ultrasonic
pub const UltrasonicSensor = struct {
    base: TimeIntervalSensor,

    pub fn init(comptime trig: SensorPin, comptime echo: SensorPin) UltrasonicSensor {
        return .{ .base = TimeIntervalSensor.init(trig, echo) };
    }

    pub fn read_distance_cm(self: UltrasonicSensor) f32 {
        const duration = self.base.measure_pulse(
            10, // Trigger pulse width in microseconds
            .TIM2, // Using TIM2 for input capture
            .Both, // Measure rising edge
        );
        // Convert pulse width to distance (cm)
        return (@as(f32, duration) * 0.0343) / 2.0;
    }
};

// ─────────────────────────────
// 3. DIGITAL SERIAL (I²C / SPI / 1-WIRE)
// ─────────────────────────────
pub const SerialDataSensor = struct {
    // Placeholder for future implementation
    _: u8,
};
