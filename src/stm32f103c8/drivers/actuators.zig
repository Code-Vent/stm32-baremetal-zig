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

    pub fn init(comptime timer: Timer, comptime channel: timers.Channel, comptime remap: afio.Remap) PWM {
        const map = switch (timer) {
            .TIM1 => timers.timer_map.TIM1,
            .TIM2 => timers.timer_map.TIM2,
            .TIM3 => timers.timer_map.TIM3,
            .TIM4 => timers.timer_map.TIM4,
            else => {},
        };
        const options = switch (channel) {
            .CH1 => map.CH1,
            .CH2 => map.CH2,
            .CH3 => map.CH3,
            .CH4 => map.CH4,
        };
        const option = options[@intFromEnum(remap)];

        const cfgs = [_]gpio.Config{
            gpio.Config.init(option.num, option.port, .Output50MHz, .Input_OR_AltPP, .NONE),
        };
        const ports = [_]gpio.Port{
            option.port,
        };
        gpio.config_gpio(&ports, &cfgs);

        const apb1_freq = core.get_apb1_clock_freq() * clock.get_apb1_prescaler();

        const prescaler: u16 = @intCast((apb1_freq / 1_000_000) - 1); // 1 MHz timer clock
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
        const cmp_masks = timers.CaptureCompareMasks.initCompare(cmp_cfg);

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

pub const Dimmer = struct {
    base: PWM,

    pub fn init(comptime timer: Timer, comptime channel: timers.Channel, comptime remap: afio.Remap) Dimmer {
        const base = PWM.init(timer, channel, remap);
        return Dimmer{
            .base = base,
        };
    }

    pub fn set_brightness(self: Dimmer, percent: u8) void {
        self.base.set_duty_cycle(percent);
    }
};
