# Architecture Notes

QuickSnap is a Swift Package macOS app centered around a single document-style state object that owns the active canvas, capture library selection, preset selection, annotation state, and export behavior.

## Core pieces

- `CapturePresets.swift` defines built-in presets, lightweight custom preset definitions, and structured preset payloads.
- `CaptureLibrary.swift` contains the persistent `Capture Object` model, preset-aware SQLite repository, frontmost-window metadata lookup, and OCR pipeline hook.
- `AnnotationModels.swift` contains the primary document model, capture ingestion flow, preset state, export helpers, and annotation data types.
- `ContentView.swift` wires toolbar actions to the document model and presents the preset-aware capture library sidebar plus the main app shell.
- `AnnotationCanvas.swift` renders the background image and overlays strokes and shapes for interactive editing.
- `DragExportNotch.swift` provides drag-to-export behavior for quick sharing.

## Interaction flow

1. The user selects a built-in or custom preset before capture.
2. A capture action runs through a shared ingestion path and persists the image plus metadata into the local capture library.
3. OCR runs against the stored image and updates the searchable capture record.
4. The sidebar loads capture history from SQLite and lets the user reopen older captures.
5. The inspector edits preset-specific structured fields and saves them back to the local capture object.
6. Export actions render the composed image to PNG or generate preset-driven outputs such as issue drafts, Markdown documents, JSON, or CSV.
