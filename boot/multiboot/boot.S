/* ============================================================================
 * Multiboot 1 Boot Stub — StratOS
 * boot/multiboot/boot.S
 *
 * Provides Multiboot header for GRUB, sets up 64-bit long mode,
 * stack, and calls kernel_main() with BootInfo pointer.
 * ============================================================================ */

/* Multiboot 1 constants */
.set MULTIBOOT_MAGIC,   0x1BADB002
.set MULTIBOOT_FLAGS,   (1 << 0) | (1 << 1) | (1 << 2)   /* page-align | meminfo | video */
.set MULTIBOOT_CHECKSUM, -(MULTIBOOT_MAGIC + MULTIBOOT_FLAGS)

/* ============================================================================
 * Multiboot Header (must be in first 8KB of image)
 * ============================================================================ */
.section .text.boot, "ax"
.align 4
multiboot_header:
    .long MULTIBOOT_MAGIC
    .long MULTIBOOT_FLAGS
    .long MULTIBOOT_CHECKSUM
    /* Address fields (unused with ELF) */
    .long 0     /* header_addr */
    .long 0     /* load_addr */
    .long 0     /* load_end_addr */
    .long 0     /* bss_end_addr */
    .long 0     /* entry_addr */
    /* Video mode fields */
    .long 0     /* mode_type: 0 = linear framebuffer */
    .long 1024  /* width */
    .long 768   /* height */
    .long 32    /* depth (bits per pixel) */

/* ============================================================================
 * Entry point — GRUB starts here in 32-bit protected mode
 * ============================================================================ */
.code32
.global _start
.type _start, @function
_start:
    /* Save multiboot info pointer (EBX) and magic (EAX) */
    movl %ebx, %edi        /* Multiboot info pointer → EDI (will be RDI in 64-bit) */
    movl %eax, %esi        /* Multiboot magic → ESI */

    /* Set up a temporary stack */
    movl $stack_top, %esp

    /* Store multiboot info pointer for later use */
    movl %edi, (mb_info_ptr)

    /* Check if we can enter long mode */
    /* For simplicity, assume we're already in a 64-bit compatible CPU */

    /* Set up paging for long mode */
    /* Identity map first 4GB using 2MB pages */

    /* Clear page tables */
    movl $pml4, %edi
    xorl %eax, %eax
    movl $(page_tables_end - pml4), %ecx
    shrl $2, %ecx
    rep stosl

    /* Set up PML4[0] -> PDPT */
    movl $pml4, %edi
    movl $pdpt, %eax
    orl  $0x03, %eax        /* Present + Writable */
    movl %eax, (%edi)

    /* Set up PDPT[0..3] -> PD[0..3], mapping 4GB */
    movl $pdpt, %edi
    movl $pd0, %eax
    orl  $0x03, %eax
    movl %eax, 0(%edi)
    movl $pd1, %eax
    orl  $0x03, %eax
    movl %eax, 8(%edi)
    movl $pd2, %eax
    orl  $0x03, %eax
    movl %eax, 16(%edi)
    movl $pd3, %eax
    orl  $0x03, %eax
    movl %eax, 24(%edi)

    /* Fill PD entries with 2MB pages (identity map) */
    movl $pd0, %edi
    movl $0x00000083, %eax  /* Present + Writable + 2MB page */
    movl $512 * 4, %ecx     /* 4 page directories × 512 entries = 4GB */
1:
    movl %eax, (%edi)
    movl $0, 4(%edi)        /* Upper 32 bits */
    addl $0x200000, %eax    /* Next 2MB page */
    jnc  2f
    /* Handle carry for addresses > 4GB */
    movl 4(%edi), %edx
    incl %edx
    movl %edx, 4(%edi)
2:
    addl $8, %edi
    decl %ecx
    jnz  1b

    /* Load PML4 into CR3 */
    movl $pml4, %eax
    movl %eax, %cr3

    /* Enable PAE (bit 5 of CR4) */
    movl %cr4, %eax
    orl  $(1 << 5), %eax
    movl %eax, %cr4

    /* Set Long Mode Enable (bit 8 of EFER MSR 0xC0000080) */
    movl $0xC0000080, %ecx
    rdmsr
    orl  $(1 << 8), %eax
    wrmsr

    /* Enable paging (bit 31 of CR0) + protected mode (bit 0) */
    movl %cr0, %eax
    orl  $(1 << 31) | (1 << 0), %eax
    movl %eax, %cr0

    /* Load 64-bit GDT and far jump to 64-bit code */
    lgdt (gdt64_ptr)
    ljmp $0x08, $long_mode_start

/* ============================================================================
 * 64-bit Long Mode Entry
 * ============================================================================ */
