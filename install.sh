#!/usr/bin/env bash
# Pulp installer.
#
# Downloads the latest release, strips macOS's quarantine flag, moves the app
# into /Applications, and launches it. Replaces any existing install.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/migoll/pulp/main/install.sh | bash
#
# Pin to a specific release:
#   curl -fsSL https://raw.githubusercontent.com/migoll/pulp/main/install.sh | bash -s -- v0.1.0
#   curl -fsSL https://raw.githubusercontent.com/migoll/pulp/main/install.sh | bash -s -- latest

set -euo pipefail

REPO="migoll/pulp"
APP="Pulp.app"
INSTALL_DIR="/Applications"
TAG="${1:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Pulp is macOS only." >&2
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "Pulp currently ships Apple Silicon only (detected $(uname -m))." >&2
    echo "Open an issue if you need an Intel build." >&2
    exit 1
fi

if [[ -n "$TAG" ]]; then
    api="https://api.github.com/repos/$REPO/releases/tags/$TAG"
else
    api="https://api.github.com/repos/$REPO/releases/latest"
fi

echo "Resolving release..."
zip_url="$(curl -fsSL "$api" \
    | grep -oE '"browser_download_url":[[:space:]]*"[^"]+\.zip"' \
    | head -1 \
    | sed -E 's/.*"(https[^"]+)".*/\1/')"

if [[ -z "$zip_url" ]]; then
    echo "Couldn't find a .zip asset on the release. Aborting." >&2
    exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Downloading $zip_url"
curl -fL --progress-bar "$zip_url" -o "$work/pulp.zip"

echo "Extracting..."
unzip -q -o "$work/pulp.zip" -d "$work"

if [[ ! -d "$work/$APP" ]]; then
    echo "$APP not found inside the zip. Aborting." >&2
    exit 1
fi

echo "Removing quarantine flag..."
xattr -cr "$work/$APP"

dest="$INSTALL_DIR/$APP"

if [[ -w "$INSTALL_DIR" ]]; then
    [[ -d "$dest" ]] && rm -rf "$dest"
    mv "$work/$APP" "$dest"
else
    echo "$INSTALL_DIR isn't writable — escalating with sudo."
    sudo rm -rf "$dest"
    sudo mv "$work/$APP" "$dest"
fi

echo "Installed to $dest"
echo "Launching..."
open "$dest"
