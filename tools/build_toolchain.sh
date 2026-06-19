#!/usr/bin/env bash
# ==============================================================================
# build_toolchain.sh — Build a statically-linked Clang + LLD + libc++ toolchain
# for use inside StratOS
#
# This script cross-compiles the LLVM/Clang toolchain as a static Linux x86_64
# binary. The resulting toolchain can be bundled into the StratOS filesystem
# and invoked by the kernel's ProcessExec module to compile C++ code natively.
#
# Prerequisites (host):
#   - CMake >= 3.20
#   - Ninja or Make
#   - GCC or Clang (host compiler)
#   - Python 3
#   - Git
#   - ~30GB disk space for LLVM build
#
# Usage:
#   ./tools/build_toolchain.sh              # Full build
#   ./tools/build_toolchain.sh --musl-only  # Build musl libc only
#   ./tools/build_toolchain.sh --clean      # Remove build artifacts
#
# Output:
#   tools/toolchain/bin/clang               — C/C++ compiler
#   tools/toolchain/bin/lld                 — Linker
#   tools/toolchain/lib/                    — libc++, libc++abi, compiler-rt
#   tools/toolchain/include/                — Headers (libc++, musl)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TOOLCHAIN_DIR="$SCRIPT_DIR/toolchain"
BUILD_DIR="$SCRIPT_DIR/toolchain-build"
SRC_DIR="$SCRIPT_DIR/toolchain-src"

# Versions
LLVM_VERSION="17.0.6"
MUSL_VERSION="1.2.5"

# Target triple
TARGET="x86_64-linux-musl"

# Parallelism
JOBS="$(nproc 2>/dev/null || echo 4)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log()   { echo -e "${GREEN}[TOOLCHAIN]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARNING]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ==============================================================================
# Argument Parsing
# ==============================================================================

MUSL_ONLY=false
CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --musl-only) MUSL_ONLY=true ;;
        --clean)     CLEAN=true ;;
        --help|-h)
            echo "Usage: $0 [--musl-only] [--clean] [--help]"
            exit 0
            ;;
        *)
            err "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

if $CLEAN; then
    log "Cleaning toolchain build artifacts..."
    rm -rf "$BUILD_DIR" "$SRC_DIR" "$TOOLCHAIN_DIR"
    log "Done."
    exit 0
fi

# ==============================================================================
# Prerequisite Checks
# ==============================================================================

check_prereqs() {
    local missing=0

    for cmd in cmake git python3 make; do
        if ! command -v "$cmd" &>/dev/null; then
            err "Required tool not found: $cmd"
            missing=1
        fi
    done

    # Prefer ninja if available
    if command -v ninja &>/dev/null; then
        CMAKE_GENERATOR="Ninja"
    else
        CMAKE_GENERATOR="Unix Makefiles"
        warn "Ninja not found, falling back to Make (slower build)"
    fi

    if [ "$missing" -ne 0 ]; then
        err "Install missing prerequisites and retry."
        exit 1
    fi
}

# ==============================================================================
# Download Sources
# ==============================================================================

download_sources() {
    mkdir -p "$SRC_DIR"

    # Download musl libc
    if [ ! -d "$SRC_DIR/musl-$MUSL_VERSION" ]; then
        log "Downloading musl $MUSL_VERSION..."
        cd "$SRC_DIR"
        wget -q "https://musl.libc.org/releases/musl-$MUSL_VERSION.tar.gz"
        tar xf "musl-$MUSL_VERSION.tar.gz"
        rm -f "musl-$MUSL_VERSION.tar.gz"
    fi

    if $MUSL_ONLY; then
        return
    fi

    # Download LLVM project (monorepo)
    if [ ! -d "$SRC_DIR/llvm-project-$LLVM_VERSION.src" ]; then
        log "Downloading LLVM $LLVM_VERSION (this may take a while)..."
        cd "$SRC_DIR"
        wget -q "https://github.com/llvm/llvm-project/releases/download/llvmorg-$LLVM_VERSION/llvm-project-$LLVM_VERSION.src.tar.xz"
        log "Extracting LLVM sources..."
        tar xf "llvm-project-$LLVM_VERSION.src.tar.xz"
        rm -f "llvm-project-$LLVM_VERSION.src.tar.xz"
    fi
}

