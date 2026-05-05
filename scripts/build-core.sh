#!/usr/bin/env bash
# Build the Rust core as a static library Xcode can link against.
#
# Defaults to a release build for the host architecture, which is what Xcode's
# pre-build phase wants. Set ARCHS="arm64 x86_64" before invoking to produce a
# universal binary at core/target/universal/release/libpulp_core.a — used for
# release packaging.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/core"
ARCHS="${ARCHS:-host}"

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

if [[ "$ARCHS" == "host" ]]; then
    cargo build --release
    exit 0
fi

OUT_DIR="$CORE_DIR/target/universal/release"
mkdir -p "$OUT_DIR"

ARTIFACTS=()
for arch in $ARCHS; do
    case "$arch" in
        arm64)  triple="aarch64-apple-darwin" ;;
        x86_64) triple="x86_64-apple-darwin" ;;
        *) echo "error: unknown arch '$arch'" >&2; exit 1 ;;
    esac
    rustup target add "$triple" >/dev/null
    cargo build --release --target "$triple"
    ARTIFACTS+=("$CORE_DIR/target/$triple/release/libpulp_core.a")
done

lipo -create "${ARTIFACTS[@]}" -output "$OUT_DIR/libpulp_core.a"
