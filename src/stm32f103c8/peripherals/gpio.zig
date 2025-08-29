const core = @import("../core/core.zig");

pub const Port = enum(u3) { A = 2, B = 3, C = 4, D = 5 };

pub const Mode = enum(u2) {
    Input = 0b00,

    Output10MHz = 0b01,
    Output2MHz = 0b10,
    Output50MHz = 0b11,
};

pub const Cnf = enum(u2) {
    Analog_OR_GpioPP = 0b00,
    Floating_OR_GpioOD = 0b01,
    Input_OR_AltPP = 0b10,
    AltOD = 0b11,
};

pub const Pull = enum {
    UP,
    DOWN,
    NONE,
};

pub const Pin = struct {
    port: Port,
    mask: u32,
};

pub const Config = struct {
    _port: Port,
    cnf_mode_mask: u32,
    pupdr_mask: u32,
    _pin: u8,
    _pull: Pull,

    pub fn init(comptime pin: u8, port: Port, mode: Mode, cnf: Cnf, pull: Pull) Config {
        const index: u32 = @intCast(pin & 0x7); // * 4;
        const m: u32 = @intFromEnum(mode);
        const c: u32 = @intFromEnum(cnf);
        return Config{
            ._port = port,
            .cnf_mode_mask = ((c << 2) | m) << (index * 4),
            .pupdr_mask = (1 << index),
            ._pin = pin,
            ._pull = pull,
        };
    }
};

fn gpio_reg(port: Port, offset: u32) *volatile u32 {
    return switch (port) {
        .A => @ptrFromInt(0x4001_0800 + offset),
        .B => @ptrFromInt(0x4001_0C00 + offset),
        .C => @ptrFromInt(0x4001_1000 + offset),
        .D => @ptrFromInt(0x4001_1400 + offset),
    };
}

pub fn config_gpio(comptime N: usize, comptime en_list: [N]Port, cfgs: []const Config) void {
    inline for (en_list, 0..) |_, i| {
        enable(@intFromEnum(en_list[i]));
    }
    for (cfgs) |cfg| {
        const crl = gpio_reg(cfg._port, 0x00);
        const crh = gpio_reg(cfg._port, 0x04);
        const odr = gpio_reg(cfg._port, 0x0C);

        if (cfg._pin < 8) {
            crl.* |= cfg.cnf_mode_mask;
        } else {
            crh.* |= cfg.cnf_mode_mask;
        }

        if (cfg._pull == .UP) {
            odr.* |= cfg.pupdr_mask;
        } else if (cfg._pull == .DOWN) {
            odr.* &= ~cfg.pupdr_mask;
        }
    }
}

pub fn write_pin(pin: Pin, value: bool) void {
    const odr = gpio_reg(pin.port, 0x0C);
    if (value) {
        odr.* |= pin.mask;
    } else {
        odr.* &= ~pin.mask;
    }
}

pub fn read_pin(pin: Pin) bool {
    const idr = gpio_reg(pin.port, 0x08);
    return (idr.* & pin.mask) != 0;
}

fn enable(comptime bit: u32) void {
    core.enable_peripheral(.APB2, 1 << bit);
}
