; ============================================================================
; StratOS UEFI Bootloader
; Target: x86_64 UEFI
; Assembler: NASM (flat binary → .efi via objcopy)
;
; This bootloader:
;   1. Calls UEFI GOP to detect and set the best available resolution
;   2. Gets the memory map from UEFI
;   3. Loads the kernel from the ESP (EFI System Partition)
;   4. Passes a BootInfo struct to the kernel
;   5. Exits UEFI Boot Services and jumps to kernel entry
; ============================================================================

; UEFI calling convention: Microsoft x64 ABI
; Args: RCX, RDX, R8, R9, then stack
; Caller-saved: RAX, RCX, RDX, R8, R9, R10, R11
; Callee-saved: RBX, RBP, RDI, RSI, R12-R15

BITS 64

; ----- PE/COFF Header for UEFI -----
section .header

; DOS Header (MZ stub)
    dw 0x5A4D                ; e_magic: MZ
    times 29 dw 0            ; padding
    dd 0x80                  ; e_lfanew: PE header offset

    times 0x80 - ($ - $$) db 0  ; pad to PE header

; PE Signature
    dd 0x00004550            ; "PE\0\0"

; COFF Header
    dw 0x8664                ; Machine: x86_64
    dw 1                     ; NumberOfSections
    dd 0                     ; TimeDateStamp
    dd 0                     ; PointerToSymbolTable
    dd 0                     ; NumberOfSymbols
    dw section_table - optional_header  ; SizeOfOptionalHeader
    dw 0x0206                ; Characteristics: EXECUTABLE_IMAGE | LINE_NUMS_STRIPPED | DLL

; Optional Header (PE32+)
optional_header:
    dw 0x020B                ; Magic: PE32+
    db 0                     ; MajorLinkerVersion
    db 0                     ; MinorLinkerVersion
    dd code_end - code_start ; SizeOfCode
    dd 0                     ; SizeOfInitializedData
    dd 0                     ; SizeOfUninitializedData
    dd code_start - $$       ; AddressOfEntryPoint
    dd code_start - $$       ; BaseOfCode

    ; PE32+ extra fields
    dq 0x100000              ; ImageBase
    dd 0x1000                ; SectionAlignment
    dd 0x200                 ; FileAlignment
    dw 0                     ; MajorOperatingSystemVersion
    dw 0                     ; MinorOperatingSystemVersion
    dw 0                     ; MajorImageVersion
    dw 0                     ; MinorImageVersion
    dw 0                     ; MajorSubsystemVersion
    dw 0                     ; MinorSubsystemVersion
    dd 0                     ; Win32VersionValue
    dd file_end - $$         ; SizeOfImage
    dd code_start - $$       ; SizeOfHeaders
    dd 0                     ; CheckSum
    dw 10                    ; Subsystem: EFI_APPLICATION
    dw 0                     ; DllCharacteristics
    dq 0x100000              ; SizeOfStackReserve
    dq 0x100000              ; SizeOfStackCommit
    dq 0x100000              ; SizeOfHeapReserve
    dq 0x100000              ; SizeOfHeapCommit
    dd 0                     ; LoaderFlags
    dd 0                     ; NumberOfRvaAndSizes

section_table:
    ; .text section
    db '.text', 0, 0, 0      ; Name
    dd code_end - code_start  ; VirtualSize
    dd code_start - $$        ; VirtualAddress
    dd code_end - code_start  ; SizeOfRawData
    dd code_start - $$        ; PointerToRawData
    dd 0                      ; PointerToRelocations
    dd 0                      ; PointerToLinenumbers
    dw 0                      ; NumberOfRelocations
    dw 0                      ; NumberOfLinenumbers
    dd 0x60000020             ; Characteristics: CODE | EXECUTE | READ

; ----- UEFI Boot Code -----
section .text

code_start:

