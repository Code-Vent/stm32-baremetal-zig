const core = @import("../core/core.zig");

pub fn init() void {}

//Write Uart api and functionalities following the patterns
//of gpio.zig and timer.zig
pub const Uart = enum(u8) {
    USART1 = 14,
    USART2 = 17,
    USART3 = 18,
};

pub const BaudRate = enum(u32) {
    BR9600 = 9600,
    BR19200 = 19200,
    BR38400 = 38400,
    BR57600 = 57600,
    BR115200 = 115200,
};

pub const Config = struct {
    uart: Uart,
    baud_rate: BaudRate,
};

fn uart_reg(uart: Uart, offset: u32) *volatile u32 {
    return switch (uart) {
        .USART1 => @ptrFromInt(0x4001_3800 + offset),
        .USART2 => @ptrFromInt(0x4000_4400 + offset),
        .USART3 => @ptrFromInt(0x4000_4800 + offset),
    };
}

pub fn config_uart(comptime N: usize, comptime en_list: [N]Uart, cfgs: []const Config) void {
    inline for (en_list, 0..) |_, i| {
        enable(@intFromEnum(en_list[i]));
    }
    for (cfgs) |cfg| {
        const cr1 = uart_reg(cfg.uart, 0x0C);
        const brr = uart_reg(cfg.uart, 0x08);

        // Configure baud rate
        brr.* = @intFromEnum(cfg.baud_rate);

        // Enable USART, TE and RE
        cr1.* |= (1 << 13) | (1 << 3) | (1 << 2);
    }
}

fn enable(comptime uart: Uart) void {
    switch (uart) {
        .USART1 => core.enable_peripheral(.APB2, @intFromEnum(uart)), // Enable USART1 clock
        .USART2 => core.enable_peripheral(.APB1, @intFromEnum(uart)), // Enable USART2 clock
        .USART3 => core.enable_peripheral(.APB1, @intFromEnum(uart)), // Enable USART3 clock
    }
}

pub fn write(uart: Uart, data: u8) void {
    const sr = uart_reg(uart, 0x00);
    const dr = uart_reg(uart, 0x04);

    // Wait until TXE (Transmit Data Register Empty) is set
    while ((sr.* & (1 << 7)) == 0) {}

    // Write data to DR (Data Register)
    dr.* = data;
}

pub fn read(uart: Uart) u8 {
    const sr = uart_reg(uart, 0x00);
    const dr = uart_reg(uart, 0x04);

    // Wait until RXNE (Read Data Register Not Empty) is set
    while ((sr.* & (1 << 5)) == 0) {}

    // Read data from DR (Data Register)
    return @as(u8, dr.*);
}

pub fn write_string(uart: Uart, str: []const u8) void {
    for (str) |c| {
        write(uart, c);
    }
}

pub fn read_string(uart: Uart, buffer: []u8) usize {
    var i: usize = 0;
    while (i < buffer.len) {
        const c = read(uart);
        if (c == 0) break; // Stop on null terminator
        buffer[i] = c;
        i += 1;
    }
    return i; // Return number of characters read
}

pub fn deinit(uart: Uart) void {
    const cr1 = uart_reg(uart, 0x0C);

    // Disable USART
    cr1.* &= ~(1 << 13);
}

pub fn is_tx_empty(uart: Uart) bool {
    const sr = uart_reg(uart, 0x00);

    return (sr.* & (1 << 7)) != 0;
}

pub fn is_rx_not_empty(uart: Uart) bool {
    const sr = uart_reg(uart, 0x00);
    return (sr.* & (1 << 5)) != 0;
}

pub fn flush(uart: Uart) void {
    while (!is_tx_empty(uart)) {}
}

pub fn available(uart: Uart) bool {
    return is_rx_not_empty(uart);
}

pub fn clear_flags(uart: Uart) void {
    const sr = uart_reg(uart, 0x00);
    const dr = uart_reg(uart, 0x04);

    // Clear all status flags by reading SR and then DR
    _ = sr.*;
    _ = dr.*; // Read DR
}

pub fn set_interrupt(uart: Uart, en: bool) void {
    const cr1 = uart_reg(uart, 0x0C);

    if (en) {
        cr1.* |= (1 << 5); // Enable RXNEIE (RX Not Empty Interrupt Enable)
    } else {
        cr1.* &= ~(1 << 5); // Disable RXNEIE
    }
}

pub fn set_mode(uart: Uart, mode: enum { TX, RX, TX_RX }) void {
    const cr1 = uart_reg(uart, 0x0C);

    // Clear TE and RE bits
    cr1.* &= ~((1 << 3) | (1 << 2));

    switch (mode) {
        .TX => cr1.* |= (1 << 3), // Enable Transmitter
        .RX => cr1.* |= (1 << 2), // Enable Receiver
        .TX_RX => cr1.* |= (1 << 3) | (1 << 2), // Enable both
    }
}

