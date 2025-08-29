cd zig-out/lib
arm-none-eabi-gcc -mcpu=cortex-m3 -mthumb -nostdlib -nostartfiles -nodefaultlibs -T bluepill.ld firmware.o startup.s -Wl,-Map=firmware.map -o firmware.elf
