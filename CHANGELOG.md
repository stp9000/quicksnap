# Changelog

All notable changes to QuickSnap should be recorded in this file.

The format is based on Keep a Changelog, and QuickSnap uses semantic versions for `CFBundleShortVersionString`.

## [Unreleased]

### Added
- Added a tag-triggered GitHub Release workflow that publishes the unsigned macOS zip from `VERSION` and `CHANGELOG.md`.

### Changed
- Consolidated release versioning around the `VERSION` file and removed redundant repo assets/docs.

## [0.1.4] - 2026-03-15

### Added
- Added a persistent capture library with SQLite-backed metadata, OCR indexing, browser URL capture, and searchable history.
- Added a right-side workspace panel for manual local or OpenAI-powered analysis plus send-preview workflows.
- Added browser-based GitHub issue sending through prefilled `issues/new` URLs with configurable owner, repo, and labels.
- Added a themed Settings window for storage, AI, GitHub, and custom preset configuration.
- Added release, privacy, architecture, roadmap, Apple-readiness, and GitHub setup documentation along with packaging/notarization scripts and GitHub workflows.

### Changed
- Refocused QuickSnap around `General` and `Bug Report` presets, with older `UI Issue` captures treated as `Bug Report`.
- Updated capture cards to use source-based display IDs like `Safari - QS00001` and removed OCR snippet text from the library cards.
- Changed the workspace behavior so opening the side panel no longer auto-runs analysis; analysis is now triggered manually.
- Improved custom preset templates so added field names automatically append matching placeholders.

### Fixed
- Normalized metadata collection across full-screen, selection, and window capture flows so they share the same baseline enrichment path.
- Fixed OpenAI BYO-key connection handling and surfaced clearer connection feedback in Settings.
- Improved browser metadata capture with page title and viewport enrichment when supported.

## [0.1.3] - 2026-03-11

### Added
- Repository governance and Apple-readiness documentation.