.code64
long_mode_start:
    /* Set up 64-bit data segments */
    movw $0x10, %ax
    movw %ax, %ds
    movw %ax, %es
    movw %ax, %fs
    movw %ax, %gs
    movw %ax, %ss

    /* Set up 64-bit stack */
    movabs $stack_top, %rsp

    /* ── Enable SSE/SSE2 (required for floating-point in x86_64 ABI) ── */
    movq %cr0, %rax
    andw $0xFFFB, %ax       /* Clear CR0.EM (bit 2) — disable x87 emulation */
    orw  $0x0002, %ax       /* Set CR0.MP (bit 1) — monitor coprocessor */
    movq %rax, %cr0

    movq %cr4, %rax
    orw  $(1 << 9), %ax     /* Set CR4.OSFXSR (bit 9) — enable FXSAVE/FXRSTOR */
    orw  $(1 << 10), %ax    /* Set CR4.OSXMMEXCPT (bit 10) — enable SSE exceptions */
    movq %rax, %cr4

    /* Initialize x87 FPU */
    fninit

    /* Initialize MXCSR to default value (mask all exceptions) */
    subq $4, %rsp
    movl $0x1F80, (%rsp)    /* Default MXCSR: all exceptions masked */
    ldmxcsr (%rsp)
    addq $4, %rsp

    /* Retrieve multiboot info pointer */
    movl (mb_info_ptr), %edi

    /* Build a BootInfo struct on the stack from Multiboot info */
    /* BootInfo layout (72 bytes):
     *   0:  long framebufferBase
     *   8:  int  framebufferSize
     *  12:  int  screenWidth
     *  16:  int  screenHeight
     *  20:  int  pixelsPerScanline
     *  24:  long memoryMap
     *  32:  int  memoryMapSize
     *  36:  int  memoryMapDescSize
     *  40:  int  memoryMapKey
     */
    subq $80, %rsp          /* Allocate BootInfo on stack (aligned) */
    movq %rsp, %rbx         /* RBX = pointer to BootInfo */

    /* Zero out the struct */
    movq %rbx, %rdi
    xorq %rax, %rax
    movl $10, %ecx
    rep stosq

    /* Check multiboot flags for framebuffer info (bit 12) */
    movl (mb_info_ptr), %edi
    movl 0(%edi), %eax          /* Load multiboot flags */
    testl $(1 << 12), %eax      /* Bit 12 = framebuffer info valid */
    jz .no_framebuffer

    /* Get framebuffer info from multiboot (offset 88 in multiboot_info) */
    movl (mb_info_ptr), %edi
    movl 88(%edi), %eax     /* framebuffer_addr (low) */
    movl 92(%edi), %edx     /* framebuffer_addr (high) */
    shlq $32, %rdx
    orq  %rdx, %rax
    movq %rax, 0(%rbx)      /* bootInfo.framebufferBase */

    movl 96(%edi), %eax     /* framebuffer_pitch */
    movl 104(%edi), %ecx    /* framebuffer_height */
    imull %ecx, %eax
    movl %eax, 8(%rbx)      /* bootInfo.framebufferSize (pitch * height) */

    movl 100(%edi), %eax    /* framebuffer_width */
    movl %eax, 12(%rbx)     /* bootInfo.screenWidth */

    movl 104(%edi), %eax    /* framebuffer_height */
    movl %eax, 16(%rbx)     /* bootInfo.screenHeight */

    movl 96(%edi), %eax     /* framebuffer_pitch */
    shrl $2, %eax           /* pitch / 4 = pixels per scanline (for 32bpp) */
    movl %eax, 20(%rbx)     /* bootInfo.pixelsPerScanline */

.no_framebuffer:
    /* Memory map from multiboot (flags bit 6) */
    movl (mb_info_ptr), %edi
    movl 0(%edi), %eax      /* multiboot flags */
    testl $(1 << 6), %eax
    jz .no_mmap

    movl 44(%edi), %eax     /* mmap_length */
    movl %eax, 32(%rbx)     /* bootInfo.memoryMapSize */

    movl 48(%edi), %eax     /* mmap_addr */
    movq %rax, 24(%rbx)     /* bootInfo.memoryMap */

    movl $24, 36(%rbx)      /* bootInfo.memoryMapDescSize (multiboot mmap entry = 24 bytes) */