# ==============================================================================
# Build musl libc (static, for x86_64-linux-musl target)
# ==============================================================================

build_musl() {
    local musl_src="$SRC_DIR/musl-$MUSL_VERSION"
    local musl_build="$BUILD_DIR/musl"
    local musl_install="$TOOLCHAIN_DIR/sysroot"

    if [ -f "$musl_install/lib/libc.a" ]; then
        log "musl already built, skipping."
        return
    fi

    log "Building musl libc (static)..."
    mkdir -p "$musl_build"
    cd "$musl_build"

    "$musl_src/configure" \
        --prefix="$musl_install" \
        --target=x86_64-linux-musl \
        --disable-shared \
        --enable-static \
        CFLAGS="-O2 -fPIC"

    make -j"$JOBS"
    make install

    log "musl installed to $musl_install"
}

# ==============================================================================
# Stage 1: Build minimal Clang (host tools only)
# ==============================================================================

build_clang_stage1() {
    local llvm_src="$SRC_DIR/llvm-project-$LLVM_VERSION.src"
    local stage1_build="$BUILD_DIR/stage1"
    local stage1_install="$BUILD_DIR/stage1-install"

    if [ -f "$stage1_install/bin/clang" ]; then
        log "Stage 1 Clang already built, skipping."
        return
    fi

    log "Building Stage 1 Clang (host bootstrap)..."
    mkdir -p "$stage1_build"
    cd "$stage1_build"

    cmake -G "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$stage1_install" \
        -DLLVM_ENABLE_PROJECTS="clang;lld" \
        -DLLVM_TARGETS_TO_BUILD="X86" \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
        -DCLANG_ENABLE_ARCMT=OFF \
        "$llvm_src/llvm"

    cmake --build . --target install -j"$JOBS"

    log "Stage 1 Clang installed to $stage1_install"
}

# ==============================================================================
# Stage 2: Build static Clang + LLD with musl sysroot
# ==============================================================================

build_clang_stage2() {
    local llvm_src="$SRC_DIR/llvm-project-$LLVM_VERSION.src"
    local stage1_install="$BUILD_DIR/stage1-install"
    local stage2_build="$BUILD_DIR/stage2"
    local sysroot="$TOOLCHAIN_DIR/sysroot"

    if [ -f "$TOOLCHAIN_DIR/bin/clang" ]; then
        log "Stage 2 Clang already built, skipping."
        return
    fi

    log "Building Stage 2 Clang (static, musl-linked)..."
    mkdir -p "$stage2_build"
    cd "$stage2_build"

    cmake -G "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$TOOLCHAIN_DIR" \
        -DCMAKE_C_COMPILER="$stage1_install/bin/clang" \
        -DCMAKE_CXX_COMPILER="$stage1_install/bin/clang++" \
        -DCMAKE_EXE_LINKER_FLAGS="-static -L$sysroot/lib" \
        -DCMAKE_C_FLAGS="--sysroot=$sysroot -isystem $sysroot/include" \
        -DCMAKE_CXX_FLAGS="--sysroot=$sysroot -isystem $sysroot/include" \
        -DLLVM_ENABLE_PROJECTS="clang;lld" \
        -DLLVM_TARGETS_TO_BUILD="X86" \
        -DLLVM_BUILD_STATIC=ON \
        -DLLVM_STATIC_LINK_CXX_STDLIB=ON \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_DEFAULT_TARGET_TRIPLE="$TARGET" \
        -DCLANG_DEFAULT_LINKER="lld" \
        -DCLANG_DEFAULT_CXX_STDLIB="libc++" \
        -DCLANG_DEFAULT_RTLIB="compiler-rt" \
        -DCLANG_ENABLE_STATIC_ANALYZER=OFF \
        -DCLANG_ENABLE_ARCMT=OFF \
        "$llvm_src/llvm"

    cmake --build . --target install -j"$JOBS"

    log "Stage 2 Clang installed to $TOOLCHAIN_DIR"
}

# ==============================================================================
# Build libc++ and libc++abi (static, against musl)
# ==============================================================================

