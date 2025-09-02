pub var systick: u32 = 0;
const systick_ptr: *volatile u32 = &systick;

export fn SysTick_Handler() callconv(.C) void {
    systick_ptr.* += 1;
}

export fn SVC_Handler() callconv(.C) void {
    while (true) {}
}

pub fn init() void {}
