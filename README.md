# QuickSnap

<p align="center">
  <img src="Resources/Brand/QuickSnapMark_readme.png" alt="QuickSnap app icon" width="144">
</p>

QuickSnap is a local-first macOS capture workspace for screenshots, browser-aware Markdown capture, bug-report drafting, and wiki-style knowledge building. It stores captures on disk, indexes OCR and metadata in SQLite for search, and keeps the capture library, generated Markdown, and Knowledge Wiki files under folders you control.

[Download the latest notarized release](https://github.com/stp9000/quicksnap/releases/latest)

## Install QuickSnap

1. Download `QuickSnap-v0.1.6-macOS-notarized.zip` from [GitHub Releases](https://github.com/stp9000/quicksnap/releases/latest).
2. Unzip the archive.
3. Drag `QuickSnap.app` into `/Applications`.
4. Open the app.

QuickSnap does not require Xcode, developer mode, or a local Swift or Node.js toolchain for normal use. Public releases are signed, notarized, and stapled for Gatekeeper.

### Permissions

QuickSnap will prompt for macOS permissions only when needed:

- `Screen Recording` to capture the display, a window, or a screen selection.
- `Automation` for supported browsers when QuickSnap reads page URL, title, HTML, and metadata for browser-aware captures.
- standard open/save panels when you import an image or choose export locations.

## Current Features

### Capture workspace

- Capture the main display, frontmost window, or a selected screen region.
- Import existing images into the same searchable library.
- Store captures locally with SQLite-backed metadata, OCR text, tags, annotations, and timeline history.
- Search captures by OCR text, source app, title, preset, tag, and metadata.
- Annotate captures with pen, rectangle, arrow, and text tools.
- Use built-in presets: `General`, `Bug Report`, and `Markdown`.

### Browser Markdown capture

- Generate Markdown captures from supported browser pages using full-page HTML extraction when available.
- Preserve browser metadata including URL, canonical URL, title, site, author, published date, description, word count, and extraction status.
- Pair the visible screenshot with full-page browser context, so the Markdown scope is not limited to the screenshot crop or visible viewport.
- Turn selection captures into Markdown using OCR when no page clip is available.

### Knowledge Wiki

- Save Markdown captures into a configurable local Knowledge Wiki structure and re-ingest later from the inspector.
- Align wiki ingest with entity/concept pages, capture evidence links, and raw clip references when available.
- Use a dedicated Knowledge Wiki folder, avoiding duplicated layouts such as `wiki/wiki`.

### Bug reports and sharing

- Draft GitHub issues from bug-report captures, including copy/export actions and screenshot handoff.
- Track optional cloud asset upload status without changing the local-first storage model.
- Reveal capture assets, Markdown files, and storage folders in Finder.

## Storage Model

QuickSnap is local-first:

- capture images live under the configured capture storage root
- the SQLite library lives beside the capture assets
- generated Markdown files use a separate configurable folder
- Knowledge Wiki files can use their own configured folder or fall back to the Markdown storage root
- OpenAI and GitHub tokens are stored in the macOS Keychain, not in the SQLite database
- the bundled Markdown helper runs from the app bundle using a pinned official Node LTS runtime

See [PRIVACY.md](PRIVACY.md) for the full permissions and storage summary.

## Develop QuickSnap

Use this path if you want to run QuickSnap from source, make local changes, or contribute.

### Requirements

- macOS 13+
- Xcode command line tools (`swift`, `iconutil`)
- network access during packaging to fetch the pinned official Node runtime used by the bundled Markdown helper

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

The app bundle includes a pinned official Node LTS runtime for the Markdown helper. Packaging does not depend on your locally installed Node.js runtime.

## Release QuickSnap

Public releases should ship the notarized archive only:

- `dist/QuickSnap-v<version>-macOS-notarized.zip`

QuickSnap still includes an unsigned packaging script for local maintainer/testing workflows, but that archive is not intended to be the primary public download.

Releases are currently signed and notarized manually on a maintainer Mac, then uploaded to GitHub Releases.

Latest release:

- Version: `0.1.6`
- Artifact: [`QuickSnap-v0.1.6-macOS-notarized.zip`](https://github.com/stp9000/quicksnap/releases/download/v0.1.6/QuickSnap-v0.1.6-macOS-notarized.zip)
- SHA-256: `084c2c7614594fff4d21ec6c144a335fe744b2e9ccb55362ecf92594761cadca`

## Repository Docs

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Privacy and Permissions](PRIVACY.md)
- [Changelog](CHANGELOG.md)
