# Changelog

All notable changes to QuickSnap should be recorded in this file.

The format is based on Keep a Changelog, and QuickSnap uses semantic versions for `CFBundleShortVersionString`.

## [Unreleased]

## [0.1.6] - 2026-06-10

### Added
- Added the new QuickSnap app icon and brand assets to the packaged app and README.
- Added richer browser Markdown metadata, including canonical URL, site name, author, published date, word count, and source HTML sizing.
- Added configurable Knowledge Wiki storage so local wiki pages can live outside a duplicated `wiki/wiki` folder layout.
- Added wiki ingest alignment for entity/concept pages, capture evidence links, and raw clip references.
- Added cloud asset upload support with persisted cloud status in the capture workspace.

### Changed
- Made full-page browser HTML extraction the authoritative Markdown source when available, with article clipping and OCR as fallbacks.
- Refined the SwiftUI capture workspace layout and library cards.
- Updated app packaging to bundle a pinned official Node LTS runtime instead of rewriting Homebrew/runtime dylib dependencies.
- Reduced startup blocking by moving Keychain-dependent work off the initial launch path.

### Fixed
- Hardened the Obsidian-style Markdown helper output parsing and pipe handling.
- Fixed packaged helper runtime signing so Markdown extraction works from the standard `build/QuickSnap.app` bundle.

## [0.1.5] - 2026-04-15

### Changed
- Reframed the public docs around the current app: local-first capture library, Markdown export, wiki ingest, and GitHub issue drafting.
- Cleaned the repository for open-source release readiness by removing generated SwiftPM Xcode workspace files and clarifying release/install guidance.
- Updated release guidance so public releases center the notarized macOS archive and use a manual maintainer-driven release flow.

### Fixed
- Signed the bundled helper runtime inside-out during notarized release builds so the notarized app can pass Apple validation successfully.

## [0.1.4] - 2026-03-15

### Added
- Persistent capture library with SQLite-backed metadata, OCR indexing, browser URL capture, and searchable history.
- Markdown capture flow with separate Markdown storage and browser-aware clipping.
- Wiki ingest support that turns captures into local Markdown wiki pages.
- GitHub issue drafting from bug-report captures.
- Packaging, privacy, security, and release documentation.

### Changed
- Simplified the workspace panel and artifact flow around Markdown and GitHub issue outputs.
- Improved helper packaging so the app can bundle the runtime needed for Markdown extraction.

### Fixed
- Reduced redundant export/file-writing behavior during drag/export flows.
- Improved Markdown fallback behavior for selections and OCR-driven captures.