build_libcxx() {
    local llvm_src="$SRC_DIR/llvm-project-$LLVM_VERSION.src"
    local libcxx_build="$BUILD_DIR/libcxx"
    local sysroot="$TOOLCHAIN_DIR/sysroot"

    if [ -f "$TOOLCHAIN_DIR/lib/libc++.a" ]; then
        log "libc++ already built, skipping."
        return
    fi

    log "Building libc++ and libc++abi (static)..."
    mkdir -p "$libcxx_build"
    cd "$libcxx_build"

    cmake -G "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$TOOLCHAIN_DIR" \
        -DCMAKE_C_COMPILER="$TOOLCHAIN_DIR/bin/clang" \
        -DCMAKE_CXX_COMPILER="$TOOLCHAIN_DIR/bin/clang++" \
        -DCMAKE_C_FLAGS="--sysroot=$sysroot" \
        -DCMAKE_CXX_FLAGS="--sysroot=$sysroot" \
        -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
        -DLIBCXX_ENABLE_SHARED=OFF \
        -DLIBCXX_ENABLE_STATIC=ON \
        -DLIBCXX_HAS_MUSL_LIBC=ON \
        -DLIBCXX_USE_COMPILER_RT=ON \
        -DLIBCXX_ENABLE_EXCEPTIONS=OFF \
        -DLIBCXX_ENABLE_RTTI=OFF \
        -DLIBCXXABI_ENABLE_SHARED=OFF \
        -DLIBCXXABI_ENABLE_STATIC=ON \
        -DLIBCXXABI_USE_COMPILER_RT=ON \
        -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
        -DLIBCXXABI_ENABLE_EXCEPTIONS=OFF \
        -DLIBUNWIND_ENABLE_SHARED=OFF \
        -DLIBUNWIND_ENABLE_STATIC=ON \
        -DLIBUNWIND_USE_COMPILER_RT=ON \
        "$llvm_src/runtimes"

    cmake --build . --target install -j"$JOBS"

    log "libc++ installed to $TOOLCHAIN_DIR"
}

# ==============================================================================
# Build compiler-rt builtins (static, for the target)
# ==============================================================================

build_compiler_rt() {
    local llvm_src="$SRC_DIR/llvm-project-$LLVM_VERSION.src"
    local rt_build="$BUILD_DIR/compiler-rt"
    local sysroot="$TOOLCHAIN_DIR/sysroot"

    if [ -d "$TOOLCHAIN_DIR/lib/clang" ]; then
        log "compiler-rt already built, skipping."
        return
    fi

    log "Building compiler-rt builtins..."
    mkdir -p "$rt_build"
    cd "$rt_build"

    cmake -G "$CMAKE_GENERATOR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$TOOLCHAIN_DIR/lib/clang/$LLVM_VERSION" \
        -DCMAKE_C_COMPILER="$TOOLCHAIN_DIR/bin/clang" \
        -DCMAKE_CXX_COMPILER="$TOOLCHAIN_DIR/bin/clang++" \
        -DCMAKE_C_FLAGS="--sysroot=$sysroot" \
        -DCMAKE_ASM_FLAGS="--sysroot=$sysroot" \
        -DCOMPILER_RT_BUILD_BUILTINS=ON \
        -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
        -DCOMPILER_RT_BUILD_XRAY=OFF \
        -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
        -DCOMPILER_RT_BUILD_PROFILE=OFF \
        -DCOMPILER_RT_BUILD_MEMPROF=OFF \
        -DCOMPILER_RT_BUILD_ORC=OFF \
        -DCOMPILER_RT_DEFAULT_TARGET_TRIPLE="$TARGET" \
        -DCOMPILER_RT_BAREMETAL_BUILD=OFF \
        "$llvm_src/compiler-rt"

    cmake --build . --target install -j"$JOBS"

    log "compiler-rt installed."
}

# ==============================================================================
# Create wrapper scripts and verify
# ==============================================================================

create_wrappers() {
    log "Creating toolchain wrapper scripts..."

    # clang++ wrapper with default flags for StratOS userspace
    cat > "$TOOLCHAIN_DIR/bin/stratos-cc" << 'WRAPPER'
#!/bin/sh
# stratos-cc — StratOS C++ compiler wrapper
# Compiles C++ source to a static ELF binary for StratOS userspace
TOOLCHAIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SYSROOT="$TOOLCHAIN_DIR/sysroot"

exec "$TOOLCHAIN_DIR/bin/clang++" \
    --sysroot="$SYSROOT" \
    -target x86_64-linux-musl \
    -static \
    -fno-exceptions \
    -fno-rtti \
    -nostdinc++ \
    -isystem "$TOOLCHAIN_DIR/include/c++/v1" \
    -L"$TOOLCHAIN_DIR/lib" \
    -lc++ \
    -lc++abi \
    -lunwind \
    -O2 \
    "$@"
WRAPPER
    chmod +x "$TOOLCHAIN_DIR/bin/stratos-cc"

    log "Wrapper scripts created."
}