.no_mmap:
    /* ── Early serial console init (COM1 at 0x3F8) ── */
    /* This provides debug output even if the kernel crashes early */
    movw $0x3F8, %dx

    /* Disable interrupts */
    addw $1, %dx            /* 0x3F9 */
    xorb %al, %al
    outb %al, %dx

    /* Set DLAB */
    addw $2, %dx            /* 0x3FB */
    movb $0x80, %al
    outb %al, %dx

    /* Baud rate divisor = 1 (115200 baud) */
    movw $0x3F8, %dx
    movb $0x01, %al
    outb %al, %dx
    incw %dx                /* 0x3F9 */
    xorb %al, %al
    outb %al, %dx

    /* 8N1 */
    movw $0x3FB, %dx
    movb $0x03, %al
    outb %al, %dx

    /* Enable FIFO */
    decw %dx                /* 0x3FA */
    movb $0xC7, %al
    outb %al, %dx

    /* Modem control: RTS/DSR */
    movw $0x3FC, %dx
    movb $0x0B, %al
    outb %al, %dx

    /* Print "BOOT\r\n" to serial */
    movw $0x3F8, %dx
    movb $'B', %al
    outb %al, %dx
    movb $'O', %al
    outb %al, %dx
    movb $'O', %al
    outb %al, %dx
    movb $'T', %al
    outb %al, %dx
    movb $'\r', %al
    outb %al, %dx
    movb $'\n', %al
    outb %al, %dx

    /* ── Set up IDT with ISR stubs before calling kernel ── */
    call setup_idt

    /* ── Initialize TSS and reload GDT with TSS descriptor ── */
    call init_tss

    /* ── Set up SYSCALL/SYSRET MSRs ── */
    call init_syscall

    /* ── Call C++ static constructors (.init_array) ──
     * This initializes global objects like fontData, exceptionNames,
     * scancodeToAscii, etc. Must happen before kernel_main, just
     * like a hosted C++ runtime calls constructors before main().
     * Save rbx (BootInfo pointer) across the calls.
     */
    pushq %rbx                          /* preserve BootInfo pointer */
    subq  $8, %rsp                      /* align stack to 16 bytes for ABI */

    leaq __init_array_start(%rip), %r14
    leaq __init_array_end(%rip), %r15
.Linit_ctors_loop:
    cmpq %r15, %r14
    jge  .Linit_ctors_done
    movq (%r14), %rax
    call *%rax
    addq $8, %r14
    jmp  .Linit_ctors_loop
.Linit_ctors_done:

    addq  $8, %rsp                      /* undo alignment padding */
    popq %rbx                           /* restore BootInfo pointer */

    /* Call kernel_main(bootInfoAddr) */
    movq %rbx, %rdi         /* First arg: pointer to BootInfo (as long) */
    call kernel_main

    /* Print "HALT\r\n" — kernel_main returned */
    movw $0x3F8, %dx
    movb $'H', %al
    outb %al, %dx
    movb $'A', %al
    outb %al, %dx
    movb $'L', %al
    outb %al, %dx
    movb $'T', %al
    outb %al, %dx
    movb $'\r', %al
    outb %al, %dx
    movb $'\n', %al
    outb %al, %dx

    /* Halt if kernel returns */
.halt:
    cli
    hlt
    jmp .halt

/* ============================================================================
 * ISR Stubs — One per vector (0-47), plus a default for 48-255
 *
 * Each stub pushes a dummy error code (if CPU doesn't push one),
 * pushes the vector number, and jumps to the common handler.
 * ============================================================================ */

/* Macro for ISR without error code (most vectors) */
.macro ISR_NOERRCODE vector
.global isr_stub_\vector
isr_stub_\vector:
    pushq $0                /* dummy error code */
    pushq $\vector          /* vector number */
    jmp isr_common
.endm

/* Macro for ISR with error code (CPU pushes it) */
.macro ISR_ERRCODE vector
.global isr_stub_\vector
isr_stub_\vector:
    pushq $\vector          /* vector number (error code already on stack) */
    jmp isr_common
.endm

/* Exception vectors 0-31 */
ISR_NOERRCODE 0             /* Division Error */
ISR_NOERRCODE 1             /* Debug */
ISR_NOERRCODE 2             /* NMI */
ISR_NOERRCODE 3             /* Breakpoint */
ISR_NOERRCODE 4             /* Overflow */
ISR_NOERRCODE 5             /* Bound Range Exceeded */
ISR_NOERRCODE 6             /* Invalid Opcode */
ISR_NOERRCODE 7             /* Device Not Available */
ISR_ERRCODE   8             /* Double Fault */
ISR_NOERRCODE 9             /* Coprocessor Segment Overrun */
ISR_ERRCODE   10            /* Invalid TSS */
ISR_ERRCODE   11            /* Segment Not Present */
ISR_ERRCODE   12            /* Stack-Segment Fault */
ISR_ERRCODE   13            /* General Protection Fault */
ISR_ERRCODE   14            /* Page Fault */
ISR_NOERRCODE 15            /* Reserved */
ISR_NOERRCODE 16            /* x87 FPU Error */
ISR_ERRCODE   17            /* Alignment Check */
ISR_NOERRCODE 18            /* Machine Check */
ISR_NOERRCODE 19            /* SIMD Exception */
ISR_NOERRCODE 20            /* Virtualization */
ISR_ERRCODE   21            /* Control Protection */
ISR_NOERRCODE 22
ISR_NOERRCODE 23
ISR_NOERRCODE 24
ISR_NOERRCODE 25
ISR_NOERRCODE 26
ISR_NOERRCODE 27
ISR_NOERRCODE 28
ISR_NOERRCODE 29
ISR_ERRCODE   30            /* Security Exception */
ISR_NOERRCODE 31

