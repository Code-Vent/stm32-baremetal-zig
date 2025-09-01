cd zig-out/lib
arm-none-eabi-gcc -mcpu=cortex-m3 -mthumb -nostdlib -nostartfiles -nodefaultlibs -T linker.ld firmware.o -Wl,-Map=firmware.map -o firmware.elf
