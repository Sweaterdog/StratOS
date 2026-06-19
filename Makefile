# ==============================================================================
# StratOS Build System
# ==============================================================================
# Targets:
#   make all       — Build everything (BIOS + UEFI images)
#   make bios      — Build BIOS-bootable disk image
#   make uefi      — Build UEFI-bootable disk image
#   make run-bios  — Build & launch in QEMU (BIOS mode)
#   make run-uefi  — Build & launch in QEMU (UEFI mode)
#   make clean     — Remove all build artifacts
# ==============================================================================

# ---- Toolchain ----
NASM        := nasm
FLUX_LOCAL  := $(realpath ../build/flux)
FLUX        := $(if $(wildcard $(FLUX_LOCAL)),$(FLUX_LOCAL),flux)
CXX         := x86_64-elf-g++
LD          := x86_64-elf-ld
OBJCOPY     := x86_64-elf-objcopy
QEMU        := qemu-system-x86_64
MKFS_FAT    := mkfs.fat
DD          := dd
MKDIR       := mkdir -p

# Use system g++/ld if cross-compiler not available
CXX_CHECK   := $(shell which x86_64-elf-g++ 2>/dev/null)
ifndef CXX_CHECK
    CXX     := g++
    LD      := ld
    OBJCOPY := objcopy
endif

# ---- Directories ----
BUILD_DIR   := build
BOOT_DIR    := boot
KERNEL_DIR  := kernel
SYSTEM_DIR  := system
APPS_DIR    := apps
ASSETS_DIR  := assets
TOOLS_DIR   := tools

OBJ_DIR     := $(BUILD_DIR)/obj
ISO_DIR     := $(BUILD_DIR)/iso
IMG_DIR     := $(BUILD_DIR)/img

# ---- Output files ----
BIOS_IMG    := $(BUILD_DIR)/stratos-bios.img
UEFI_IMG    := $(BUILD_DIR)/stratos-uefi.img
KERNEL_ELF  := $(BUILD_DIR)/kernel.elf
KERNEL_BIN  := $(BUILD_DIR)/kernel.bin
DISK_IMG    := $(BUILD_DIR)/stratos-disk.img
DISK_SIZE   := 64M

# ---- UEFI firmware ----
OVMF_CODE   := /usr/share/OVMF/OVMF_CODE.fd
OVMF_VARS   := /usr/share/OVMF/OVMF_VARS.fd

# Check alternate OVMF paths
ifeq ($(wildcard $(OVMF_CODE)),)
    OVMF_CODE := /usr/share/edk2/ovmf/OVMF_CODE.fd
    OVMF_VARS := /usr/share/edk2/ovmf/OVMF_VARS.fd
endif
ifeq ($(wildcard $(OVMF_CODE)),)
    OVMF_CODE := /usr/share/qemu/OVMF_CODE.fd
    OVMF_VARS := /usr/share/qemu/OVMF_VARS.fd
endif

# ---- Compiler/Linker Flags ----
CXXFLAGS    := -ffreestanding -fno-exceptions -fno-rtti -nostdlib \
               -mno-red-zone \
               -mcmodel=kernel -fno-pic -fno-stack-protector \
               -Wall -Wextra -O2 -std=c++17 \
               -I$(KERNEL_DIR) -I$(SYSTEM_DIR) -I$(APPS_DIR) -I$(ASSETS_DIR)

LDFLAGS     := -T $(TOOLS_DIR)/linker.ld -nostdlib -z max-page-size=4096

NASMFLAGS_BIN   := -f bin
NASMFLAGS_ELF   := -f elf64
NASMFLAGS_UEFI  := -f win64

# ---- Source Discovery ----
# Flux source files (kernel, system, apps, assets)
FLUX_KERNEL := $(shell find $(KERNEL_DIR) -name '*.flux' -o -name '*.lx' 2>/dev/null)
FLUX_SYSTEM := $(shell find $(SYSTEM_DIR) -name '*.flux' -o -name '*.lx' 2>/dev/null)
FLUX_APPS   := $(shell find $(APPS_DIR) -name '*.flux' -o -name '*.lx' 2>/dev/null)
FLUX_ASSETS := $(shell find $(ASSETS_DIR) -name '*.lx' 2>/dev/null)
FLUX_ALL    := $(FLUX_KERNEL) $(FLUX_SYSTEM) $(FLUX_APPS) $(FLUX_ASSETS)
KERNEL_ENTRY := $(KERNEL_DIR)/core/main.flux

