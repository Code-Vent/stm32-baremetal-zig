const gpio = @import("../peripherals/gpio.zig");
const timers = @import("../peripherals/timers.zig");
const afio = @import("../peripherals/afio.zig");
const core = @import("../core/core.zig");
const clock = @import("../core/clock.zig");

const Timer = timers.Timer;

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

    pub fn read(self: AnalogSensor) u16 {
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
    channel: timers.Channel,
    timer: Timer,

    pub fn init(comptime timer: Timer, comptime echo_channel: timers.Channel, comptime trig: ?afio.Pin, comptime remap: afio.Remap) TimeIntervalSensor {
        const map = switch (timer) {
            .TIM1 => timers.timer_map.TIM1,
            .TIM2 => timers.timer_map.TIM2,
            .TIM3 => timers.timer_map.TIM3,
            .TIM4 => timers.timer_map.TIM4,
            else => {},
        };
        const options = switch (echo_channel) {
            .CH1 => map.CH1,
            .CH2 => map.CH2,
            .CH3 => map.CH3,
            .CH4 => map.CH4,
        };
        const option = options[@intFromEnum(remap)];

        const echo_cfg = [_]gpio.Config{
            gpio.Config.init(option.num, option.port, .Input, .Input_OR_AltPP, .DOWN),
        };
        gpio.config_gpio(1, .{option.port}, &echo_cfg);

        if (trig != null) {
            const trig_cfg = [_]gpio.Config{
                gpio.Config.init(trig.?.num, trig.?.port, .Output50MHz, .PushPull_OR_AltPP, null),
            };
            gpio.config_gpio(1, .{trig.?.port}, &trig_cfg);
        }

        const echo_pin = gpio.Pin{
            .port = option.port,
            .mask = (1 << option.num),
        };

        if (trig == null) {
            return TimeIntervalSensor{
                .trig = null,
                .echo = echo_pin,
                .channel = echo_channel,
                .timer = timer,
            };
        } else {
            return TimeIntervalSensor{
                .trig = gpio.Pin{
                    .port = trig.?.port,
                    .mask = (1 << trig.?.num),
                },
                .echo = echo_pin,
                .channel = echo_channel,
                .timer = timer,
            };
        }
    }

    fn trigger(self: TimeIntervalSensor, trigger_pulse_width: u8) void {
        gpio.write_pin(self.trig, true);
        core.delay_us(trigger_pulse_width);
        gpio.write_pin(self.trig, false);
    }

    pub fn measure_pulse(self: TimeIntervalSensor, trigger_pulse_Us: u8) u32 {
        const apb1_freq = core.Env.apb1_clock_freq * clock.get_apb1_prescaler();

        const auto_reload = (apb1_freq / 1_000_000) - 1;
        const counter_config = timers.CounterConfig{
            .prescaler = 0,
            .auto_reload = auto_reload,
            .clock_division = 0,
            .counter_mode = .Up,
            .repetition_counter = 0,
        };

        const cap_config = timers.CapConfig{
            .ch = self.channel,
            .edge = .Rising,
        };
        const cap_masks = timers.CaptureCompareMasks.initCapture(cap_config);

        timers.start_capture_compare(
            self.timer,
            self.channel,
            counter_config,
            cap_masks,
        );

        if (self.trig != null)
            self.trigger(trigger_pulse_Us); // Trigger with 10µs pulse
        // Wait for echo HIGH
        while (!gpio.read_pin(self.echo)) {}
        const start = timers.get_counter(self.timer);

        // Wait for echo LOW
        while (gpio.read_pin(self.echo)) {}
        const end = timers.get_counter(self.timer);

        return end - start;
    }
};

/// Specialization: Ultrasonic
pub const UltrasonicSensor = struct {
    base: TimeIntervalSensor,

    pub fn init(comptime timer: Timer, comptime echo_channel: timers.Channel, comptime trig: ?afio.Pin, comptime remap: afio.Remap) UltrasonicSensor {
        return .{ .base = TimeIntervalSensor.init(timer, echo_channel, trig, remap) };
    }

    pub fn read_distance_cm(self: UltrasonicSensor) f32 {
        const duration = self.base.measure_pulse(
            self.base,
            10, // Trigger pulse width in microseconds
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