/* IRQ vectors 32-47 (after PIC remap) */
ISR_NOERRCODE 32            /* IRQ0 - Timer */
ISR_NOERRCODE 33            /* IRQ1 - Keyboard */
ISR_NOERRCODE 34
ISR_NOERRCODE 35
ISR_NOERRCODE 36
ISR_NOERRCODE 37
ISR_NOERRCODE 38
ISR_NOERRCODE 39
ISR_NOERRCODE 40
ISR_NOERRCODE 41
ISR_NOERRCODE 42
ISR_NOERRCODE 43
ISR_NOERRCODE 44
ISR_NOERRCODE 45
ISR_NOERRCODE 46
ISR_NOERRCODE 47

/* Common ISR handler — saves all registers, calls C dispatch, restores */
isr_common:
    /* Save all general-purpose registers */
    pushq %rax
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rsi
    pushq %rdi
    pushq %rbp
    pushq %r8
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    /* Set up C calling convention args:
     * Stack layout at this point:
     *   [rsp+0]   = r15 (just pushed)
     *   [rsp+8]   = r14
     *   ...       = (13 more regs, each 8 bytes = 15 regs × 8 = 120 bytes)
     *   [rsp+120] = vector number
     *   [rsp+128] = error code
     *   [rsp+136] = RIP (from interrupt)
     *   [rsp+144] = CS
     *   [rsp+152] = RFLAGS
     *   [rsp+160] = RSP
     *   [rsp+168] = SS
     */
    movq 120(%rsp), %rdi    /* First arg: vector number */
    movq 128(%rsp), %rsi    /* Second arg: error code */
    call isr_dispatch

    /* Restore all general-purpose registers */
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %r8
    popq %rbp
    popq %rdi
    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    popq %rax

    addq $16, %rsp          /* Remove vector number and error code */
    iretq

/* ============================================================================
 * setup_idt — Fill IDT entries with ISR stub addresses
 *
 * Called from boot stub before kernel_main. Fills the IDT in BSS
 * with entries pointing to isr_stub_0 through isr_stub_47.
 * ============================================================================ */
.global setup_idt
setup_idt:
    pushq %rbx
    pushq %r12
    pushq %r13

    /* IDT is in BSS (idt_table symbol, 256 entries × 16 bytes) */
    leaq idt_table(%rip), %rbx

    /* Zero out entire IDT first (256 × 16 = 4096 bytes) */
    movq %rbx, %rdi
    xorq %rax, %rax
    movl $512, %ecx         /* 4096 / 8 = 512 qwords */
    rep stosq

    /* Fill entries 0-47 from the ISR stub table */
    leaq isr_stub_table(%rip), %r12
    xorq %r13, %r13         /* counter = 0 */

.fill_loop:
    cmpq $48, %r13
    jge .fill_done

    /* Get stub address from table */
    movq (%r12,%r13,8), %rax

    /* Calculate IDT entry address: base + vector * 16 */
    movq %r13, %rcx
    shlq $4, %rcx
    leaq (%rbx,%rcx), %rdi

    /* Set IDT entry fields:
     *   [0-1]   offset_low  (bits 0..15)
     *   [2-3]   selector    (0x08 = code segment)
     *   [4]     IST         (0)
     *   [5]     type_attr   (0x8E = present, DPL=0, interrupt gate)
     *   [6-7]   offset_mid  (bits 16..31)
     *   [8-11]  offset_high (bits 32..63)
     *   [12-15] reserved    (0)
     */
    movw %ax, 0(%rdi)       /* offset_low */
    movw $0x08, 2(%rdi)     /* code segment selector */
    movb $0, 4(%rdi)        /* IST = 0 */
    movb $0x8E, 5(%rdi)     /* type_attr (interrupt gate, present) */
    movq %rax, %rcx
    shrq $16, %rcx
    movw %cx, 6(%rdi)       /* offset_mid */
    shrq $16, %rcx
    movl %ecx, 8(%rdi)      /* offset_high */
    movl $0, 12(%rdi)       /* reserved */

    incq %r13
    jmp .fill_loop