# Boot assembly
BIOS_STAGE1 := $(BOOT_DIR)/bios/stage1.asm
BIOS_STAGE2 := $(BOOT_DIR)/bios/stage2.asm
UEFI_BOOT   := $(BOOT_DIR)/uefi/boot.asm

# ==============================================================================
# Targets
# ==============================================================================

.PHONY: all bios uefi clean run-bios run-uefi dirs

all: bios uefi
	@echo ""
	@echo "╔══════════════════════════════════════╗"
	@echo "║     StratOS build complete!          ║"
	@echo "║  BIOS: $(BIOS_IMG)                   "
	@echo "║  UEFI: $(UEFI_IMG)                   "
	@echo "╚══════════════════════════════════════╝"

# ---- Directory Setup ----
dirs:
	@$(MKDIR) $(BUILD_DIR) $(OBJ_DIR) $(ISO_DIR) $(IMG_DIR)
	@$(MKDIR) $(OBJ_DIR)/kernel/core
	@$(MKDIR) $(OBJ_DIR)/kernel/memory
	@$(MKDIR) $(OBJ_DIR)/kernel/interrupts
	@$(MKDIR) $(OBJ_DIR)/kernel/drivers
	@$(MKDIR) $(OBJ_DIR)/system/shell
	@$(MKDIR) $(OBJ_DIR)/system/fs
	@$(MKDIR) $(OBJ_DIR)/system/windowing
	@$(MKDIR) $(OBJ_DIR)/system/audio
	@$(MKDIR) $(OBJ_DIR)/apps/editor
	@$(MKDIR) $(OBJ_DIR)/apps/explorer
	@$(MKDIR) $(OBJ_DIR)/apps/browser
	@$(MKDIR) $(OBJ_DIR)/apps/music
	@$(MKDIR) $(OBJ_DIR)/apps/quantum
	@$(MKDIR) $(OBJ_DIR)/assets/fonts
	@$(MKDIR) $(OBJ_DIR)/assets/icons

# ==============================================================================
# Kernel linking
# ==============================================================================

# Multiboot boot stub (GAS syntax — no NASM required)
BOOT_STUB   := boot/multiboot/boot.S
GRUB_CFG    := $(ISO_DIR)/boot/grub/grub.cfg
STRATOS_ISO := $(BUILD_DIR)/stratos.iso

$(OBJ_DIR)/boot.o: $(BOOT_STUB) | dirs
	@echo "  AS    $<"
	@as --64 -o $@ $<

$(OBJ_DIR)/kernel.o: $(KERNEL_ENTRY) $(FLUX_ALL) | dirs
	@echo "  FLUX  $<"
	@$(FLUX) compile $< --dev
	@cp $(KERNEL_DIR)/core/main $@

$(KERNEL_ELF): $(OBJ_DIR)/boot.o $(OBJ_DIR)/kernel.o | dirs
	@echo "  LD    $@"
	@$(LD) $(LDFLAGS) -o $@ $(OBJ_DIR)/boot.o $(OBJ_DIR)/kernel.o

$(KERNEL_BIN): $(KERNEL_ELF)
	@echo "  BIN   $@"
	@$(OBJCOPY) -O binary $< $@

# ==============================================================================
# GRUB ISO image (primary boot method)
# ==============================================================================