; ============================================================================
; EFI Entry Point
; RCX = EFI_HANDLE (ImageHandle)
; RDX = EFI_SYSTEM_TABLE*
; ============================================================================
efi_main:
    ; Save UEFI parameters
    push rbp
    mov rbp, rsp
    sub rsp, 256             ; Local stack space

    mov [image_handle], rcx
    mov [system_table], rdx

    ; Get BootServices pointer
    mov rax, [rdx + 96]      ; EFI_SYSTEM_TABLE.BootServices (offset varies by spec)
    mov [boot_services], rax

    ; Get ConOut for text output
    mov rax, [rdx + 64]      ; EFI_SYSTEM_TABLE.ConOut
    mov [con_out], rax

    ; ----- Print Banner -----
    lea rdx, [banner_msg]
    mov rcx, [con_out]
    mov rax, [rcx + 8]       ; ConOut->OutputString
    call rax

    ; ----- Setup GOP (Graphics Output Protocol) -----
    call setup_graphics

    ; ----- Get Memory Map -----
    call get_memory_map

    ; ----- Load Kernel -----
    ; For now, kernel is expected at a fixed address after bootloader
    ; In production, this reads kernel.bin from the ESP filesystem
    lea rdx, [kernel_loading_msg]
    mov rcx, [con_out]
    mov rax, [rcx + 8]
    call rax

    ; ----- Prepare BootInfo Struct -----
    ; BootInfo is passed to kernel in RDI (SysV ABI for kernel)
    lea rdi, [boot_info]

    ; Framebuffer base address
    mov rax, [gop_framebuffer]
    mov [rdi], rax             ; boot_info.framebuffer_base

    ; Framebuffer size
    mov eax, [gop_fb_size]
    mov [rdi + 8], eax         ; boot_info.framebuffer_size

    ; Screen resolution
    mov eax, [gop_width]
    mov [rdi + 12], eax        ; boot_info.screen_width
    mov eax, [gop_height]
    mov [rdi + 16], eax        ; boot_info.screen_height
    mov eax, [gop_pitch]
    mov [rdi + 20], eax        ; boot_info.pixels_per_scanline

    ; Memory map pointer
    mov rax, [mmap_ptr]
    mov [rdi + 24], rax        ; boot_info.memory_map
    mov eax, [mmap_size]
    mov [rdi + 32], eax        ; boot_info.memory_map_size
    mov eax, [mmap_desc_size]
    mov [rdi + 36], eax        ; boot_info.memory_map_desc_size
    mov eax, [mmap_key]
    mov [rdi + 40], eax        ; boot_info.memory_map_key

    ; ----- Exit Boot Services -----
    lea rdx, [exit_bs_msg]
    mov rcx, [con_out]
    mov rax, [rcx + 8]
    call rax

    mov rcx, [image_handle]
    mov edx, [mmap_key]
    mov rax, [boot_services]
    call [rax + 232]           ; BootServices->ExitBootServices

    ; Test for success
    test rax, rax
    jnz .exit_bs_failed

    ; ----- Jump to Kernel -----
    ; Kernel entry point expected at KERNEL_LOAD_ADDR
    ; RDI = pointer to boot_info (SysV x86_64 ABI)
    lea rdi, [boot_info]
    mov rax, KERNEL_LOAD_ADDR
    jmp rax

.exit_bs_failed:
    ; If ExitBootServices fails, retry with updated memory map
    ; For now, just halt
    cli
    hlt

