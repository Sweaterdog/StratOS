; ============================================================================
; StratOS Legacy BIOS Bootloader — Stage 2
; Target: x86 Real Mode → Protected Mode → Long Mode
;
; Stage 2 responsibilities:
;   1. Enable A20 line
;   2. Detect available memory (E820)
;   3. Set up VESA/VBE graphics mode (auto-detect best resolution)
;   4. Build page tables for long mode
;   5. Enter Protected Mode → Long Mode
;   6. Jump to kernel at 0x100000 (1MB)
; ============================================================================

BITS 16
ORG 0x10000                     ; Loaded at segment 0x1000:0x0000

KERNEL_LOAD_ADDR equ 0x100000   ; 1MB — same as UEFI path

stage2_entry:
    ; Set up segments for stage 2
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov si, stage2_banner
    call print_string_16

    ; ----- Enable A20 Line -----
    call enable_a20
    mov si, a20_ok_msg
    call print_string_16

    ; ----- Detect Memory (E820) -----
    call detect_memory
    mov si, mem_ok_msg
    call print_string_16

    ; ----- Set VESA Graphics Mode -----
    call setup_vesa
    mov si, vesa_ok_msg
    call print_string_16

    ; ----- Build Page Tables -----
    call setup_page_tables
    mov si, paging_ok_msg
    call print_string_16

    ; ----- Enter Long Mode -----
    mov si, longmode_msg
    call print_string_16

    ; Disable interrupts for mode switch
    cli

    ; Load GDT
    lgdt [gdt64_pointer]

    ; Enable PAE in CR4
    mov eax, cr4
    or eax, (1 << 5)           ; PAE bit
    mov cr4, eax

    ; Set PML4 table address in CR3
    mov eax, pml4_table
    mov cr3, eax

    ; Enable long mode via IA32_EFER MSR
    mov ecx, 0xC0000080         ; IA32_EFER
    rdmsr
    or eax, (1 << 8)           ; LME (Long Mode Enable)
    wrmsr

    ; Enable paging + protected mode
    mov eax, cr0
    or eax, (1 << 31) | (1 << 0)  ; PG | PE
    mov cr0, eax

    ; Far jump to 64-bit code
    jmp 0x08:long_mode_entry

; ============================================================================
; enable_a20 - Enable the A20 address line
; ============================================================================
enable_a20:
    ; Try BIOS method first
    mov ax, 0x2401
    int 0x15
    jnc .a20_done

    ; Fast A20 gate (port 0x92)
    in al, 0x92
    or al, 2
    and al, 0xFE                ; Don't trigger reset
    out 0x92, al

.a20_done:
    ret

; ============================================================================
; detect_memory - Use INT 15h E820 to build memory map
; ============================================================================
detect_memory:
    mov di, e820_map
    xor ebx, ebx               ; continuation = 0 (start)
    mov edx, 0x534D4150         ; 'SMAP'
    xor bp, bp                  ; entry counter

.e820_loop:
    mov eax, 0xE820
    mov ecx, 24                 ; Entry size
    int 0x15

    jc .e820_done               ; Carry = error or end
    cmp eax, 0x534D4150
    jne .e820_done

    ; Valid entry
    inc bp
    add di, 24

    ; Check if more entries
    test ebx, ebx
    jz .e820_done
    jmp .e820_loop

.e820_done:
    mov [e820_count], bp
    ret

; ============================================================================
; setup_vesa - Auto-detect and set best VESA graphics mode
; ============================================================================
setup_vesa:
    ; Get VBE Controller Info
    mov ax, 0x4F00
    mov di, vbe_info_block
    int 0x10
    cmp ax, 0x004F
    jne .vesa_fail

    ; Scan mode list for best resolution
    mov si, [vbe_info_block + 14]   ; Pointer to mode list
    mov ax, [vbe_info_block + 16]   ; Segment of mode list
    mov fs, ax

    xor edx, edx               ; best_pixels = 0
    mov word [best_vesa_mode], 0xFFFF

.scan_loop:
    mov cx, [fs:si]
    cmp cx, 0xFFFF              ; End of list sentinel
    je .set_mode
    
    ; Get mode info
    push si
    push edx
    mov ax, 0x4F01
    mov di, vbe_mode_info
    int 0x10
    pop edx
    pop si

    cmp ax, 0x004F
    jne .next_vesa_mode

    ; Check: must be graphics mode with linear framebuffer
    mov al, [vbe_mode_info + 0]     ; ModeAttributes
    test al, (1 << 4)              ; Graphics mode?
    jz .next_vesa_mode
    test al, (1 << 7)              ; Linear framebuffer?
    jz .next_vesa_mode

    ; Check bits per pixel (want 32bpp)
    cmp byte [vbe_mode_info + 25], 32
    jne .next_vesa_mode

    ; Calculate total pixels
    movzx eax, word [vbe_mode_info + 18]  ; XResolution
    movzx ebx, word [vbe_mode_info + 20]  ; YResolution
    imul eax, ebx

    ; Is this the best so far?
    cmp eax, edx
    jle .next_vesa_mode

    ; New best mode
    mov edx, eax
    mov [best_vesa_mode], cx
    
    ; Save mode details
    movzx eax, word [vbe_mode_info + 18]
    mov [vesa_width], eax
    movzx eax, word [vbe_mode_info + 20]
    mov [vesa_height], eax
    movzx eax, word [vbe_mode_info + 16]  ; BytesPerScanLine
    mov [vesa_pitch], eax
    mov eax, [vbe_mode_info + 40]          ; PhysBasePtr (framebuffer)
    mov [vesa_framebuffer], eax