iso: dirs $(KERNEL_ELF)
	@echo "  ISO   $(STRATOS_ISO)"
	@$(MKDIR) $(ISO_DIR)/boot/grub
	@cp $(KERNEL_ELF) $(ISO_DIR)/boot/kernel.elf
	@echo 'set timeout=3' > $(GRUB_CFG)
	@echo 'set default=0' >> $(GRUB_CFG)
	@echo 'set gfxmode=1024x768x32' >> $(GRUB_CFG)
	@echo 'set gfxpayload=keep' >> $(GRUB_CFG)
	@echo '' >> $(GRUB_CFG)
	@echo 'menuentry "StratOS v0.1.0 — Cosmic Edition" {' >> $(GRUB_CFG)
	@echo '    multiboot /boot/kernel.elf' >> $(GRUB_CFG)
	@echo '    boot' >> $(GRUB_CFG)
	@echo '}' >> $(GRUB_CFG)
	@grub-mkrescue -o $(STRATOS_ISO) $(ISO_DIR) 2>/dev/null
	@echo "  DONE  ISO ready: $(STRATOS_ISO)"

run-iso: iso disk
	@echo ""
	@echo "  Launching StratOS (GRUB/ISO mode + persistent disk)..."
	@$(QEMU) \
		-cdrom $(STRATOS_ISO) \
		-drive file=$(DISK_IMG),format=raw,if=ide,index=0 \
		-m 256M \
		-cpu qemu64 \
		-vga std \
		-serial stdio \
		-audiodev pa,id=snd0 \
		-machine pcspk-audiodev=snd0 \
		-netdev user,id=net0 \
		-device e1000,netdev=net0 \
		-no-reboot \
		-no-shutdown

# ==============================================================================
# Persistent Disk Image
# ==============================================================================

# Create a raw disk image if it doesn't already exist.
# This preserves data across reboots — never regenerated once created.
disk:
	@if [ ! -f $(DISK_IMG) ]; then \
		echo "  DISK  Creating persistent disk image ($(DISK_SIZE))..."; \
		$(DD) if=/dev/zero of=$(DISK_IMG) bs=1M count=64 status=none; \
		echo "  DONE  Disk image created: $(DISK_IMG)"; \
	else \
		echo "  DISK  Using existing disk image: $(DISK_IMG)"; \
	fi

# Force-recreate the disk image (erases all persistent data)
disk-reset:
	@echo "  DISK  Resetting persistent disk image..."
	@rm -f $(DISK_IMG)
	@$(DD) if=/dev/zero of=$(DISK_IMG) bs=1M count=64 status=none
	@echo "  DONE  Fresh disk image created"

# ==============================================================================
# BIOS boot image
# ==============================================================================

bios: dirs $(KERNEL_BIN) $(BUILD_DIR)/stage1.bin $(BUILD_DIR)/stage2.bin
	@echo "  IMG   $(BIOS_IMG)"
	@# Create 64MB disk image
	@$(DD) if=/dev/zero of=$(BIOS_IMG) bs=1M count=64 status=none
	@# Write MBR (stage1) to first sector
	@$(DD) if=$(BUILD_DIR)/stage1.bin of=$(BIOS_IMG) bs=512 count=1 conv=notrunc status=none
	@# Write stage2 starting at sector 2 (LBA 1)
	@$(DD) if=$(BUILD_DIR)/stage2.bin of=$(BIOS_IMG) bs=512 seek=1 conv=notrunc status=none
	@# Write kernel at 1MB offset (sector 2048)
	@$(DD) if=$(KERNEL_BIN) of=$(BIOS_IMG) bs=512 seek=2048 conv=notrunc status=none
	@echo "  DONE  BIOS image ready"

$(BUILD_DIR)/stage1.bin: $(BIOS_STAGE1) | dirs
	@echo "  ASM   $<"
	@$(NASM) $(NASMFLAGS_BIN) -o $@ $<

$(BUILD_DIR)/stage2.bin: $(BIOS_STAGE2) | dirs
	@echo "  ASM   $<"
	@$(NASM) $(NASMFLAGS_BIN) -o $@ $<

# ==============================================================================
# UEFI boot image
# ==============================================================================

