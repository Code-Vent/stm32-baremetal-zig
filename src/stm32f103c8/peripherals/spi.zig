const std = @import("std");
const core = @import("../core/core.zig");
const afio = @import("afio.zig");
const gpio = @import("gpio.zig");

pub const Spi = enum(u5) {
    SPI1 = 12,
    SPI2 = 14,
    SPI3 = 15,
};

pub const SpiPins = enum {
    NSS,
    SCK,
    MISO,
    MOSI,
};

pub const BaudRate = enum(u3) {
    DIV2 = 0,
    DIV4 = 1,
    DIV8 = 2,
    DIV16 = 3,
    DIV32 = 4,
    DIV64 = 5,
    DIV128 = 6,
    DIV256 = 7,
};

pub const SpiConfig = struct {
    br: BaudRate,
    mstr: enum(u1) { MASTER = 1, SLAVE = 0 },
    cpol: enum(u1) { LOW = 0, HIGH = 1 },
    cpha: enum(u1) { FIRST = 0, SECOND = 1 },
    dff: enum(u1) { EIGHTBIT = 0, SIXTEENBIT = 1 },
    lsbfirst: enum(u1) { MSB_FIRST = 0, LSB_FIRST = 1 },
    ssm: enum(u1) { DISABLE = 0, ENABLE = 1 },
    ssi: enum(u1) { DISABLE = 0, ENABLE = 1 },
    crc_en: enum(u1) { DISABLE = 0, ENABLE = 1 },
    crc_polynomial: u16,
};

pub const SpiConfigMasks = struct {
    cr1_mask: u32,
    crcpr: ?u16,

    pub fn init(cfg: SpiConfig) SpiConfigMasks {
        var cr1: u32 = 0;
        var crcpr: ?u32 = null;

        // Configure CR1
        cr1 |= @as(u32, @intFromEnum(cfg.br)) << 3; // BR[2:0] bits
        cr1 |= @as(u32, @intFromEnum(cfg.mstr)) << 2; // MSTR bit
        cr1 |= @as(u32, @intFromEnum(cfg.cpol)) << 1; // CPOL bit
        cr1 |= @as(u32, @intFromEnum(cfg.cpha)) << 0; // CPHA bit
        cr1 |= @as(u32, @intFromEnum(cfg.dff)) << 11; // DFF bit
        cr1 |= @as(u32, @intFromEnum(cfg.lsbfirst)) << 7; // LSBFIRST bit
        cr1 |= @as(u32, @intFromEnum(cfg.ssm)) << 9; // SSM bit
        cr1 |= @as(u32, @intFromEnum(cfg.ssi)) << 8; // SSI bit
        cr1 |= @as(u32, @intFromEnum(cfg.crc_en)) << 13; // CRCENABLE bit

        if (cfg.crc_polynomial != 0) {
            crcpr = cfg.crc_polynomial; // Set CRC Polynomial if provided
        }

        return SpiConfigMasks{
            .cr1_mask = cr1,
            .crcpr = crcpr,
        };
    }
};

fn spi_reg(spi: Spi, offset: u32) *volatile u32 {
    return switch (spi) {
        .SPI1 => @ptrFromInt(0x4001_3000 + offset),
        .SPI2 => @ptrFromInt(0x4000_3800 + offset),
        .SPI3 => @ptrFromInt(0x4000_3C00 + offset),
    };
}

fn enable(spi: Spi) void {
    switch (spi) {
        .SPI1 => core.enable_peripheral(.APB2, @intFromEnum(spi)),
        else => core.enable_peripheral(.APB1, @intFromEnum(spi)),
    }
}

pub fn config_spi(spi: Spi, cfg: SpiConfigMasks, remap: afio.Remap) void {
    //Configure GPIO pins
    const spi_pins = switch (spi) {
        .SPI1 => spi_map.SPI1,
        .SPI2 => spi_map.SPI2,
        .SPI3 => spi_map.SPI3,
    };

    const nss = spi_pins.NSS[@intFromEnum(remap)];
    const sck = spi_pins.SCK[@intFromEnum(remap)];
    const miso = spi_pins.MISO[@intFromEnum(remap)];
    const mosi = spi_pins.MOSI[@intFromEnum(remap)];

    const cfgs = [_]gpio.Config{
        gpio.Config.init(nss.num, nss.port, .Output50MHz, .Input_OR_AltPP, .NONE),
        gpio.Config.init(sck.num, sck.port, .Output50MHz, .Input_OR_AltPP, .NONE),
        gpio.Config.init(miso.num, miso.port, .Output50MHz, .Input_OR_AltPP, .NONE),
        gpio.Config.init(mosi.num, mosi.port, .Output50MHz, .Input_OR_AltPP, .NONE),
    };
    const ports = [_]gpio.Port{
        nss.port,
        sck.port,
        miso.port,
        mosi.port,
    };
    gpio.config_gpio(&ports, &cfgs);
    afio.init();
    remap_spi(spi, remap);
    enable(spi); // Enable SPI clock
    const cr1 = spi_reg(spi, 0x00);
    const crcpr = spi_reg(spi, 0x10);

    cr1.* = cfg.cr1_mask; // Apply CR1 configuration
    if (cfg.crcpr) |poly| {
        crcpr.* = poly;
    }

    cr1.* |= 1 << 6; // SPE: SPI Enable
}

pub fn remap_spi(spi: Spi, remap: afio.Remap) void {
    switch (spi) {
        .SPI1 => afio.spi1_remap(remap),
        .SPI3 => afio.spi3_remap(remap),
        else => {},
    }
}

pub fn transfer(data: u8) void {
    _ = data;
}

pub const spi_map = .{
    .SPI1 = .{
        .NSS = .{ .{ .port = .A, .num = 4 }, .{ .port = .A, .num = 15 }, .{ .port = .A, .num = 15 } },
        .SCK = .{ .{ .port = .A, .num = 5 }, .{ .port = .B, .num = 3 }, .{ .port = .B, .num = 3 } },
        .MISO = .{ .{ .port = .A, .num = 6 }, .{ .port = .B, .num = 4 }, .{ .port = .B, .num = 4 } },
        .MOSI = .{ .{ .port = .A, .num = 7 }, .{ .port = .B, .num = 5 }, .{ .port = .B, .num = 5 } },
    },
    .SPI2 = .{
        .NSS = .{ .{ .port = .B, .num = 12 }, .{ .port = .B, .num = 12 }, .{ .port = .B, .num = 12 } },
        .SCK = .{ .{ .port = .B, .num = 13 }, .{ .port = .B, .num = 13 }, .{ .port = .B, .num = 13 } },
        .MISO = .{ .{ .port = .B, .num = 14 }, .{ .port = .B, .num = 14 }, .{ .port = .B, .num = 14 } },
        .MOSI = .{ .{ .port = .B, .num = 15 }, .{ .port = .B, .num = 15 }, .{ .port = .B, .num = 15 } },
    },
    .SPI3 = .{
        .NSS = .{ .{ .port = .A, .num = 15 }, .{ .port = .A, .num = 4 }, .{ .port = .A, .num = 4 } },
        .SCK = .{ .{ .port = .B, .num = 3 }, .{ .port = .C, .num = 10 }, .{ .port = .C, .num = 10 } },
        .MISO = .{ .{ .port = .B, .num = 4 }, .{ .port = .C, .num = 11 }, .{ .port = .C, .num = 11 } },
        .MOSI = .{ .{ .port = .B, .num = 5 }, .{ .port = .C, .num = 12 }, .{ .port = .C, .num = 12 } },
    },
};
