/* ============================================================================
 * Linker Script — StratOS x86_64 kernel
 * tools/linker.ld
 * ============================================================================ */

OUTPUT_FORMAT(elf64-x86-64)
OUTPUT_ARCH(i386:x86-64)
ENTRY(_start)

/* Kernel loads at 1MB */
KERNEL_OFFSET = 0x100000;

SECTIONS
{
    . = KERNEL_OFFSET;

    /* Code section */
    .text ALIGN(4K) : {
        *(.text.boot)       /* Boot entry point first */
        *(.text)
        *(.text.*)
    }

    /* Read-only data */
    .rodata ALIGN(4K) : {
        *(.rodata)
        *(.rodata.*)
    }

    /* Initialized data */
    .data ALIGN(4K) : {
        *(.data)
        *(.data.*)
    }

    /* C++ static constructors (.init_array)
     * These must be called before kernel_main to initialize
     * global objects (fontData, exceptionNames, etc.).
     * boot.S iterates from __init_array_start to __init_array_end
     * and calls each function pointer.
     */
    .init_array ALIGN(8) : {
        __init_array_start = .;
        KEEP(*(.init_array))
        KEEP(*(.init_array.*))
        __init_array_end = .;
    }

    /* Uninitialized data */
    .bss ALIGN(4K) : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        __bss_end = .;
    }

    /* Kernel end marker */
    __kernel_end = .;

    /* Discard unneeded sections */
    /DISCARD/ : {
        *(.comment)
        *(.note)
        *(.note.*)
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
}
