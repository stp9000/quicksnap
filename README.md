# QuickSnap

![QuickSnap icon](Resources/Brand/QuickSnapMark_readme.png)

QuickSnap is a local-first macOS capture workspace for screenshots, web clipping, Markdown export, and wiki-style knowledge building. It stores captures on disk, indexes OCR and metadata in SQLite for search, and keeps the capture library, generated Markdown, and wiki files under folders you control.

## Install QuickSnap

1. Download the latest `QuickSnap-v<version>-macOS-notarized.zip` from [GitHub Releases](https://github.com/stp9000/quicksnap/releases).
2. Unzip the archive.
3. Drag `QuickSnap.app` into `/Applications`.
4. Open the app.

QuickSnap does not require Xcode, developer mode, or a local Swift toolchain for normal use.

### Permissions

QuickSnap will prompt for macOS permissions only when needed:

- `Screen Recording` to capture the display, a window, or a screen selection.
- `Automation` for supported browsers when QuickSnap reads page metadata for browser-aware captures.
- standard open/save panels when you import an image or choose export locations.

## Current Features

- Capture the main display, frontmost window, or a selected screen region.
- Import existing images into the same searchable library.
- Store captures locally with SQLite-backed metadata, OCR text, tags, annotations, and timeline history.
- Search captures by OCR text, source app, title, preset, tag, and metadata.
- Annotate captures with pen, rectangle, arrow, and text tools.
- Use built-in presets: `General`, `Bug Report`, and `Markdown`.
- Generate Markdown captures from supported browser pages and save `.md` files to a configurable Markdown folder.
- Turn selection captures into Markdown using OCR when no page clip is available.
- Save Markdown captures into a local `wiki/` structure and re-ingest later from the inspector.
- Draft GitHub issues from bug-report captures, including copy/export actions and screenshot handoff.
- Reveal capture assets, Markdown files, and storage folders in Finder.

## Storage Model

QuickSnap is local-first:

- capture images live under the configured capture storage root
- the SQLite library lives beside the capture assets
- generated Markdown files use a separate configurable folder
- wiki files live under the Markdown storage root
- OpenAI and GitHub tokens are stored in the macOS Keychain, not in the SQLite database

See [PRIVACY.md](PRIVACY.md) for the full permissions and storage summary.

## Develop QuickSnap

Use this path if you want to run QuickSnap from source, make local changes, or contribute.

### Requirements

- macOS 13+
- Xcode command line tools (`swift`, `iconutil`)
- Node.js for packaging the bundled Markdown helper

### Run from source

```bash
swift run
```

### Build locally

```bash
swift build
./scripts/build_app.sh
```

This creates:

- `build/QuickSnap.app`

## Release QuickSnap

Public releases should ship the notarized archive only:

- `dist/QuickSnap-v<version>-macOS-notarized.zip`

QuickSnap still includes an unsigned packaging script for local maintainer/testing workflows, but that archive is not intended to be the primary public download.

Releases are currently signed and notarized manually on a maintainer Mac, then uploaded to GitHub Releases.

## Repository Docs

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Privacy and Permissions](PRIVACY.md)
- [Changelog](CHANGELOG.md)
