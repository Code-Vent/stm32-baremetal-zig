pub const Config = struct {
    cr_mask: u32,
    cfgr_mask: u32,
    clock_freq: u32,

    pub fn init(comptime freq_in_MHz: u8) Config {
        const mul = @as(u32, freq_in_MHz >> 2);
        var cr: u32 = 0x83;
        var cfgr: u32 = 0x00;
        var freq: u32 = 0;
        switch (mul) {
            0...1 => {
                //4MHz => Use HSE divide by 2
                //HSE = ON, HSI = OFF, PLL = OFF, PLLXTPRE = 1
                //Select HSE with SW bits
                cr |= (1 << 16); //HSEON
                cfgr |= (1 << 17) | 0x01; //PLLXTPRE|SW
                freq = 4_000_000;
            },
            2...13 => {
                //HSI = ON, PLL = ON, HSE = OFF, PLLSRC = 0
                //Set pllmull to (mull - 2)
                //Select PLLCLK with sw bits
                cr |= (1 << 24); //PLLON
                cfgr |= @as(u32, (mul - 2) << 18) | 0x02; //PLLMULL|SW
                freq = mul * 4_000_000;
            },
            else => {
                const mul1 = @as(u32, freq_in_MHz >> 3);
                //HSE = ON, PLL = ON, HSI = OFF, PLLXTPRE = 0, PLLSRC = 1
                //Set pllmull to 9
                //Select PLLCLK with sw bits
                cr |= (1 << 16) | (1 << 24); //HSEON|PLLON
                if (mul1 < 9) {
                    cfgr |= (1 << 16) | @as(u32, (mul1 - 2) << 18) | 0x02;
                    freq = mul1 * 8_000_000;
                } else {
                    cfgr |= (1 << 16) | (0x07 << 18) | 0x02; //PLLSRC|PLLMULL|SW
                    freq = 9 * 8_000_000;
                }
            },
        }
        return Config{
            .cr_mask = cr,
            .cfgr_mask = cfgr,
            .clock_freq = freq,
        };
    }
};

pub const ClockSrc = enum {
    AHB,
    APB1,
    APB2,
};

fn rcc_reg(offset: u32) *volatile u32 {
    return @ptrFromInt(0x4002_1000 + offset);
}

pub fn enable(clock: ClockSrc, mask: u32) void {
    switch (clock) {
        .AHB => {
            const ahb = rcc_reg(0x14);
            ahb.* |= mask;
        },
        .APB1 => {
            const apb1 = rcc_reg(0x1C);
            apb1.* |= mask;
        },
        .APB2 => {
            const apb2 = rcc_reg(0x18);
            apb2.* |= mask;
        },
    }
}

pub fn start(config: Config) u32 {
    const cr = rcc_reg(0x00);
    const cfgr = rcc_reg(0x04);

    if ((config.cr_mask & (1 << 16)) != 0) { //HSE ON
        cr.* |= (1 << 16);
        while ((cr.* & (1 << 17)) == 0) {}
        cfgr.* |= (config.cfgr_mask & (1 << 17)); //PLLXTPRE
    }

    //PLL MULTIPLIER
    cfgr.* |= (config.cfgr_mask & (1 << 18));
    cfgr.* |= (config.cfgr_mask & (1 << 19));
    cfgr.* |= (config.cfgr_mask & (1 << 20));
    cfgr.* |= (config.cfgr_mask & (1 << 21));

    if ((config.cr_mask & (1 << 24)) != 0) { //PLL ON
        cr.* |= (1 << 24);
        while ((cr.* & (1 << 25)) == 0) {}
        cfgr.* |= (config.cfgr_mask & (1 << 16)); //PLLSRC
    }
    //SW
    cfgr.* |= (config.cfgr_mask & (1 << 0));
    cfgr.* |= (config.cfgr_mask & (1 << 1));

    return config.clock_freq;
}