pub fn set_parity(uart: Uart, parity: enum { NONE, EVEN, ODD }) void {
    const cr1 = uart_reg(uart, 0x0C);

    // Clear PCE and PS bits
    cr1.* &= ~((1 << 10) | (1 << 9));

    switch (parity) {
        .NONE => {}, // No parity
        .EVEN => cr1.* |= (1 << 10), // Enable Even Parity
        .ODD => cr1.* |= (1 << 10) | (1 << 9), // Enable Odd Parity
    }
}

pub fn set_stop_bits(uart: Uart, stop_bits: enum { ONE, HALF, TWO, ONE_AND_HALF }) void {
    const cr2 = uart_reg(uart, 0x10);
    // Clear STOP bits
    cr2.* &= ~(0b11 << 12);
    switch (stop_bits) {
        .ONE => {}, // 1 Stop bit
        .HALF => cr2.* |= (0b01 << 12), // 0.5 Stop bits
        .TWO => cr2.* |= (0b10 << 12), // 2 Stop bits
        .ONE_AND_HALF => cr2.* |= (0b11 << 12), // 1.5 Stop bits
    }
}

pub fn set_word_length(uart: Uart, length: enum { WL8, WL9 }) void {
    const cr1 = uart_reg(uart, 0x0C);
    // Clear M bit
    cr1.* &= ~(1 << 12);
    switch (length) {
        .WL8 => {}, // 8 Data bits
        .WL9 => cr1.* |= (1 << 12), // 9 Data bits
    }
}

pub fn set_hardware_flow_control(uart: Uart, en: bool) void {
    const cr3 = uart_reg(uart, 0x14);
    if (en) {
        cr3.* |= (1 << 8) | (1 << 9); // Enable CTS and RTS
    } else {
        cr3.* &= ~((1 << 8) | (1 << 9)); // Disable CTS and RTS
    }
}

pub fn set_dma(uart: Uart, enable_tx: bool, enable_rx: bool) void {
    const cr3 = uart_reg(uart, 0x14);
    // Clear DMAT and DMAR bits
    cr3.* &= ~((1 << 7) | (1 << 6));
    if (enable_tx) {
        cr3.* |= (1 << 7); // Enable DMA for Transmission
    }
    if (enable_rx) {
        cr3.* |= (1 << 6); // Enable DMA for Reception
    }
}

pub fn set_linenumber(uart: Uart, line_number: u8) void {
    const cr4 = uart_reg(uart, 0x18);
    // Clear LBDL and LBDIE bits
    cr4.* &= ~((1 << 5) | (1 << 6));
    if (line_number > 0) {
        cr4.* |= (1 << 5); // Enable LIN mode
        cr4.* |= (line_number & 0x0F) << 0; // Set line number (4 bits)
    }
}

pub fn set_smartcard_mode(uart: Uart, en: bool) void {
    const cr3 = uart_reg(uart, 0x14);
    if (en) {
        cr3.* |= (1 << 5); // Enable Smartcard mode
    } else {
        cr3.* &= ~(1 << 5); // Disable Smartcard mode
    }
}

pub fn set_irda_mode(uart: Uart, en: bool) void {
    const cr3 = uart_reg(uart, 0x14);
    if (en) {
        cr3.* |= (1 << 4); // Enable IrDA mode
    } else {
        cr3.* &= ~(1 << 4); // Disable IrDA mode
    }
}

pub fn set_over8(uart: Uart, over8: bool) void {
    const cr1 = uart_reg(uart, 0x0C);
    if (over8) {
        cr1.* |= (1 << 15); // Enable oversampling by 8
    } else {
        cr1.* &= ~(1 << 15); // Enable oversampling by 16
    }
}

pub fn set_onebit_sampling(uart: Uart, en: bool) void {
    const cr3 = uart_reg(uart, 0x14);
    if (en) {
        cr3.* |= (1 << 11); // Enable one sample bit method
    } else {
        cr3.* &= ~(1 << 11); // Disable one sample bit method
    }
}

pub fn set_tx_complete_interrupt(uart: Uart, en: bool) void {
    const cr1 = uart_reg(uart, 0x0C);
    if (en) {
        cr1.* |= (1 << 6); // Enable TCIE (Transmission Complete Interrupt Enable)
    } else {
        cr1.* &= ~(1 << 6); // Disable TCIE
    }
}

pub fn set_idle_line_interrupt(uart: Uart, en: bool) void {
    const cr1 = uart_reg(uart, 0x0C);
    if (en) {
        cr1.* |= (1 << 4); // Enable IDLEIE (Idle Line Interrupt Enable)
    } else {
        cr1.* &= ~(1 << 4); // Disable IDLEIE
    }
}

pub fn set_error_interrupt(uart: Uart, en: bool) void {
    const cr3 = uart_reg(uart, 0x14);
    if (en) {
        cr3.* |= (1 << 0); // Enable EIE (Error Interrupt Enable)
    } else {
        cr3.* &= ~(1 << 0); // Disable EIE
    }
}
