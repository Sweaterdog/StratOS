; ============================================================================
; StratOS Legacy BIOS Bootloader — Stage 1 (MBR)
; Target: x86 Real Mode → Protected Mode → Long Mode
; Size: 512 bytes (fits in MBR)
;
; Stage 1 responsibilities:
;   1. Set up segments and stack
;   2. Load Stage 2 from disk (sectors 2+)
;   3. Jump to Stage 2
; ============================================================================

BITS 16
ORG 0x7C00

STAGE2_LOAD_SEG equ 0x1000
STAGE2_LOAD_OFF equ 0x0000
STAGE2_SECTORS  equ 32          ; Load 16KB for stage2

; ============================================================================
; Entry Point
; ============================================================================
start:
    ; Disable interrupts during setup
    cli
    
    ; Set up segments
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              ; Stack grows down from bootloader
    
    ; Re-enable interrupts
    sti
    
    ; Save boot drive number
    mov [boot_drive], dl
    
    ; Clear screen
    mov ax, 0x0003              ; 80x25 text mode, clear screen
    int 0x10
    
    ; Print banner
    mov si, banner
    call print_string
    
    ; ----- Load Stage 2 from disk -----
    mov si, loading_msg
    call print_string
    
    ; Use INT 13h Extended Read (LBA)
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap                 ; Disk Address Packet
    int 0x13
    jc disk_error
    
    ; Print success
    mov si, ok_msg
    call print_string
    
    ; Jump to Stage 2
    jmp STAGE2_LOAD_SEG:STAGE2_LOAD_OFF
    
disk_error:
    mov si, disk_err_msg
    call print_string
    jmp halt

halt:
    cli
    hlt
    jmp halt

; ============================================================================
; print_string - Print null-terminated string at SI
; ============================================================================
print_string:
    pusha
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    mov bx, 0x0007              ; Page 0, light gray
    int 0x10
    jmp .loop
.done:
    popa
    ret

; ============================================================================
; Data
; ============================================================================

; Disk Address Packet for LBA read
dap:
    db 0x10                     ; Size of DAP
    db 0                        ; Reserved
    dw STAGE2_SECTORS           ; Number of sectors to read
    dw STAGE2_LOAD_OFF          ; Offset
    dw STAGE2_LOAD_SEG          ; Segment
    dq 1                        ; LBA start (sector 1 = right after MBR)

boot_drive: db 0

banner:
    db 0x0D, 0x0A
    db '  StratOS BIOS Bootloader v0.1', 0x0D, 0x0A
    db '  "From the Void, Structure."', 0x0D, 0x0A
    db 0x0D, 0x0A, 0

loading_msg:
    db '  [..] Loading Stage 2...', 0

ok_msg:
    db ' OK', 0x0D, 0x0A, 0

disk_err_msg:
    db ' FAIL', 0x0D, 0x0A
    db '  Disk read error. System halted.', 0x0D, 0x0A, 0

; ============================================================================
; MBR Padding and Signature
; ============================================================================
    times 510 - ($ - $$) db 0
    dw 0xAA55                   ; Boot signature
