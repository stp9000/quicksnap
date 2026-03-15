# QuickSnap Product Realignment Plan

## Summary

Reposition QuickSnap from an annotation-first screenshot utility into a macOS capture-and-search product defined by `Capture Object`s. Treat the current app as a functional prototype to evolve from, not the final product shape. Normalize documentation to `docs/product.md` and `docs/roadmap.md`, and use the new spec as the canonical source of truth. Keep AI, BYO-LLM, and medical-specific workflows out of MVP; design only enough extension room to add them after the capture/search foundation is stable.

Status: promoted into canonical docs at `docs/product.md` and `docs/roadmap.md`. Keep this file for working notes and future direction changes.

## Key Changes

### Product and docs
- Rename the existing product docs to `docs/product.md` and `docs/roadmap.md`.
- Update the main README to match the new product position: capture, metadata, OCR, searchable history, Markdown export.
- Move annotation features into a secondary section of the product narrative so they are framed as supporting tools, not the core value proposition.
- Align roadmap phases to the new strategy: Core Capture, Knowledge Layer, Developer Workflow, Sharing, AI Layer, Platform Expansion.

### Application direction
- Preserve current screenshot capture, selection capture, export, and annotation code as the starting shell.
- Add a persistent local `Capture Object` store as the new product backbone:
  - stable capture ID
  - image path
  - timestamp
  - source app
  - window title
  - dimensions
  - OCR text
  - user tags
  - optional URL field when available
- Introduce a capture ingestion pipeline:
  - capture image
  - persist image asset
  - extract metadata
  - run OCR
  - save searchable record
  - surface in history/search UI
- Keep annotations editable per capture, but do not make annotation expansion the next milestone.

### MVP implementation milestones
- Milestone 1: capture foundation
  - unify full-screen, region, and window capture behavior
  - define the `Capture Object` model and local storage layout
  - store captures under an app-managed directory instead of only ad hoc export flows
- Milestone 2: knowledge layer
  - add local database persistence, preferably SQLite
  - index OCR text, titles, tags, timestamps, and app name
  - build a searchable history/timeline UI inside the app
- Milestone 3: workflow output
  - add Markdown clipboard/export support
  - support copy-image, copy-file-path, and Markdown-link output modes
  - keep release/distribution docs aligned with the new feature set
- Milestone 4: polish and readiness
  - clarify privacy language around stored captures, OCR, and local indexing
  - validate permissions, storage behavior, and release scripts against the new app behavior

### Public interfaces and data shape
- Define `Capture Object` as the canonical internal model and use it across capture, storage, search, and export paths.
- Introduce a persistence layer boundary so capture generation and search UI do not depend directly on file paths alone.
- Reserve optional fields for future enrichment, but do not implement AI-specific schemas in MVP.
- Do not add cloud sync, remote analysis, or research-database integrations in this phase.

## Test Plan

- Capture scenarios:
  - full-screen capture creates a persisted `Capture Object`
  - region capture creates a persisted `Capture Object`
  - window capture behaves consistently with metadata capture
- Persistence scenarios:
  - app restart preserves capture history
  - missing image files are handled gracefully in history/search views
  - duplicate timestamps do not collide on IDs or file paths
- Search scenarios:
  - OCR text is searchable
  - app/title/tag filters work independently and together
  - empty-state and no-results behavior is clear
- Export/workflow scenarios:
  - Markdown export generates the expected output format
  - clipboard/export actions work from both fresh captures and historical captures
- Regression scenarios:
  - existing annotation and PNG export flows still work on stored captures
  - packaging/build scripts still produce a valid app bundle after the storage changes

## Assumptions

- The new docs are the product source of truth.
- Final canonical doc names should be `docs/product.md` and `docs/roadmap.md`.
- MVP excludes AI, BYO-LLM, cloud sharing, medical workflows, and external research integrations.
- The current app’s annotation features remain in scope only as supporting capability.
- SQLite is the default persistence choice unless a repo-level constraint appears during implementation.