.fill_done:
    /* Debug: write "IDT\r\n" to serial to confirm IDT setup complete */
    movw $0x3F8, %dx
    movb $'I', %al
    outb %al, %dx
    movb $'D', %al
    outb %al, %dx
    movb $'T', %al
    outb %al, %dx
    movb $'\r', %al
    outb %al, %dx
    movb $'\n', %al
    outb %al, %dx

    /* Load IDT register */
    /* Use idt_pointer in BSS for IDTR (2 bytes limit + 8 bytes base) */
    leaq idt_pointer(%rip), %rdi
    movw $4095, (%rdi)       /* limit = 256*16 - 1 */
    movq %rbx, 2(%rdi)       /* base = idt_table address */
    lidt (%rdi)

    popq %r13
    popq %r12
    popq %rbx
    ret

/* ISR stub address table */
.section .data
.align 8
isr_stub_table:
    .quad isr_stub_0,  isr_stub_1,  isr_stub_2,  isr_stub_3
    .quad isr_stub_4,  isr_stub_5,  isr_stub_6,  isr_stub_7
    .quad isr_stub_8,  isr_stub_9,  isr_stub_10, isr_stub_11
    .quad isr_stub_12, isr_stub_13, isr_stub_14, isr_stub_15
    .quad isr_stub_16, isr_stub_17, isr_stub_18, isr_stub_19
    .quad isr_stub_20, isr_stub_21, isr_stub_22, isr_stub_23
    .quad isr_stub_24, isr_stub_25, isr_stub_26, isr_stub_27
    .quad isr_stub_28, isr_stub_29, isr_stub_30, isr_stub_31
    .quad isr_stub_32, isr_stub_33, isr_stub_34, isr_stub_35
    .quad isr_stub_36, isr_stub_37, isr_stub_38, isr_stub_39
    .quad isr_stub_40, isr_stub_41, isr_stub_42, isr_stub_43
    .quad isr_stub_44, isr_stub_45, isr_stub_46, isr_stub_47

/* ============================================================================
 * init_tss — Set up the Task State Segment and load it into the GDT
 *
 * The TSS is required for Ring 3 → Ring 0 transitions. When a syscall
 * or interrupt occurs from user mode, the CPU loads RSP0 from the TSS
 * to switch to the kernel stack.
 * ============================================================================ */
.section .text
.global init_tss
init_tss:
    pushq %rbx
    pushq %rcx
    pushq %rdx

    /* Zero the TSS */
    leaq tss_block(%rip), %rdi
    xorq %rax, %rax
    movl $13, %ecx          /* 104 / 8 = 13 qwords */
    rep stosq

    /* Set RSP0 (kernel stack for ring 0) — offset 0x04 in TSS */
    leaq tss_block(%rip), %rbx
    leaq syscall_kernel_stack_top(%rip), %rax
    movq %rax, 4(%rbx)      /* TSS.RSP0 */

    /* Set IST1 (interrupt stack for double fault, etc.) — offset 0x24 */
    leaq ist1_stack_top(%rip), %rax
    movq %rax, 36(%rbx)     /* TSS.IST1 */

    /* Set IOPB offset past TSS size (no I/O bitmap) */
    movw $104, 102(%rbx)    /* IOPB offset at byte 102 */

    /* Now install TSS descriptor into GDT at offset 0x28 (entry 5)
     * 64-bit TSS descriptor is 16 bytes:
     *   Bytes 0-1:  limit low (103 = 0x0067)
     *   Bytes 2-3:  base low
     *   Byte 4:     base mid
     *   Byte 5:     access (0x89 = present, DPL=0, 64-bit TSS available)
     *   Byte 6:     flags + limit high (0x00)
     *   Byte 7:     base mid-high
     *   Bytes 8-11: base high
     *   Bytes 12-15: reserved (0)
     */
    leaq gdt64(%rip), %rdi
    addq $0x28, %rdi         /* Point to TSS entry in GDT */

    movq %rbx, %rax          /* RAX = TSS base address */

    /* Word 0: limit low = 103 */
    movw $103, 0(%rdi)

    /* Word 1: base[15:0] */
    movw %ax, 2(%rdi)

    /* Byte 4: base[23:16] */
    movq %rax, %rcx
    shrq $16, %rcx
    movb %cl, 4(%rdi)

    /* Byte 5: access byte = 0x89 (present, DPL=0, 64-bit TSS) */
    movb $0x89, 5(%rdi)

    /* Byte 6: flags (0) | limit high (0) = 0x00 */
    movb $0x00, 6(%rdi)

    /* Byte 7: base[31:24] */
    shrq $8, %rcx
    movb %cl, 7(%rdi)

    /* Dword at offset 8: base[63:32] */
    movq %rax, %rcx
    shrq $32, %rcx
    movl %ecx, 8(%rdi)

    /* Dword at offset 12: reserved = 0 */
    movl $0, 12(%rdi)

    /* Reload GDT with the 64-bit pointer (needed for TSS entries) */
    leaq gdt64_ptr64(%rip), %rax
    lgdt (%rax)

    /* Load Task Register with TSS selector (0x28) */
    movw $0x28, %ax
    ltr %ax

    /* Serial debug: "TSS\r\n" */
    movw $0x3F8, %dx
    movb $'T', %al
    outb %al, %dx
    movb $'S', %al
    outb %al, %dx
    movb $'S', %al
    outb %al, %dx
    movb $'\r', %al
    outb %al, %dx
    movb $'\n', %al
    outb %al, %dx

    popq %rdx
    popq %rcx
    popq %rbx
    ret

