#!/usr/bin/env bash
# Regenerate the AppIcon set from the source PNGs in assets/icons/.
#
# Inputs:
#   assets/icons/pulp-dark.png         the original dark-background design
#   assets/icons/pulp-transparent.png  the original transparent-background design
#
# The light variant is composited on the fly: the transparent design over a
# #f1f1f1 background.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES="$ROOT/assets/icons"
ICONSET="$ROOT/macos/Pulp/Resources/Assets.xcassets/AppIcon.appiconset"

DARK_SRC="$SOURCES/pulp-dark.png"
TRANSPARENT_SRC="$SOURCES/pulp-transparent.png"

if [[ ! -f "$DARK_SRC" || ! -f "$TRANSPARENT_SRC" ]]; then
    echo "error: missing source icons in $SOURCES" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Composite the transparent design over #f1f1f1 to make the light master.
swift - "$TRANSPARENT_SRC" "$WORK/master-light.png" <<'SWIFT'
import AppKit

let args = CommandLine.arguments
let input = args[1]
let output = args[2]

let bg = NSColor(red: 0xF1/255.0, green: 0xF1/255.0, blue: 0xF1/255.0, alpha: 1.0)
let target = NSSize(width: 1024, height: 1024)

guard let src = NSImage(contentsOfFile: input) else { exit(1) }
let canvas = NSImage(size: target)
canvas.lockFocus()
bg.setFill()
NSRect(origin: .zero, size: target).fill()
src.draw(in: NSRect(origin: .zero, size: target),
         from: NSRect(origin: .zero, size: src.size),
         operation: .sourceOver,
         fraction: 1.0)
canvas.unlockFocus()

let bitmap = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: output))
SWIFT

# Resize the dark source to 1024 to match the light master.
sips -z 1024 1024 "$DARK_SRC" --out "$WORK/master-dark.png" >/dev/null

for size in 16 32 64 128 256 512 1024; do
    sips -z "$size" "$size" "$WORK/master-light.png" \
        --out "$ICONSET/icon-light-$size.png" >/dev/null
    sips -z "$size" "$size" "$WORK/master-dark.png" \
        --out "$ICONSET/icon-dark-$size.png" >/dev/null
done

echo "AppIcon regenerated → $ICONSET"