; ============================================================================
; setup_graphics - Locate GOP and set best available mode
; ============================================================================
setup_graphics:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; Locate GOP protocol
    mov rcx, [boot_services]

    ; BootServices->LocateProtocol(&EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID, NULL, &gop)
    lea rdx, [gop_guid]
    xor r8, r8               ; SearchKey = NULL
    lea r9, [gop_handle]     ; Interface output
    mov rax, [rcx + 320]     ; BootServices->LocateProtocol
    call rax

    test rax, rax
    jnz .gop_not_found

    ; GOP found — query modes to find best resolution
    mov rcx, [gop_handle]

    ; Get current mode info
    mov rax, [rcx + 24]       ; GOP->Mode
    mov rdx, [rax + 8]        ; Mode->Info
    mov eax, [rdx + 4]        ; Info->HorizontalResolution
    mov [gop_width], eax
    mov eax, [rdx + 8]        ; Info->VerticalResolution
    mov [gop_height], eax
    mov eax, [rdx + 12]       ; Info->PixelsPerScanLine
    mov [gop_pitch], eax

    ; Get framebuffer
    mov rcx, [gop_handle]
    mov rax, [rcx + 24]       ; GOP->Mode
    mov rdx, [rax + 24]       ; Mode->FrameBufferBase
    mov [gop_framebuffer], rdx
    mov eax, [rax + 32]       ; Mode->FrameBufferSize
    mov [gop_fb_size], eax

    ; Scan all modes to find the highest resolution
    mov rcx, [gop_handle]
    mov rax, [rcx + 24]       ; GOP->Mode
    mov ecx, [rax]            ; Mode->MaxMode
    mov [gop_max_modes], ecx

    xor esi, esi              ; mode_index = 0
    xor edi, edi              ; best_pixels = 0
    mov dword [best_mode], 0

.scan_modes:
    cmp esi, [gop_max_modes]
    jge .set_best_mode

    ; QueryMode(gop, mode_index, &info_size, &info)
    push rsi
    push rdi
    mov rcx, [gop_handle]
    mov edx, esi              ; ModeNumber
    lea r8, [mode_info_size]
    lea r9, [mode_info_ptr]
    mov rax, [rcx + 8]        ; GOP->QueryMode
    call rax
    pop rdi
    pop rsi

    test rax, rax
    jnz .next_mode

    ; Check if this mode has more pixels
    mov rax, [mode_info_ptr]
    mov ecx, [rax + 4]        ; HorizontalResolution
    mov edx, [rax + 8]        ; VerticalResolution
    imul ecx, edx             ; total pixels
    cmp ecx, edi
    jle .next_mode

    ; New best mode
    mov edi, ecx
    mov [best_mode], esi

.next_mode:
    inc esi
    jmp .scan_modes

.set_best_mode:
    ; Set the best mode we found
    mov rcx, [gop_handle]
    mov edx, [best_mode]
    mov rax, [rcx]            ; GOP->SetMode
    call rax

    ; Re-read mode info after setting
    mov rcx, [gop_handle]
    mov rax, [rcx + 24]       ; GOP->Mode
    mov rdx, [rax + 8]        ; Mode->Info
    mov eax, [rdx + 4]
    mov [gop_width], eax
    mov eax, [rdx + 8]
    mov [gop_height], eax
    mov eax, [rdx + 12]
    mov [gop_pitch], eax

    mov rcx, [gop_handle]
    mov rax, [rcx + 24]
    mov rdx, [rax + 24]
    mov [gop_framebuffer], rdx
    mov eax, [rax + 32]
    mov [gop_fb_size], eax

    ; Print success
    lea rdx, [gop_ok_msg]
    mov rcx, [con_out]
    mov rax, [rcx + 8]
    call rax

    leave
    ret

.gop_not_found:
    lea rdx, [gop_fail_msg]
    mov rcx, [con_out]
    mov rax, [rcx + 8]
    call rax
    cli
    hlt