/* ============================================================================
 * init_syscall — Set up SYSCALL/SYSRET MSRs
 *
 * MSRs configured:
 *   STAR  (0xC0000081): Segment selectors for SYSCALL/SYSRET
 *   LSTAR (0xC0000082): RIP loaded on SYSCALL (our handler)
 *   SFMASK(0xC0000084): RFLAGS bits cleared on SYSCALL
 *   EFER  (0xC0000080): Enable SCE (SYSCALL Enable) bit
 * ============================================================================ */
.global init_syscall
init_syscall:
    pushq %rcx
    pushq %rdx

    /* STAR MSR: [63:48] = SYSRET CS base, [47:32] = SYSCALL CS
     * SYSCALL: CS = 0x08, SS = CS+8 = 0x10
     * SYSRET:  CS = 0x10+16 = 0x20 (| RPL3 = 0x23), SS = 0x10+8 = 0x18 (| RPL3 = 0x1B)
     */
    movl $0xC0000081, %ecx   /* STAR MSR */
    xorl %eax, %eax          /* Low 32 bits: reserved (0) */
    movl $0x00100008, %edx   /* High 32 bits: SYSRET_CS_BASE(0x10) | SYSCALL_CS(0x08) */
    wrmsr

    /* LSTAR MSR: Address of syscall entry point */
    movl $0xC0000082, %ecx
    leaq syscall_entry(%rip), %rdx
    movq %rdx, %rax
    /* EDX:EAX = 64-bit address split into high:low */
    shrq $32, %rdx           /* EDX = high 32 bits */
    /* EAX already has low 32 bits (movq copies full, low 32 suffice) */
    wrmsr

    /* SFMASK MSR: Clear IF (bit 9) and DF (bit 10) on SYSCALL */
    movl $0xC0000084, %ecx
    movl $(1 << 9) | (1 << 10), %eax   /* Clear IF + DF */
    xorl %edx, %edx
    wrmsr

    /* Enable SYSCALL by setting SCE (bit 0) in EFER MSR */
    movl $0xC0000080, %ecx
    rdmsr
    orl $1, %eax             /* Set SCE bit */
    wrmsr

    /* Serial debug: "SYS\r\n" */
    movw $0x3F8, %dx
    movb $'S', %al
    outb %al, %dx
    movb $'Y', %al
    outb %al, %dx
    movb $'S', %al
    outb %al, %dx
    movb $'\r', %al
    outb %al, %dx
    movb $'\n', %al
    outb %al, %dx

    popq %rdx
    popq %rcx
    ret

/* ============================================================================
 * syscall_entry — SYSCALL handler entry point
 *
 * On SYSCALL:
 *   RCX = saved RIP (return address)
 *   R11 = saved RFLAGS
 *   RAX = syscall number
 *   RDI, RSI, RDX, R10, R8, R9 = arguments (Linux x86_64 ABI)
 *
 * We switch to the kernel stack (from TSS RSP0), save user state,
 * call the C handler, restore state, and SYSRETQ back.
 * ============================================================================ */
