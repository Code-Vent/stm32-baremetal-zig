const gpio = @import("../peripherals/gpio.zig");
const timers = @import("../peripherals/timers.zig");
const afio = @import("../peripherals/afio.zig");
const core = @import("../core/core.zig");
const clock = @import("../core/clock.zig");

const Timer = timers.Timer;

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

//PMW
pub const PWM = struct {
    timer: timers.Timer,
    channel: timers.Channel,

    pub fn init(
        pin: afio.Pin,
        timer: timers.Timer,
        channel: timers.Channel,
        remap: afio.Remap,
    ) PWM {
        switch (remap) {
            .NO_REMAP => {
                timers.assertTimerCompatible(pin, timer, channel);
            },
            .PARTIAL_REMAP => {
                timers.assertTimerPartialRemapCompatible(pin, timer, channel);
                timers.remap_timer(timer, remap);
            },
            .FULL_REMAP => {
                timers.assertTimerFullRemapCompatible(pin, timer, channel);
                timers.remap_timer(timer, remap);
            },
        }
        const cfgs = [_]gpio.Config{
            gpio.Config.init(pin.num, pin.port, .Output50MHz, .Input_OR_AltPP, .NONE),
        };
        const ports = [_]gpio.Port{
            pin.port,
        };
        gpio.config_gpio(&ports, &cfgs);

        const apb1_freq = core.Env.apb1_clock_freq * clock.get_apb1_prescaler();

        const prescaler = apb1_freq / 1_000_000 - 1; // 1 MHz timer clock
        const counter_cfg = timers.CounterConfig{
            .auto_reload = 999,
            .prescaler = prescaler,
            .counter_mode = .Up,
            .clock_division = 0,
            .repetition_counter = 0,
        };
        const cmp_cfg = timers.CmpConfig{
            .cmp_out = .PWM1,
            .ch = channel,
            .fast = .ENABLE,
            .preload = .ENABLE,
            .active_state = .HIGH,
        };
        const cmp_masks = timers.CaptureCompareMasks.initCompare(&cmp_cfg);

        timers.start_capture_compare(timer, channel, counter_cfg, cmp_masks, 500);

        return PWM{
            .timer = timer,
            .channel = channel,
        };
    }

    pub fn set_duty_cycle(self: PWM, duty_cycle_percent: u8) void {
        const duty = @as(u16, (duty_cycle_percent * (self.auto_reload + 1)) / 100);
        timers.set_pwm_duty(self.timer, self.channel, duty);
    }

    pub fn set_frequency(self: PWM, freq_in_Hz: u32) void {
        const auto_reload = (1_000_000 / freq_in_Hz) - 1;
        timers.set_auto_reload(self.timer, auto_reload);
    }

    pub fn stop(self: PWM) void {
        timers.stop(self.timer);
    }
};
