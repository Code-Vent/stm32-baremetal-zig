/* Minimal STM32F103C8 linker script for Zig bare-metal */

ENTRY(Reset_Handler)

/* Memory regions */
MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 64K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 20K
}

/* Symbols Zig code may use */
_estack = ORIGIN(RAM) + LENGTH(RAM);

/* Sections */
SECTIONS
{
    /* Vector table goes at start of flash */
    .isr_vector :
    {
        KEEP(*(.isr_vector))   /* vector_table from startup.zig */
    } > FLASH

    /* Program code */
    .text :
    {
        *(.text .text.*)
        *(.rodata .rodata.*)
    } > FLASH
    _sidata = LOADADDR(.data);
    /* Initialized data section */
    .data :
    {
        _sdata = .;
        *(.data .data.*)
        _edata = .;
    } > RAM

    /* Zero-initialized data */
    .bss :
    {
        __bss_start__ = .;
        *(.bss .bss.*)
        *(COMMON)
        __bss_end__ = .;
    } > RAM

    /DISCARD/ :
    {
        *(.ARM.exidx*)
        *(.ARM.extab*)
    }

}