.next_vesa_mode:
    add si, 2
    jmp .scan_loop

.set_mode:
    ; Set the best mode we found
    mov ax, 0x4F02
    mov bx, [best_vesa_mode]
    or bx, (1 << 14)           ; Enable linear framebuffer
    int 0x10
    ret

.vesa_fail:
    ; Fall back to VGA 320x200 mode 13h
    mov ax, 0x0013
    int 0x10
    mov dword [vesa_width], 320
    mov dword [vesa_height], 200
    mov dword [vesa_pitch], 320
    mov dword [vesa_framebuffer], 0xA0000
    ret

; ============================================================================
; setup_page_tables - Identity-map first 4GB for long mode
; ============================================================================
setup_page_tables:
    ; Zero out page table area
    mov edi, pml4_table
    mov ecx, 4096
    xor eax, eax
    rep stosd

    ; PML4[0] -> PDPT
    mov dword [pml4_table], pdpt_table | 0x03       ; Present + Writable

    ; PDPT[0..3] -> PD (4 entries = 4GB with 2MB pages)
    mov dword [pdpt_table + 0],  pd_table | 0x03
    mov dword [pdpt_table + 8],  pd_table + 0x1000 | 0x03
    mov dword [pdpt_table + 16], pd_table + 0x2000 | 0x03
    mov dword [pdpt_table + 24], pd_table + 0x3000 | 0x03

    ; PD entries: 2MB pages, identity-mapped
    mov edi, pd_table
    mov eax, 0x83               ; Present + Writable + PageSize (2MB)
    mov ecx, 2048               ; 2048 entries * 2MB = 4GB
.fill_pd:
    mov [edi], eax
    add eax, 0x200000           ; Next 2MB
    add edi, 8
    loop .fill_pd

    ret

; ============================================================================
; print_string_16 - Print null-terminated string (16-bit real mode)
; ============================================================================
print_string_16:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bx, 0x0007
    int 0x10
    jmp .loop
.done:
    popa
    ret

; ============================================================================
; 64-bit Long Mode Code
; ============================================================================
BITS 64

long_mode_entry:
    ; Set up 64-bit segment registers
    mov ax, 0x10                ; Data segment
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; Set up a proper stack
    mov rsp, 0x90000

    ; ----- Build BootInfo struct (same layout as UEFI) -----
    mov rdi, boot_info_64

    ; Framebuffer
    mov eax, [vesa_framebuffer]
    mov [rdi], rax              ; framebuffer_base (zero-extended)
    
    ; Framebuffer size = pitch * height
    mov eax, [vesa_pitch]
    mov ecx, [vesa_height]
    imul eax, ecx
    mov [rdi + 8], eax          ; framebuffer_size

    ; Resolution
    mov eax, [vesa_width]
    mov [rdi + 12], eax         ; screen_width
    mov eax, [vesa_height]
    mov [rdi + 16], eax         ; screen_height
    mov eax, [vesa_pitch]
    shr eax, 2                  ; bytes_per_scanline / 4 = pixels_per_scanline
    mov [rdi + 20], eax         ; pixels_per_scanline

    ; Memory map
    lea rax, [e820_map]
    mov [rdi + 24], rax         ; memory_map pointer
    movzx eax, word [e820_count]
    imul eax, 24                ; total size in bytes
    mov [rdi + 32], eax         ; memory_map_size
    mov dword [rdi + 36], 24    ; memory_map_desc_size
    mov dword [rdi + 40], 0     ; memory_map_key (N/A for BIOS)

    ; Jump to kernel
    mov rax, KERNEL_LOAD_ADDR
    jmp rax

; ============================================================================
; GDT for 64-bit Long Mode
; ============================================================================
align 16
gdt64:
    dq 0                        ; Null descriptor
.code: equ $ - gdt64
    dq 0x00AF9A000000FFFF       ; 64-bit code segment
.data: equ $ - gdt64
    dq 0x00CF92000000FFFF       ; 64-bit data segment
gdt64_end:

gdt64_pointer:
    dw gdt64_end - gdt64 - 1   ; Limit
    dd gdt64                    ; Base

; ============================================================================
; Data Section
; ============================================================================
align 16

stage2_banner:
    db 0x0D, 0x0A
    db '  StratOS Stage 2 Loader', 0x0D, 0x0A, 0

a20_ok_msg:
    db '  [OK] A20 line enabled', 0x0D, 0x0A, 0

mem_ok_msg:
    db '  [OK] Memory detected (E820)', 0x0D, 0x0A, 0

vesa_ok_msg:
    db '  [OK] VESA graphics initialized', 0x0D, 0x0A, 0

paging_ok_msg:
    db '  [OK] Page tables built (4GB identity map)', 0x0D, 0x0A, 0

longmode_msg:
    db '  [..] Entering 64-bit Long Mode...', 0x0D, 0x0A, 0

; VBE data
align 4
vbe_info_block: times 512 db 0
vbe_mode_info:  times 256 db 0
best_vesa_mode: dw 0
vesa_width:     dd 0
vesa_height:    dd 0
vesa_pitch:     dd 0
vesa_framebuffer: dd 0

; E820 memory map (max 64 entries * 24 bytes)
e820_map:   times (64 * 24) db 0
e820_count: dw 0

; Boot info struct for kernel (64 bytes)
boot_info_64: times 64 db 0

; ============================================================================
; Page Tables (must be page-aligned)
; ============================================================================
align 4096
pml4_table: times 4096 db 0
pdpt_table: times 4096 db 0
pd_table:   times (4096 * 4) db 0   ; 4 page directories for 4GB