.global syscall_entry
syscall_entry:
    /* ── STATE ON ENTRY ──
     * Ring 0, interrupts disabled (SFMASK cleared IF).
     * RCX = user RIP, R11 = user RFLAGS.
     * RSP = still user stack. All other GPRs untouched.
     * RAX = syscall number.
     * Linux x86_64 syscall ABI: args in RDI, RSI, RDX, R10, R8, R9.
     */

    /* Save user RSP, switch to kernel stack */
    movq %rsp, %r15
    leaq syscall_kernel_stack_top(%rip), %rsp

    /* Push iret-style frame (for potential iretq fallback) */
    pushq $0x1B              /* User SS  (0x18 | 3) */
    pushq %r15               /* User RSP */
    pushq %r11               /* User RFLAGS */
    pushq $0x23              /* User CS  (0x20 | 3) */
    pushq %rcx               /* User RIP */

    /* Save all GPRs */
    pushq %rax
    pushq %rbx
    pushq %rcx
    pushq %rdx
    pushq %rsi
    pushq %rdi
    pushq %rbp
    pushq %r8
    pushq %r9
    pushq %r10
    pushq %r11
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    /* ── Stack layout (each slot 8 bytes) ──
     *  [rsp+0]   r15         (slot 0)
     *  [rsp+8]   r14         (slot 1)
     *  [rsp+16]  r13         (slot 2)
     *  [rsp+24]  r12         (slot 3)
     *  [rsp+32]  r11         (slot 4)
     *  [rsp+40]  r10         (slot 5)
     *  [rsp+48]  r9          (slot 6)
     *  [rsp+56]  r8          (slot 7)
     *  [rsp+64]  rbp         (slot 8)
     *  [rsp+72]  rdi         (slot 9)   = Linux arg1
     *  [rsp+80]  rsi         (slot 10)  = Linux arg2
     *  [rsp+88]  rdx         (slot 11)  = Linux arg3
     *  [rsp+96]  rcx         (slot 12)
     *  [rsp+104] rbx         (slot 13)
     *  [rsp+112] rax         (slot 14)  = syscall number
     *  [rsp+120] user RIP    (slot 15)
     *  [rsp+128] user CS     (slot 16)
     *  [rsp+136] user RFLAGS (slot 17)
     *  [rsp+144] user RSP    (slot 18)
     *  [rsp+152] user SS     (slot 19)
     */

    /* Re-enable interrupts */
    sti

    /* Map to C calling convention:
     * syscall_dispatch(number, a1, a2, a3, a4, a5)
     * C ABI: RDI, RSI, RDX, RCX, R8, R9
     *
     * Linux:  RAX=number, RDI=a1, RSI=a2, RDX=a3, R10=a4, R8=a5
     */
    movq 112(%rsp), %rdi     /* C arg0 = syscall number (saved RAX) */
    movq 72(%rsp),  %rsi     /* C arg1 = user RDI */
    movq 80(%rsp),  %rdx     /* C arg2 = user RSI */
    movq 88(%rsp),  %rcx     /* C arg3 = user RDX */
    movq 40(%rsp),  %r8      /* C arg4 = user R10 */
    movq 56(%rsp),  %r9      /* C arg5 = user R8 */

    call syscall_dispatch

    /* Disable interrupts for return sequence */
    cli

    /* Store return value into saved RAX slot */
    movq %rax, 112(%rsp)

    /* Restore all GPRs */
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %r11
    popq %r10
    popq %r9
    popq %r8
    popq %rbp
    popq %rdi
    popq %rsi
    popq %rdx
    popq %rcx
    popq %rbx
    popq %rax               /* Contains syscall return value */

    /* Stack now: user_RIP, user_CS, user_RFLAGS, user_RSP, user_SS */
    popq %rcx                /* User RIP → RCX for SYSRETQ */
    addq $8, %rsp            /* Skip user CS */
    popq %r11                /* User RFLAGS → R11 for SYSRETQ */
    popq %rsp                /* Restore user RSP */

    sysretq

/* ============================================================================
 * jump_to_usermode — Transfer execution from Ring 0 to Ring 3
 *
 * Called from C: jump_to_usermode(long entry, long userStack)
 *   RDI = user-mode entry point
 *   RSI = user-mode stack pointer
 *
 * Uses IRETQ to transition: pushes SS, RSP, RFLAGS, CS, RIP,
 * then iretq pops them into the CPU, switching to Ring 3.
 * ============================================================================ */
.global jump_to_usermode
jump_to_usermode:
    cli

    /* Build an iret frame on the kernel stack */
    pushq $0x1B              /* User SS  (0x18 | 3) */
    pushq %rsi               /* User RSP */
    pushfq
    popq %rax
    orq $(1 << 9), %rax      /* Ensure IF (interrupts) is set */
    pushq %rax               /* User RFLAGS */
    pushq $0x23              /* User CS  (0x20 | 3) */
    pushq %rdi               /* User RIP (entry point) */

    /* Zero all GPRs for a clean entry environment */
    xorq %rax, %rax
    xorq %rbx, %rbx
    xorq %rcx, %rcx
    xorq %rdx, %rdx
    xorq %rsi, %rsi
    xorq %rdi, %rdi
    xorq %rbp, %rbp
    xorq %r8,  %r8
    xorq %r9,  %r9
    xorq %r10, %r10
    xorq %r11, %r11
    xorq %r12, %r12
    xorq %r13, %r13
    xorq %r14, %r14
    xorq %r15, %r15

    iretq

/* ============================================================================
 * call_elf_ring0 — Execute an ELF entry point in Ring 0 (trusted mode)
 *
 * Called from C: call_elf_ring0(long entry, long stack, long arg)
 *   RDI = entry point
 *   RSI = stack pointer for the ELF
 *   RDX = argument (passed as RDI to the entry point)
 * ============================================================================ */
