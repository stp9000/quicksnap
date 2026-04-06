# QuickSnap

![QuickSnap icon](Resources/Brand/QuickSnapMark_readme.png)

QuickSnap is a local-first macOS structured capture tool with persistent screenshot history, metadata, OCR-backed search, preset-driven workflows, lightweight annotation, and documentation-friendly export.

## Current App

Today, QuickSnap already supports:

- Open any image and annotate it
- Capture the main display, frontmost window, or a screen selection
- Import existing images into the same local capture library
- Store captures in an app-managed local library with SQLite-backed metadata
- Choose the storage location for captures and the SQLite library from the app's Settings window
- Attach built-in capture presets like `UI Issue`, `Console Error`, `Documentation`, `Product Research`, and `Table Capture`
- Search captures by OCR text, preset, app name, title, kind, tags, and timestamp
- Automatically store the active page URL when a supported browser is frontmost during capture
- Filter the timeline by capture type or missing files
- Reopen older captures from a built-in timeline sidebar
- Edit capture tags, preset fields, and structured metadata in the inspector
- Draw with pen, rectangle, and arrow tools
- Export annotated output as PNG
- Copy rendered images, file paths, Markdown snippets, and full Markdown documents
- Generate issue-style drafts for `UI Issue` and `Console Error` presets
- Export table captures as JSON or CSV clipboard formats
- Export Markdown files for stored captures and reveal source assets in Finder
- Open a unified right-side workspace panel for AI analysis and Send previews
- Save a personal OpenAI API key in Settings for BYO analysis
- Create lightweight custom presets in Settings with field lists and export templates
- Build a launchable `.app` bundle with a custom app icon

## Product Direction

QuickSnap is built around persistent `Capture Object`s and `Capture Preset`s:

- capture screenshots into app-managed storage
- retain metadata and OCR text for search
- shape capture fields and outputs through preset schemas
- build a searchable history/timeline
- support Markdown-oriented reuse in developer workflows

Annotation remains part of the product, but no longer defines the primary value proposition.

## End-User Install (No Swift/Xcode Required)

1. Download the latest `QuickSnap-v<version>-macOS-unsigned.zip` asset from GitHub Releases.
2. Unzip the archive.
3. Drag `QuickSnap.app` into `/Applications`.
4. Open the app.

If macOS blocks launch, right-click `QuickSnap.app` -> `Open` -> `Open`.

### Screen Recording Permission
QuickSnap needs macOS Screen Recording permission to capture your display.  
The first time you capture, macOS will prompt you to allow access in **System Settings -> Privacy & Security -> Screen Recording**.

Note: Permission usually persists for the installed app. If you install a new unsigned build/version, macOS may ask again.

## Project Structure

- `Sources/QuickSnap/` — Swift source for app logic and UI.
- `Resources/` — app icon and brand assets.
- `scripts/` — helper scripts for icon generation and `.app` bundle creation.

## Privacy & Data Handling

QuickSnap processes captures and annotations locally on-device. Screen captures are stored in a local library you can configure in Settings, exports are written only when you trigger them, and drag export also archives a copy under `~/Pictures/QuickSnap`.

See [Privacy and Permissions](PRIVACY.md) for the full permissions, storage, and disclosure summary.

## Development Requirements

- macOS 13+
- Xcode command line tools (`swift`, `iconutil`)

## Run During Development

```bash
swift run
```

## Build a Launchable App Bundle

```bash
./scripts/build_app.sh
```

To create a versioned unsigned zip for releases:

```bash
./scripts/package_release.sh
```

Brand assets (logo + mark) live in `Resources/Brand/`.

This creates:

- `build/QuickSnap.app`

You can launch it from Finder or with:

```bash
open build/QuickSnap.app
```

## Repository Policies

- [Contributing Guide](CONTRIBUTING.md)
- [Security Policy](SECURITY.md)
- [Privacy and Permissions](PRIVACY.md)
- [Changelog](CHANGELOG.md)