verify_toolchain() {
    log "Verifying toolchain..."

    if [ ! -f "$TOOLCHAIN_DIR/bin/clang" ]; then
        err "clang not found!"
        return 1
    fi

    if [ ! -f "$TOOLCHAIN_DIR/bin/ld.lld" ]; then
        err "lld not found!"
        return 1
    fi

    if [ ! -f "$TOOLCHAIN_DIR/lib/libc++.a" ]; then
        err "libc++.a not found!"
        return 1
    fi

    if [ ! -f "$TOOLCHAIN_DIR/sysroot/lib/libc.a" ]; then
        err "musl libc.a not found!"
        return 1
    fi

    # Test compile a simple program
    local test_src="$BUILD_DIR/test_hello.cpp"
    local test_bin="$BUILD_DIR/test_hello"

    cat > "$test_src" << 'TEST'
// Minimal freestanding test — no libc needed
extern "C" void _start() {
    // sys_write(1, "Hello from StratOS toolchain!\n", 30)
    const char* msg = "Hello from StratOS toolchain!\n";
    long ret;
    __asm__ volatile(
        "syscall"
        : "=a"(ret)
        : "a"(1), "D"(1), "S"(msg), "d"(30)
        : "rcx", "r11", "memory"
    );
    // sys_exit(0)
    __asm__ volatile(
        "syscall"
        :
        : "a"(60), "D"(0)
        : "rcx", "r11"
    );
}
TEST

    "$TOOLCHAIN_DIR/bin/clang++" \
        --sysroot="$TOOLCHAIN_DIR/sysroot" \
        -target x86_64-linux-musl \
        -static \
        -nostdlib \
        -ffreestanding \
        -fuse-ld=lld \
        -o "$test_bin" \
        "$test_src" 2>/dev/null

    if [ -f "$test_bin" ]; then
        local filetype
        filetype="$(file "$test_bin" 2>/dev/null)"
        if echo "$filetype" | grep -q "ELF 64-bit.*x86-64.*statically linked"; then
            log "Verification PASSED: Static ELF64 x86_64 binary produced."
        else
            warn "Binary produced but unexpected format: $filetype"
        fi
        rm -f "$test_bin" "$test_src"
    else
        err "Test compilation failed!"
        rm -f "$test_src"
        return 1
    fi

    log ""
    log "╔══════════════════════════════════════════════════╗"
    log "║  StratOS Toolchain Build Complete!               ║"
    log "║                                                  ║"
    log "║  Clang:      $TOOLCHAIN_DIR/bin/clang"
    log "║  LLD:        $TOOLCHAIN_DIR/bin/ld.lld"
    log "║  libc++:     $TOOLCHAIN_DIR/lib/libc++.a"
    log "║  musl:       $TOOLCHAIN_DIR/sysroot/lib/libc.a"
    log "║  Wrapper:    $TOOLCHAIN_DIR/bin/stratos-cc"
    log "║                                                  ║"
    log "║  To compile for StratOS:                         ║"
    log "║    stratos-cc hello.cpp -o hello                  ║"
    log "╚══════════════════════════════════════════════════╝"
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    log "StratOS Toolchain Builder"
    log "========================"
    log "LLVM:   $LLVM_VERSION"
    log "musl:   $MUSL_VERSION"
    log "Target: $TARGET"
    log "Jobs:   $JOBS"
    log ""

    check_prereqs

    mkdir -p "$TOOLCHAIN_DIR" "$BUILD_DIR" "$SRC_DIR"

    download_sources
    build_musl

    if $MUSL_ONLY; then
        log "musl-only build complete."
        exit 0
    fi

    build_clang_stage1
    build_clang_stage2
    build_libcxx
    build_compiler_rt
    create_wrappers
    verify_toolchain
}

main "$@"
