# Privacy and Permissions

QuickSnap is a local-first macOS app. It stores captures, OCR text, metadata, Markdown files, and wiki files on your Mac. It does not include analytics, ad SDKs, crash reporting, or cloud sync.

## What QuickSnap accesses

- `Screen Recording` to capture the display, a window, or a selected region.
- `Automation` for supported browsers when QuickSnap reads browser metadata or page content for `Markdown` captures.
- file open access when you import an image.
- file save access when you export a Markdown document or image.
- network access only for optional integrations you configure, such as OpenAI-powered wiki/Markdown refinement.

## What QuickSnap stores locally

- captured images in the configured capture storage root
- a local SQLite library with capture metadata, OCR text, tags, annotations, chat history, and wiki ingest metadata
- generated Markdown files in the configured Markdown output folder
- wiki files under the Markdown storage root
- the selected annotation color and similar app preferences in macOS user defaults

## Credentials and tokens

- OpenAI API keys are stored in the macOS Keychain.
- GitHub personal access tokens are stored in the macOS Keychain.
- QuickSnap does not store those secrets in its SQLite library.

## What QuickSnap sends over the network

QuickSnap sends nothing to a QuickSnap server because there is no QuickSnap cloud service.

Network activity only happens when you explicitly use an external integration such as:

- OpenAI-backed Markdown cleanup or wiki ingest
- browser fetch/extraction paths for web clipping
- opening GitHub issue drafts in the browser

## What QuickSnap does not do

- It does not run background sync.
- It does not upload your library automatically.
- It does not create analytics or tracking profiles.
- It does not bundle third-party telemetry SDKs.

## Retention

- stored captures remain on disk until you remove the app data or delete the storage folder
- Markdown files remain in the configured Markdown folder until you remove them
- wiki files remain in the wiki directory until you remove them
- temporary export files are created only for the active export/drag flow and may be removed by the system later
