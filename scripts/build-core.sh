#!/usr/bin/env bash
# Build the Rust core as a static library Xcode can link against.
#
# Default: host-arch release build into core/target/release/. This is what
# Xcode's pre-build phase invokes — it doesn't care about Xcode's ARCHS
# variable so it always produces a predictable output path.
#
# Universal builds (for release packaging): UNIVERSAL=1 scripts/build-core.sh.
# Output goes to core/target/universal/release/libpulp_core.a.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/core"

if ! command -v cargo >/dev/null; then
    if [[ -f "$HOME/.cargo/env" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    else
        echo "error: cargo not found. Install Rust from https://rustup.rs" >&2
        exit 1
    fi
fi

cd "$CORE_DIR"

if [[ "${UNIVERSAL:-0}" != "1" ]]; then
    cargo build --release
    exit 0
fi

OUT_DIR="$CORE_DIR/target/universal/release"
mkdir -p "$OUT_DIR"

rustup target add aarch64-apple-darwin x86_64-apple-darwin >/dev/null
cargo build --release --target aarch64-apple-darwin
cargo build --release --target x86_64-apple-darwin

lipo -create \
    "$CORE_DIR/target/aarch64-apple-darwin/release/libpulp_core.a" \
    "$CORE_DIR/target/x86_64-apple-darwin/release/libpulp_core.a" \
    -output "$OUT_DIR/libpulp_core.a"
