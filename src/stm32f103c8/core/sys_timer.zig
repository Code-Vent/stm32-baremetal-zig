//pub const sys_timer = struct {};

fn sys_timer_reg(offset: u32) *volatile u32 {
    return @ptrFromInt(0xE000_E010 + offset);
}

pub fn init_delay(clock_freq: u32, unit: u32) void {
    const ctrl = sys_timer_reg(0x00);
    const load = sys_timer_reg(0x04);
    const val = sys_timer_reg(0x08);

    load.* = (clock_freq / unit) - 1; //@as(u32, 1);
    val.* = 0;
    ctrl.* |= (1 << 0) | (1 << 1) | (1 << 2);
}
