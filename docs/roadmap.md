# QuickSnap Roadmap

This roadmap turns the product direction in [product.md](/Users/steve/Documents/QuickSnapApp/docs/product.md) into implementation phases that fit the current app and release process.

## Phase 1: Capture Foundation

Goal: establish a consistent capture pipeline and a durable `Capture Object` model.

Deliverables:

- Unify full-screen, region, and window capture behavior
- Define the `Capture Object` model in code
- Choose the app-managed storage location for persisted captures
- Save captures under managed storage instead of relying only on export flows
- Preserve current annotation and PNG export behavior on top of stored captures

Exit criteria:

- Every new capture produces a persisted `Capture Object`
- IDs and file paths do not collide
- Existing basic capture flows still work

## Phase 2: Knowledge Layer

Goal: make captures searchable and durable across app restarts.

Deliverables:

- Add local database persistence, preferably SQLite
- Persist OCR text, timestamps, app name, title, tags, and image references
- Build a history or timeline UI inside the app
- Add local search across OCR text and metadata
- Handle missing files and partial records gracefully

Exit criteria:

- Capture history survives restart
- Search works for OCR text and metadata filters
- Empty-state and no-results behavior is clear

## Phase 3: Workflow Output

Goal: make stored captures useful in documentation and engineering workflows.

Deliverables:

- Add Markdown clipboard and export support
- Support copy image, copy file path, and Markdown link output modes
- Allow export actions from both fresh captures and history items
- Update public docs and release notes to reflect the new workflows

Exit criteria:

- Markdown export format is stable
- Output actions work from history and immediate post-capture views
- README messaging matches actual product behavior

## Phase 4: Polish and Readiness

Goal: prepare the repositioned product for reliable distribution.

Deliverables:

- Update privacy language around local capture storage, OCR, and indexing
- Re-check permissions and storage behavior against actual implementation
- Validate build, packaging, signing, and notarization flows after storage changes
- Confirm clean-machine install and launch behavior still makes sense

Exit criteria:

- Shipping docs match app behavior
- Release scripts still work
- Apple readiness checklist reflects the final MVP behavior

## Deferred Phases

These areas stay intentionally out of MVP, but the architecture should avoid blocking them later.

### Phase 5: Sharing

- Shared links
- Collaboration comments
- Team-facing distribution flows

### Phase 6: AI Layer

- Semantic tagging
- Summaries or alt text
- Natural-language retrieval

### Phase 7: Platform Expansion

- Additional capture inputs such as recordings or pasted images
- Broader workflow integrations once the core local model is stable

## Engineering Notes

- Favor a persistence boundary early so UI code does not hard-code file-system assumptions.
- Treat OCR as a pipeline stage, not a UI concern.
- Keep annotation tools functional, but do not let annotation expansion outrun search/history work.
- Keep release and Apple-signing work aligned with the app’s true storage and permission behavior.
