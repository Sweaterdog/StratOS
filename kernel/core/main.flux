// DOCTYPE {AOT}
// ============================================================================
// StratOS Kernel Entry Point
// kernel/core/main.flux
//
// Called by the bootloader (BIOS stage2 or UEFI stub) after switching to
// 64-bit long mode. The BootInfo struct is passed via RDI as per the
// System V AMD64 ABI.
//
// Initialization order:
//   1. Memory manager (physical frame allocator + heap)
//   2. IDT (interrupt descriptor table + PIC remap)
//   3. Timer (PIT at 100Hz)
//   4. Framebuffer (video output)
//   5. Console (text mode on framebuffer)
//   6. Keyboard (PS/2 input)
//   7. Disk driver (ATA PIO)
//   8. PCI bus enumeration
//   9. E1000 NIC driver
//  10. Network stack (TCP/IP, ARP, DNS)
//  11. Scheduler (process management)
//  12. VFS (virtual filesystem + StratFS persistence)
//  13. Syscall dispatch (Linux ABI layer)
//  14. Shell / Compositor (user interface)
// ============================================================================

import "kernel/core/bootinfo.lx";
import "kernel/memory/manager.lx";
import "kernel/interrupts/idt.lx";
import "kernel/drivers/timer.lx";
import "kernel/drivers/framebuffer.lx";
import "kernel/core/console.lx";
import "kernel/drivers/keyboard.lx";
import "kernel/core/scheduler.lx";
import "system/fs/vfs.lx";
import "kernel/drivers/disk.lx";
import "kernel/drivers/pci.lx";
import "kernel/drivers/e1000.lx";
import "kernel/drivers/net.lx";
import "kernel/core/process.lx";
import "system/shell/shell.lx";
import "system/windowing/compositor.lx";
import "assets/fonts/system_font.lx";

// Kernel entry point — called from bootloader with BootInfo* in RDI
export func kernel_main(long bootInfoAddr) -> void {
    unsafe {
        // Cast the raw address to a BootInfo pointer
        BootInfo* bootInfo = (BootInfo*) bootInfoAddr;

        // Copy boot info to a local structure
        BootInfo boot;
        byte* src = (byte*) bootInfo;
        byte* dst = (byte*) &boot;
        for (int i = 0; i < 72; i++) {
            dst[i] = src[i];
        }

        // Set up font base address — read the items pointer from the
        // fontData FluxList struct (first 8 bytes are the items pointer)
        long* fontItemsPtr = (long*) &fontData;
        BUILTIN_FONT_BASE = *fontItemsPtr;

        // ── Phase 1: Core Kernel ──────────────────────────────────────────

        // Initialize memory manager from bootloader memory map
        MemoryManager.init(boot.memoryMap, boot.memoryMapSize, boot.memoryMapDescSize);

        // Connect the kernel heap to the Flux runtime allocator
        // Allocate 4MB from the kernel heap for FluxList/FluxString dynamic memory
        unsafe {
            long heapChunk = MemoryManager.kmalloc(4194304);
            byte** heapPtrPtr = (byte**) &flux_heap_ptr;
            *heapPtrPtr = (byte*) heapChunk;
            long* remainPtr = (long*) &flux_heap_remaining;
            *remainPtr = (long) 4194304;
        }

        // Set up interrupt descriptor table and remap PICs
        IDT.init();
        IDT.registerExceptionHandlers();

        // Initialize framebuffer
        Framebuffer.init(boot);

        // Initialize console output
        Console.init(boot);
        Console.setColor(0x5B8CFFFF);
        Console.log("StratOS v0.1.0 - Cosmic Edition");
        Console.setColor(0xC8D0E0FF);
        Console.log("Booting...");
        Console.log("");

        // ── Phase 2: Hardware Drivers ─────────────────────────────────────

        Console.write("[  OK  ] Memory manager initialized (");
        Console.write("heap: 16MB)");
        Console.log("");

        // Initialize PIT timer at 100 Hz
        Timer.init(100);
        Console.log("[  OK  ] Timer initialized (100 Hz)");

        // Initialize keyboard driver
        Keyboard.init();
        Console.log("[  OK  ] Keyboard driver loaded (PS/2)");

        // Initialize disk driver (ATA PIO)
        Disk.init();
        if (Disk.isPresent()) {
            Console.log("[  OK  ] ATA disk detected");
        } else {
            Console.log("[WARN ] No ATA disk found — volatile mode");
        }

        // PCI bus enumeration
        PCI.enumerate();
        Console.log("[  OK  ] PCI bus enumerated");

        // E1000 Network Interface
        E1000.init();
        if (E1000.isPresent()) {
            Console.log("[  OK  ] E1000 NIC initialized");
        } else {
            Console.log("[WARN ] No E1000 NIC found — no networking");
        }

        // Network stack (TCP/IP, ARP, DNS, DHCP)
        if (E1000.isPresent()) {
            Net.init();
            Net.dhcp();
        }

        // ── Phase 3: Kernel Services ──────────────────────────────────────

        // Initialize scheduler
        Scheduler.init();
        Console.log("[  OK  ] Scheduler initialized");

        // Initialize virtual filesystem (with disk persistence if available)
        VFS.init();
        if (VFS.isPersistent()) {
            Console.log("[  OK  ] Virtual filesystem mounted (persistent)");
        } else {
            Console.log("[  OK  ] Virtual filesystem mounted (volatile)");
        }

        // Initialize syscall dispatch layer (depends on VFS)
        Syscall.init();
        Console.log("[  OK  ] Syscall dispatch initialized (Linux ABI)");

        // Enable interrupts now that all handlers are registered
        asm("sti");
        Console.log("[  OK  ] Interrupts enabled");

        Console.log("");
        Console.setColor(0x69F0AEFF);
        Console.log("StratOS boot complete.");
        Console.setColor(0xC8D0E0FF);
        Console.log("");

        // ── Phase 4: User Interface ───────────────────────────────────────

        // Initialize shell (for terminal access within desktop)
        Shell.init();

        // Boot directly to the desktop environment
        Compositor.init(boot);
        Compositor.startDesktop();

        // Desktop exited — drop to shell
        Console.setColor(0x5B8CFFFF);
        Console.log("Desktop session ended. Entering shell.");
        Console.setColor(0xC8D0E0FF);
        Console.log("");

        // Shell/Desktop loop — supports startx to return to desktop
        while (true) {
            Shell.run();

            // Check if desktop was requested via 'startx'
            if (desktopRequested) {
                desktopRequested = false;
                Compositor.init(boot);
                Compositor.startDesktop();

                // Desktop exited, return to shell
                Console.setColor(0x5B8CFFFF);
                Console.log("Desktop session ended. Returning to shell.");
                Console.setColor(0xC8D0E0FF);
                Console.log("");
            } else {
                // Shell exited normally (exit/shutdown)
                break;
            }
        }

        // If shell exits, halt the CPU
        Console.log("System halted.");
        asm("cli");
        while (true) {
            asm("hlt");
        }
    }
}
