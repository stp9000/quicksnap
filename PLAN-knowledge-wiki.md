# QuickSnap as an LLM Knowledge Wiki Engine

## Context

Karpathy published a **pattern** (not code) for building personal knowledge bases with LLMs — a 3-layer architecture: Raw Sources (immutable docs) → Wiki (LLM-generated markdown: entity pages, concept pages, comparisons, overviews) → Schema (a CLAUDE.md governing how the LLM maintains the wiki). Three operations: **Ingest** (process a source, update ~10-15 wiki pages), **Query** (search + synthesize), **Lint** (find contradictions, stale claims, orphans).

QuickSnap already solves the hardest part of this pattern — **ingestion from the real world** — but stops at storage. It never synthesizes captures into a growing, interconnected knowledge base. Bridging that gap turns QuickSnap from a capture tool into a knowledge engine.

## What QuickSnap Already Has That Karpathy's Pattern Lacks

| QuickSnap capability | Why it matters for a wiki |
|---|---|
| **Visual capture** (screenshots + OCR) | Screenshots carry info text extraction misses — UI state, layout, error dialogs, code in context |
| **Web page → Markdown** (Obsidian Clipper) | Already extracts clean markdown with title, author, date, excerpt, canonical URL |
| **Real-time browser context** | Console errors, failed resources, viewport, user agent — rich provenance no copy-paste captures |
| **Annotations** (rectangles, arrows, text) | Human semantic signal — "this part matters" — highest-value input for wiki synthesis |
| **Always-on capture flow** | Wiki grows as a side effect of normal browsing, not deliberate file drops |
| **SQLite + full-text search** | Unified search across raw sources and synthesized knowledge |

## The Gap

QuickSnap captures and stores. Karpathy's wiki synthesizes but has no capture tool. The bridge is a **wiki synthesis layer** that processes captures into interconnected, LLM-maintained markdown pages.

---

## Architecture

### Layer Mapping

```
Karpathy's Model          →  QuickSnap Implementation
─────────────────────────────────────────────────────
Layer 1: Raw Sources      →  CaptureRepository + SQLite + Captures/ + Markdown/
                              (already built)
Layer 2: Wiki             →  NEW: Wiki/ directory with entity, concept, comparison pages
Layer 3: Schema           →  NEW: wiki-schema.md in Wiki/ root
```

### Wiki Directory Structure

Lives alongside the existing markdown output directory:

```
<markdownStorageDirectory>/
  wiki/
    wiki-schema.md           -- LLM instructions (what to extract, page templates, linking conventions)
    index.md                 -- auto-maintained catalog of all wiki pages
    log.md                   -- append-only chronological record of operations
    entities/
      <entity-name>.md       -- one page per person, tool, company, API, etc.
    concepts/
      <concept-name>.md      -- one page per technique, pattern, argument
    comparisons/
      <a>-vs-<b>.md          -- comparison pages
    overviews/
      <topic>.md             -- topic synthesis pages
    captures/
      <capture-id>.md        -- enriched capture summaries (backlinks to source)
```

---

## New Features

### 1. "Knowledge Wiki" Preset

A fourth built-in preset in `CapturePresets.swift` alongside General, Bug Report, and Markdown:

- ID: `knowledge_wiki`
- Expected fields: URL, Page Title, Clip Status, Wiki Entities, Wiki Concepts
- When active, capture ingestion follows the existing markdown clip flow **plus** a post-capture wiki synthesis step

New payload fields on `CapturePresetPayload`:
- `wikiEntities: [String]` — extracted entities (people, tools, companies)
- `wikiConcepts: [String]` — extracted concepts (patterns, techniques)
- `wikiIngestStatus: String` — pending/complete/failed
- `wikiPagesAffected: [String]` — which wiki pages were created/updated

### 2. Wiki Repository (`WikiRepository.swift` — new file)

Manages the wiki directory structure:
- Create/read/update wiki page `.md` files
- Maintain `index.md` (catalog with one-line summaries and links)
- Append to `log.md` (e.g., `## [2026-04-07] ingest | "React Server Components Deep Dive"`)
- Generate default `wiki-schema.md` on first use
- Query pages by entity/concept name

### 3. Wiki Operations Engine (`WikiOperationService.swift` — new file)

Implements the three core operations:

**Ingest** (triggered after capture save when preset is `knowledge_wiki`):
1. Collect: capture's clipped markdown, OCR text, metadata, annotations
2. Load: current `wiki-schema.md` + `index.md` + any existing pages for detected entities
3. Send to LLM: "Given this source and schema, return: entities found, concepts found, pages to create/update with full content"
4. Write affected wiki pages, update `index.md`, append to `log.md`
5. Store `wikiPagesAffected` back on the `CaptureRecord`

**Query** (new "Wiki" tab in the right panel):
1. User types a question
2. Search `index.md` for relevant pages, load them
3. Send pages + question to LLM
4. Return synthesized answer with citations back to specific captures

**Lint** (manual trigger from settings or toolbar):
1. Load all wiki pages
2. LLM identifies: contradictions, stale claims, orphaned pages, missing cross-references
3. Return structured report for user review

### 4. Annotations as Semantic Signal

This is QuickSnap's unique advantage. Existing annotation types map to wiki semantics:

