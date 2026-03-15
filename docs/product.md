# QuickSnap Product

QuickSnap is evolving from a screenshot annotation utility into a local-first macOS capture-and-search product.

The current app is the starting shell, not the final product shape. Existing capture, annotation, and export flows remain useful, but the core value is shifting toward durable `Capture Object`s that can be stored, searched, and reused in documentation workflows.

## Product Summary

QuickSnap should become the fastest way to capture, organize, and reuse UI from your screen.

Instead of treating a screenshot as a throwaway PNG, QuickSnap should treat every capture as a structured record with image data, metadata, searchable text, and export-friendly context.

## Product Position

- Primary value: local capture plus searchable history
- Secondary value: lightweight annotation and export tools
- Explicit non-MVP areas: AI features, BYO-LLM, cloud sync, medical-specific workflows, remote analysis

## Target Users

- Primary: developers and technical builders
- Secondary: product managers, founders, and designers
- Tertiary: support and operations teams that frequently reference UI states

## Core Principles

- Speed over ceremony
- Local-first by default
- Searchability over file sprawl
- Workflow compatibility over feature bloat
- Annotation as support, not the center of the product

## Canonical Model: Capture Object

`Capture Object` is the internal product primitive used across capture, storage, search, and export.

Suggested MVP fields:

- Stable capture ID
- Image path
- Created timestamp
- Source app name
- Window title
- Dimensions
- OCR text
- User tags
- Optional URL when available

Example:

```json
{
  "id": "cap_84291",
  "image_path": "/captures/login-error.png",
  "timestamp": "2026-03-13T11:43:22Z",
  "app": "Chrome",
  "window_title": "Login - MyProduct",
  "url": "https://app.example.com/login",
  "ocr_text": "Invalid password",
  "tags": ["login", "error"],
  "dimensions": "1280x720"
}
```

## MVP Scope

Include:

- Full-screen, region, and window capture
- Persistent local capture storage
- Metadata extraction
- OCR indexing
- Searchable history and timeline views
- Markdown-oriented export and clipboard workflows
- Existing annotation and PNG export as supporting capability

Exclude:

- Cloud sync or hosted storage
- AI tagging or AI summarization
- BYO-LLM configuration
- Remote sharing systems as a required core path
- Vertical-specific workflow customization

## MVP User Experience

1. Capture an image from the screen.
2. Persist the image to an app-managed location.
3. Extract metadata and OCR text.
4. Save the result as a `Capture Object`.
5. Surface the capture in a searchable history.
6. Reuse the capture through annotation, copy, export, file path, or Markdown output.

## Architecture Direction

The implementation should separate:

- capture generation
- metadata and OCR enrichment
- persistence
- query and history UI
- export/output modes

The search/history product should not depend on raw file paths alone. Persistence should sit behind a boundary that lets the UI reason about `Capture Object`s rather than ad hoc exported files.

## Documentation Guidance

This file is the canonical product definition.

When implementation details change, align these documents next:

- [roadmap.md](/Users/steve/Documents/QuickSnapApp/docs/roadmap.md)
- [ARCHITECTURE.md](/Users/steve/Documents/QuickSnapApp/docs/ARCHITECTURE.md)
- [RELEASE.md](/Users/steve/Documents/QuickSnapApp/docs/RELEASE.md)
- [PRIVACY.md](/Users/steve/Documents/QuickSnapApp/PRIVACY.md)