.global call_elf_ring0
call_elf_ring0:
    /* Save callee-saved registers */
    pushq %rbx
    pushq %rbp
    pushq %r12
    pushq %r13
    pushq %r14
    pushq %r15

    /* Save current RSP so we can return */
    movq %rsp, %r15

    /* Switch to the ELF's stack */
    movq %rsi, %rsp

    /* Set up the argument (pass as RDI to the entry) */
    movq %rdx, %rdi

    /* Call the entry point (it should return normally) */
    call *%rdi

    /* Restore kernel RSP */
    movq %r15, %rsp

    /* Restore callee-saved registers */
    popq %r15
    popq %r14
    popq %r13
    popq %r12
    popq %rbp
    popq %rbx

    ret

/* ============================================================================
 * Data
 * ============================================================================ */
.section .data

.align 4
mb_info_ptr:
    .long 0

/* 64-bit GDT
 *
 * Layout (SYSCALL/SYSRET compatible):
 *   0x00  Null descriptor
 *   0x08  Kernel Code  — 64-bit, DPL=0, execute/read
 *   0x10  Kernel Data  — 64-bit, DPL=0, read/write
 *   0x18  User Data    — 64-bit, DPL=3, read/write   (SYSRET SS = STAR_HI+8 | 3)
 *   0x20  User Code    — 64-bit, DPL=3, execute/read  (SYSRET CS = STAR_HI+16 | 3)
 *   0x28  TSS low      — 64-bit TSS descriptor (first 8 bytes)
 *   0x30  TSS high     — 64-bit TSS descriptor (upper 8 bytes)
 *
 * STAR MSR = (0x10 << 48) | (0x08 << 32)
 *   SYSCALL: CS=0x08, SS=0x10  (kernel)
 *   SYSRET:  CS=0x23, SS=0x1B  (user, RPL=3)
 */
.align 16
gdt64:
    .quad 0x0000000000000000  /* 0x00: Null descriptor */
    .quad 0x00AF9A000000FFFF  /* 0x08: Kernel Code — 64-bit, DPL=0, execute/read */
    .quad 0x00AF92000000FFFF  /* 0x10: Kernel Data — 64-bit, DPL=0, read/write */
    .quad 0x00AFF2000000FFFF  /* 0x18: User Data   — 64-bit, DPL=3, read/write */
    .quad 0x00AFFA000000FFFF  /* 0x20: User Code   — 64-bit, DPL=3, execute/read */
    .quad 0                   /* 0x28: TSS low  (filled at runtime by init_tss) */
    .quad 0                   /* 0x30: TSS high (filled at runtime by init_tss) */
gdt64_end:

gdt64_ptr:
    .word gdt64_end - gdt64 - 1
    .long gdt64

/* 64-bit GDT pointer (used when reloading GDT in long mode) */
.align 16
gdt64_ptr64:
    .word gdt64_end - gdt64 - 1
    .quad gdt64

/* ============================================================================
 * BSS — Page tables and stack
 * ============================================================================ */
.section .bss
.align 4096

/* Page tables for identity mapping 4GB */
pml4:
    .skip 4096
pdpt:
    .skip 4096
pd0:
    .skip 4096
pd1:
    .skip 4096
pd2:
    .skip 4096
pd3:
    .skip 4096
page_tables_end:

/* Interrupt Descriptor Table (256 entries × 16 bytes = 4KB) */
.align 4096
.global idt_table
idt_table:
    .skip 4096

/* IDTR pointer structure (10 bytes: 2-byte limit + 8-byte base) */
.align 16
idt_pointer:
    .skip 16

/* Task State Segment (104 bytes minimum for x86_64)
 * Layout:
 *   0x00  uint32  reserved0
 *   0x04  uint64  RSP0  (kernel stack pointer for ring 0)
 *   0x0C  uint64  RSP1
 *   0x14  uint64  RSP2
 *   0x1C  uint64  reserved1
 *   0x24  uint64  IST1  (interrupt stack table entries)
 *   0x2C  uint64  IST2
 *   0x34  uint64  IST3
 *   0x3C  uint64  IST4
 *   0x44  uint64  IST5
 *   0x4C  uint64  IST6
 *   0x54  uint64  IST7
 *   0x5C  uint64  reserved2
 *   0x64  uint16  reserved3
 *   0x66  uint16  IOPB offset
 */
.align 16
.global tss_block
tss_block:
    .skip 104

/* Separate kernel stacks for syscall and IST (16KB each) */
.align 4096
.global syscall_kernel_stack_bottom
syscall_kernel_stack_bottom:
    .skip 16384
.global syscall_kernel_stack_top
syscall_kernel_stack_top:

.align 4096
.global ist1_stack_bottom
ist1_stack_bottom:
    .skip 16384
ist1_stack_top:

/* Kernel stack (256KB — SSE register saves + FluxString locals need large stack) */
.align 4096
stack_bottom:
    .skip 262144
stack_top:

/* Mark stack as non-executable (suppresses ld warning) */
.section .note.GNU-stack,"",@progbits
