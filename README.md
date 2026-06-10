# QuickSnap

<p align="center">
  <img src="Resources/Brand/QuickSnapAppIcon_readme.png" alt="QuickSnap app icon" width="160">
</p>

<p align="center"><strong>Local-first screenshot capture, browser-aware Markdown clipping, and knowledge capture for macOS.</strong></p>

<p align="center">
  <a href="https://github.com/stp9000/quicksnap/releases/latest">Download Latest Release</a>
  ·
  <a href="PRIVACY.md">Privacy</a>
  ·
  <a href="CONTRIBUTING.md">Contributing</a>
  ·
  <a href="CHANGELOG.md">Changelog</a>
</p>

QuickSnap is a macOS app for turning screenshots and browser pages into a searchable local workspace. It keeps captures on disk, indexes OCR and metadata in SQLite, writes Markdown files to folders you control, and can feed those captures into a local wiki-style knowledge base.

## Why QuickSnap

- Capture the full screen, the frontmost window, or a selected region.
- Import existing images into the same searchable library.
- Search by OCR text, title, source app, preset, tag, and metadata.
- Generate browser-aware Markdown captures with page metadata when supported.
- Draft bug reports from captures and export or reveal related files quickly.
- Save Markdown captures into a local Knowledge Wiki structure for later re-ingest.

## Install

1. Download the latest release from [GitHub Releases](https://github.com/stp9000/quicksnap/releases/latest).
2. Unzip the archive.
3. Move `QuickSnap.app` to `/Applications`.
4. Open the app.

QuickSnap does not require Xcode or a local Swift or Node.js toolchain for normal use.

## Permissions

QuickSnap requests macOS permissions only when a feature needs them:

- `Screen Recording` for display, window, and region capture.
- `Automation` for supported browsers when reading page URL, title, HTML, and related metadata for browser-aware Markdown capture.
- Standard open/save panel access when importing images or choosing export locations.

## How It Stores Data

QuickSnap is local-first:

- Capture images live under your configured capture storage root.
- The SQLite library lives beside the capture assets.
- Generated Markdown files use a separate configurable folder.
- Knowledge Wiki files can use their own configured folder or fall back to the Markdown storage root.
- OpenAI and GitHub tokens are stored in the macOS Keychain, not in the SQLite database.

More detail is in [PRIVACY.md](PRIVACY.md).

## Development

QuickSnap is a Swift package targeting macOS 13+.

### Requirements

- macOS 13+
- Xcode command line tools with `swift`
- `iconutil` if you need to rebuild app icons locally

### Run From Source

```bash
swift run
```

### Build The App

```bash
swift build
./scripts/build_app.sh
```

This produces `build/QuickSnap.app`.

## Repository Docs

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Privacy and Permissions](PRIVACY.md)
- [Changelog](CHANGELOG.md)
