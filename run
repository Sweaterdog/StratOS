#!/usr/bin/env bash
# ==============================================================================
# run.sh — Quick-launch StratOS in QEMU
# Usage:
#   ./run.sh          — Build & run in BIOS mode (default)
#   ./run.sh bios     — Build & run in BIOS mode
#   ./run.sh uefi     — Build & run in UEFI mode
#   ./run.sh debug    — Build & run with GDB server
#   ./run.sh clean    — Clean build artifacts
#   ./run.sh info     — Show build info
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MODE="${1:-bios}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

banner() {
    echo -e "${CYAN}${BOLD}"
    echo "  ╔═══════════════════════════════════╗"
    echo "  ║         ★  S t r a t O S  ★       ║"
    echo "  ║     Operating System Launcher     ║"
    echo "  ╚═══════════════════════════════════╝"
    echo -e "${NC}"
}

check_deps() {
    local missing=()

    command -v nasm   >/dev/null 2>&1 || missing+=("nasm")
    command -v qemu-system-x86_64 >/dev/null 2>&1 || missing+=("qemu-system-x86_64")
    command -v fluxc  >/dev/null 2>&1 || missing+=("fluxc (Flux compiler)")
    command -v make   >/dev/null 2>&1 || missing+=("make")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing dependencies:${NC}"
        for dep in "${missing[@]}"; do
            echo -e "  • $dep"
        done
        echo ""
        echo "Install with:"
        echo "  sudo apt install nasm qemu-system-x86 make"
        echo "  (Flux compiler: see Flux_Language_Manual.md)"
        exit 1
    fi
}

case "$MODE" in
    bios)
        banner
        check_deps
        echo -e "${BLUE}Building StratOS (BIOS)...${NC}"
        make bios
        echo -e "${GREEN}Launching in QEMU (BIOS mode)...${NC}"
        make run-bios
        ;;
    uefi)
        banner
        check_deps
        echo -e "${BLUE}Building StratOS (UEFI)...${NC}"

        # Check for OVMF
        OVMF=""
        for path in /usr/share/OVMF/OVMF_CODE.fd \
                     /usr/share/edk2/ovmf/OVMF_CODE.fd \
                     /usr/share/qemu/OVMF_CODE.fd; do
            if [ -f "$path" ]; then
                OVMF="$path"
                break
            fi
        done

        if [ -z "$OVMF" ]; then
            echo -e "${RED}OVMF firmware not found.${NC}"
            echo "Install with: sudo apt install ovmf"
            exit 1
        fi

        make uefi
        echo -e "${GREEN}Launching in QEMU (UEFI mode)...${NC}"
        make run-uefi
        ;;
    debug)
        banner
        check_deps
        echo -e "${BLUE}Building StratOS (Debug)...${NC}"
        make bios
        echo -e "${GREEN}Launching with GDB server on :1234...${NC}"
        make debug-bios
        ;;
    clean)
        echo -e "${BLUE}Cleaning build artifacts...${NC}"
        make clean
        echo -e "${GREEN}Done.${NC}"
        ;;
    info)
        banner
        make info
        ;;
    all)
        banner
        check_deps
        echo -e "${BLUE}Building all targets...${NC}"
        make all
        echo -e "${GREEN}Build complete.${NC}"
        ;;
    *)
        echo "Usage: $0 {bios|uefi|debug|clean|info|all}"
        exit 1
        ;;
esac
