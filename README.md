# StratOS

StratOS is an experimental Flux-native operating environment. This repository contains the kernel sources, boot code, desktop/windowing system, apps, assets, runtime support, media, and build scripts for the current StratOS package.

## What Is Included

- `kernel/` - core kernel, memory, interrupt, scheduler, process, syscall, and driver sources.
- `boot/` - BIOS, UEFI, and multiboot boot code.
- `system/` - shell, filesystem, audio, runtime, renderer, installer, and windowing components.
- `apps/` - bundled Flux applications such as browser, editor, explorer, terminal, settings, games, music, and system monitor.
- `assets/` and `media/` - fonts, icons, images, and music used by the desktop and apps.
- `tools/` - linker script, toolchain helper, and development utilities.
- `Flux_Language_Manual.md` - Flux language reference with StratOS-specific sections.

Flux itself is published separately at `https://github.com/Sweaterdog/Flux`.

## Prerequisites

StratOS builds expect a working Flux compiler/runtime. The Makefile looks for a sibling Flux build at `../build/flux` and otherwise falls back to `flux` on `PATH`.

Common build tools include:

- `as`, `ld`, and `objcopy`, or an `x86_64-elf-*` cross toolchain.
- `grub-mkrescue` for ISO image creation.
- `qemu-system-x86_64` for local boot testing.
- `nasm` for BIOS and UEFI boot image targets.

## Build

Build the GRUB ISO path:

```sh
make iso
```

Build all BIOS and UEFI targets:

```sh
make all
```

Generated images and object files are written under `build/` and are intentionally ignored by git.

## Run

Run the ISO target in QEMU:

```sh
make run-iso
```

The `run` and `run.sh` scripts are also included for local development workflows.

## Persistence

The `disk` target creates `build/stratos-disk.img` as a persistent raw disk image. It is not committed to the repository. Use `make disk-reset` only when you want to erase that local persistent state.

## Repository Notes

This repository was split out from the newer nested `Flux/Flux_StratOS` tree. Generated files such as kernel objects, ISO images, disk images, and generated C++ are excluded so the repo stays focused on source and packaged assets.