| Annotation | Wiki meaning | Implementation |
|---|---|---|
| **Rectangle** | "Region of interest" — OCR text within bounds becomes a key excerpt | Use Vision framework bounding boxes to extract text inside rectangle coordinates |
| **Arrow** | "Points to important element" — creates a callout reference | Arrow endpoint identifies significant content |
| **Text annotation** | "User commentary" — first-class marginalia for the LLM | Treated as high-signal user synthesis during ingest |
| **Pen strokes** | "Emphasis/highlighting" — marks important regions | Overlapping OCR text treated as highlighted |

The ingest prompt includes annotation data: "This capture has rectangles highlighting [regions], text annotations reading ['important API change'], arrows pointing to [coordinates]. Treat annotated regions as especially important."

**New annotation type to add:** "Wiki Tag" — user taps a region, types an entity/concept name, creating a direct link to a wiki page.

### 5. LLM Backend (`WikiLLMBackend.swift` — new file)

Protocol with two implementations:

- **`InProcessWikiLLM`** — direct API calls (OpenAI or Anthropic) for single-capture ingest and queries. Extends the existing `OpenAIAnalysisClient` pattern with Anthropic support.
- **`ClaudeCodeWikiLLM`** — invokes `claude` CLI via `Process` for heavy operations (full lint, batch re-ingest, wiki reorganization). The wiki directory becomes the working context.

Settings additions:
- API provider toggle (OpenAI / Anthropic)
- Anthropic API key (Keychain)
- Claude Code path (auto-detect or user-specified)

### 6. "Ingest to Wiki" Action on Any Capture

Not just for the Knowledge Wiki preset — any existing capture can be ingested into the wiki via an action button in the inspector panel. This lets users retroactively build their wiki from their capture history.

---

## User Experience Flows

**Capture-to-Wiki (primary flow):**
1. Select "Knowledge Wiki" preset → capture a web page → existing OCR + markdown clip runs
2. Status shows "Ingesting into wiki..."
3. Inspector panel shows extracted entities, concepts, and links to affected wiki pages
4. Click any wiki page link to open in editor

**Annotate-then-Ingest:**
1. Capture with any preset → annotate (rectangle key sections, add text notes)
2. Click "Ingest to Wiki" button
3. Annotations provide high-signal guidance to the LLM

**Query:**
1. Open "Wiki" tab in right panel → type question
2. Get synthesized answer with citations to specific captures (with thumbnails)

**Browse Wiki:**
1. New sidebar section showing wiki directory tree
2. Wiki pages show backlinks to source captures

---

## Implementation Phases

### Phase 1: Wiki Directory Foundation
- `WikiRepository.swift` — directory management, read/write pages, maintain index + log
- `WikiSchema.swift` — models for wiki page structure, default schema template
- Extend `CapturePresetDefinition` with `.knowledgeWiki`
- Extend `CapturePresetPayload` with wiki fields
- Settings UI for wiki directory path

### Phase 2: Ingest Operation
- `WikiOperationService.swift` — ingest engine
- `WikiLLMBackend.swift` — protocol + OpenAI/Anthropic implementations
- Wire ingest into capture flow for knowledge_wiki preset
- Add "Ingest to Wiki" action button for any existing capture
- Anthropic API key in settings

### Phase 3: Query and Browse
- "Wiki" tab in right workspace panel
- Wiki query mode in chat system
- Wiki page browser in sidebar
- Backlink rendering (capture thumbnails on wiki pages)

### Phase 4: Annotations + Lint
- Annotation-aware ingest (extract text from annotated regions)
- New "Wiki Tag" annotation tool
- Lint operation with report UI
- Claude Code CLI integration for heavy operations

### Phase 5: Compound Growth
- Auto-detect contradictions between new capture and existing wiki
- "Related captures" suggestions based on entity overlap
- Wiki evolution diff view
- Export as static site or Obsidian vault

---

## Key Files to Modify

| File | Changes |
|---|---|
| `Sources/QuickSnap/CapturePresets.swift` | Add Knowledge Wiki preset, wiki payload fields |
| `Sources/QuickSnap/CaptureLibrary.swift` | Wiki status tracking on CaptureRecord, wiki directory config |
| `Sources/QuickSnap/AnnotationModels.swift` | Wiki Tag annotation type |
| `Sources/QuickSnap/AIWorkspace.swift` | Anthropic API support, wiki prompt construction |
| `Sources/QuickSnap/ContentView.swift` | Wiki tab in right panel, wiki browse UI, ingest action buttons |
| `Sources/QuickSnap/SettingsView.swift` | Wiki directory path, Anthropic API key, LLM backend toggle |

## New Files

| File | Purpose |
|---|---|
| `Sources/QuickSnap/WikiRepository.swift` | Wiki directory management, page CRUD, index/log maintenance |
| `Sources/QuickSnap/WikiSchema.swift` | Wiki page models, default schema template |
| `Sources/QuickSnap/WikiOperationService.swift` | Ingest/Query/Lint engine |
| `Sources/QuickSnap/WikiLLMBackend.swift` | LLM abstraction — InProcess + Claude Code backends |

## Verification

- Create a test wiki directory, capture a web page with Knowledge Wiki preset, verify wiki pages are generated
- Annotate a capture, ingest to wiki, verify annotations influence extracted entities
- Query the wiki, verify answer cites source captures
- Run lint, verify it detects orphaned pages or missing cross-references
- Test with both OpenAI and Anthropic backends
