#!/bin/bash
# Build and run the Quantum Package Server
# Usage: ./run_server.sh [port] [packages_dir]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_SRC="$SCRIPT_DIR/quantum_server.cpp"
SERVER_BIN="$SCRIPT_DIR/quantum_server"

PORT="${1:-9090}"
PKG_DIR="${2:-$SCRIPT_DIR/../packages}"

# Build if needed
if [ ! -f "$SERVER_BIN" ] || [ "$SERVER_SRC" -nt "$SERVER_BIN" ]; then
    echo "Building Quantum Package Server..."
    g++ -O2 -std=c++17 -o "$SERVER_BIN" "$SERVER_SRC" -lssl -lcrypto
    if [ $? -ne 0 ]; then
        echo "Build failed. Install OpenSSL: sudo apt install libssl-dev"
        exit 1
    fi
    echo "Build complete."
fi

echo "Starting Quantum Package Server on port $PORT..."
exec "$SERVER_BIN" "$PORT" "$PKG_DIR"