; ============================================================================
; get_memory_map - Retrieve UEFI memory map
; ============================================================================
get_memory_map:
    push rbp
    mov rbp, rsp
    sub rsp, 64

    ; First call to get required size
    lea rcx, [mmap_size]
    mov dword [rcx], 0        ; size = 0 (will be filled)
    xor edx, edx              ; MemoryMap = NULL
    lea r8, [mmap_key]
    lea r9, [mmap_desc_size]
    push qword 0              ; DescriptorVersion (on stack)
    mov rax, [boot_services]
    call [rax + 56]            ; BootServices->GetMemoryMap
    pop rax                    ; clean stack

    ; Allocate buffer for memory map + extra
    mov ecx, [mmap_size]
    add ecx, 4096              ; Extra space for map changes
    mov [mmap_size], ecx

    ; AllocatePool(EfiLoaderData, size, &buffer)
    mov rcx, 2                 ; EfiLoaderData
    mov edx, [mmap_size]
    lea r8, [mmap_ptr]
    mov rax, [boot_services]
    call [rax + 64]            ; BootServices->AllocatePool

    ; Now get the actual memory map
    lea rcx, [mmap_size]
    mov rdx, [mmap_ptr]
    lea r8, [mmap_key]
    lea r9, [mmap_desc_size]
    push qword 0
    mov rax, [boot_services]
    call [rax + 56]            ; GetMemoryMap
    pop rax

    leave
    ret

; ============================================================================
; Data Section
; ============================================================================
section .data

KERNEL_LOAD_ADDR equ 0x100000  ; 1MB — kernel load address

; UEFI handles and pointers
image_handle:   dq 0
system_table:   dq 0
boot_services:  dq 0
con_out:        dq 0

; GOP data
gop_handle:     dq 0
gop_framebuffer: dq 0
gop_fb_size:    dd 0
gop_width:      dd 0
gop_height:     dd 0
gop_pitch:      dd 0
gop_max_modes:  dd 0
best_mode:      dd 0
mode_info_size: dq 0
mode_info_ptr:  dq 0

; GOP GUID: 9042a9de-23dc-4a38-96fb-7aded080516a
gop_guid:
    dd 0x9042A9DE
    dw 0x23DC
    dw 0x4A38
    db 0x96, 0xFB, 0x7A, 0xDE, 0xD0, 0x80, 0x51, 0x6A

; Memory map data
mmap_ptr:       dq 0
mmap_size:      dd 0
mmap_key:       dd 0
mmap_desc_size: dd 0

; Boot info struct passed to kernel
; Layout:
;   +0   : u64 framebuffer_base
;   +8   : u32 framebuffer_size
;   +12  : u32 screen_width
;   +16  : u32 screen_height
;   +20  : u32 pixels_per_scanline
;   +24  : u64 memory_map
;   +32  : u32 memory_map_size
;   +36  : u32 memory_map_desc_size
;   +40  : u32 memory_map_key
boot_info: times 64 db 0

; Unicode strings for UEFI console output (UTF-16LE, null-terminated)
banner_msg:
    dw __utf16le__(`\r\n`)
    dw __utf16le__(`  ____  _             _    ___  ____\r\n`)
    dw __utf16le__(` / ___|| |_ _ __ __ _| |_ / _ \\/ ___|\r\n`)
    dw __utf16le__(` \\___ \\| __| '__/ _` | __| | | \\___ \\\r\n`)
    dw __utf16le__(`  ___) | |_| | | (_| | |_| |_| |___) |\r\n`)
    dw __utf16le__(` |____/ \\__|_|  \\__,_|\\__|\\___/|____/\r\n`)
    dw __utf16le__(`\r\n`)
    dw __utf16le__(`  "From the Void, Structure."\r\n`)
    dw __utf16le__(`  UEFI Bootloader v0.1\r\n`)
    dw __utf16le__(`\r\n`), 0

gop_ok_msg:
    dw __utf16le__(`  [OK] Graphics Output Protocol initialized\r\n`), 0

gop_fail_msg:
    dw __utf16le__(`  [FAIL] GOP not found - cannot boot\r\n`), 0

kernel_loading_msg:
    dw __utf16le__(`  [..] Loading StratOS kernel...\r\n`), 0

exit_bs_msg:
    dw __utf16le__(`  [..] Exiting UEFI Boot Services...\r\n`), 0

code_end:
file_end:
