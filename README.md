# Pulp

Image compression and format conversion that's instant, native, and stays out of your way. No upload, no ads, no signup — drop a file in, get a smaller one out.

> Status: early. macOS-only for now. Windows and Linux are planned via a Tauri shell that links the same Rust core.

## Download

- **[Latest build](https://github.com/migoll/pulp/releases/tag/latest)** — built from `main` on every push.
- **[Tagged releases](https://github.com/migoll/pulp/releases)** — versioned snapshots.

Apple Silicon only for now.

### Running an unsigned build

Pulp isn't signed by an Apple Developer ID (the $99/year membership), so macOS Gatekeeper will block it the first time you open it. Pick one:

- Right-click `Pulp.app` → **Open** → confirm in the dialog.
- Or strip the quarantine flag once:
  ```bash
  xattr -cr /path/to/Pulp.app
  ```

## Why

Most image-compression tools are random web apps with ads and a 5 MB upload cap. Pulp is a desktop app, runs entirely offline, and is fast because it decodes once and re-encodes from the in-memory pixel buffer every time you change a setting.

## Architecture

```
core/   →  Rust library. Decode, encode, resize. Exposes a small C ABI.
macos/  →  SwiftUI app. Liquid Glass UI, links the Rust core as a static lib.
```

Adding Windows/Linux later means writing a second thin shell (Tauri) that calls the same `core/` library. Image processing stays in one place.

### Pixel pipeline

1. **Decode once.** Source bytes go to the Rust core (or to ImageIO on macOS for HEIC/AVIF) and become a single RGBA8 buffer held in memory.
2. **Re-encode on demand.** Format, quality, and dimension changes hit the encoder, not the decoder. That's why it feels live.
3. **Save.** Either click an individual image, or "Save All" to dump everything into a folder.

## Building

You need Rust, Xcode 26+, and `xcodegen`:

```bash
# One-time setup
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
brew install xcodegen

# Generate the Xcode project and open it
cd macos
xcodegen generate
open Pulp.xcodeproj
```

Hit **Run**. Xcode will build the Rust core via a pre-build script and link it into the app.

For a universal release binary:

```bash
UNIVERSAL=1 scripts/build-core.sh
```

## Releasing

Pushes to `main` automatically rebuild the rolling **Latest build** release. To cut a versioned release, tag the commit and push the tag:

```bash
git tag v0.1.1
git push --tags
```

GitHub Actions builds the app and creates a permanent release with auto-generated notes.

To regenerate the AppIcon set after editing `assets/icons/pulp-dark.png` or
`assets/icons/pulp-transparent.png`:

```bash
scripts/build-icons.sh
```

The light variant is composited on the fly (transparent design over `#f1f1f1`),
so you only need to maintain the dark and transparent originals.

## Supported formats

| Format | Decode | Encode |
|--------|--------|--------|
| JPEG   | ✓      | ✓      |
| PNG    | ✓      | ✓      |
| WebP   | ✓      | ✓      |
| AVIF   | via ImageIO | ✓ |
| HEIC   | via ImageIO | — (patent-encumbered) |
| TIFF, GIF, BMP | ✓ | — |

## Roadmap

- [ ] Cropper
- [ ] Custom user presets
- [ ] Tauri shell for Windows / Linux
- [ ] Video (separate project — ffmpeg territory)

## License

Not licensed yet — pending.