uefi: dirs $(KERNEL_BIN) $(BUILD_DIR)/BOOTX64.EFI
	@echo "  IMG   $(UEFI_IMG)"
	@# Create 128MB FAT32 disk image
	@$(DD) if=/dev/zero of=$(UEFI_IMG) bs=1M count=128 status=none
	@$(MKFS_FAT) -F 32 $(UEFI_IMG) > /dev/null 2>&1
	@# Create directory structure and copy files using mtools if available
	@if command -v mmd > /dev/null 2>&1; then \
		mmd -i $(UEFI_IMG) ::/EFI; \
		mmd -i $(UEFI_IMG) ::/EFI/BOOT; \
		mcopy -i $(UEFI_IMG) $(BUILD_DIR)/BOOTX64.EFI ::/EFI/BOOT/; \
		mcopy -i $(UEFI_IMG) $(KERNEL_BIN) ::/kernel.bin; \
	else \
		echo "  WARN  mtools not found; mount image manually to populate"; \
	fi
	@echo "  DONE  UEFI image ready"

$(BUILD_DIR)/BOOTX64.EFI: $(UEFI_BOOT) | dirs
	@echo "  ASM   $< (UEFI)"
	@$(NASM) $(NASMFLAGS_UEFI) -o $(BUILD_DIR)/boot_uefi.obj $<
	@# If we have a PE linker, link properly. Otherwise use raw binary.
	@if command -v x86_64-w64-mingw32-ld > /dev/null 2>&1; then \
		x86_64-w64-mingw32-ld --subsystem 10 -e efi_main \
			-o $@ $(BUILD_DIR)/boot_uefi.obj; \
	else \
		$(NASM) -f bin -D__UEFI_BIN__ -o $@ $<; \
	fi

# ==============================================================================
# QEMU Launch
# ==============================================================================

run-bios: bios
	@echo ""
	@echo "  Launching StratOS (BIOS mode)..."
	@$(QEMU) \
		-drive file=$(BIOS_IMG),format=raw,if=ide \
		-m 256M \
		-cpu qemu64 \
		-vga std \
		-serial stdio \
		-audiodev pa,id=snd0 \
		-machine pcspk-audiodev=snd0 \
		-no-reboot \
		-no-shutdown

run-uefi: uefi
	@echo ""
	@echo "  Launching StratOS (UEFI mode)..."
	@$(QEMU) \
		-drive if=pflash,format=raw,readonly=on,file=$(OVMF_CODE) \
		-drive if=pflash,format=raw,file=$(OVMF_VARS) \
		-drive file=$(UEFI_IMG),format=raw,if=virtio \
		-m 256M \
		-cpu qemu64 \
		-vga std \
		-serial stdio \
		-device ich9-intel-hda \
		-device hda-duplex \
		-no-reboot \
		-no-shutdown

# Convenience alias
run: run-iso

# ==============================================================================
# Debug
# ==============================================================================

debug-bios: bios
	@echo "  Launching StratOS with GDB server..."
	@$(QEMU) \
		-drive file=$(BIOS_IMG),format=raw,if=ide \
		-m 256M \
		-cpu qemu64 \
		-vga std \
		-serial stdio \
		-audiodev pa,id=snd0 \
		-machine pcspk-audiodev=snd0 \
		-no-reboot \
		-no-shutdown \
		-s -S &
	@echo "  GDB server on localhost:1234. Attach with: gdb -ex 'target remote :1234' $(KERNEL_ELF)"

# ==============================================================================
# Clean
# ==============================================================================

clean:
	@echo "  Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "  Done."

# ==============================================================================
# Info
# ==============================================================================

info:
	@echo "StratOS Build System"
	@echo "===================="
	@echo "Flux sources:  $(words $(FLUX_ALL)) files"
	@echo "Kernel files:  $(words $(FLUX_KERNEL))"
	@echo "System files:  $(words $(FLUX_SYSTEM))"
	@echo "App files:     $(words $(FLUX_APPS))"
	@echo "Asset files:   $(words $(FLUX_ASSETS))"
	@echo ""
	@echo "Toolchain:"
	@echo "  NASM:    $(shell $(NASM) -v 2>/dev/null || echo 'not found')"
	@echo "  FLUX:    $(shell $(FLUX) --version 2>/dev/null || echo 'not found')"
	@echo "  CXX:     $(CXX)"
	@echo "  QEMU:    $(shell $(QEMU) --version 2>/dev/null | head -1 || echo 'not found')"
