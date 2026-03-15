# Privacy and Permissions

QuickSnap is a local-first macOS screenshot and annotation app. It stores captures on-device for history and search, and it does not include analytics, crash reporting, cloud sync, advertising SDKs, or other network-backed telemetry.

## What QuickSnap accesses

- Screen Recording permission is required when you capture the main display or an on-screen selection.
- Screen Recording permission is also used when you capture the frontmost window.
- Apple Events automation permission may be requested for supported browsers so QuickSnap can store the active page URL in capture metadata.
- File open access is used only when you choose an image from disk.
- File save access is used only when you export an annotated PNG.
- Network access is used only when you choose to run AI analysis with a personal API key.

## What QuickSnap stores

- Screen captures are stored in QuickSnap's local capture library. By default this lives under macOS Application Support, and the user can choose a different folder in Settings.
- Capture metadata such as timestamp, capture type, source app, window title, and dimensions is stored locally in QuickSnap's SQLite library.
- Preset-specific structured fields such as URLs, browser names, stack traces, documentation notes, research summaries, table data, and custom preset field values are stored locally when you add them.
- AI analysis results such as summaries, recommended actions, issue-draft suggestions, and analysis metadata are stored locally in QuickSnap's SQLite library when analysis is run.
- OCR text extracted from captures is stored locally so captures can be searched.
- User-edited tags for captures are stored locally in the same SQLite library.
- A personal OpenAI API key, if you save one, is stored securely in your macOS Keychain rather than in QuickSnap's SQLite library or user defaults.
- Annotated PNG exports are written only when you trigger an export action.
- Drag export creates a temporary file for the active drag session and also writes an archived copy to `~/Pictures/QuickSnap`.
- The selected annotation color is stored in macOS user defaults so the app can restore the last-used color.

## What QuickSnap does not do

- It does not upload screenshots or annotations.
- It does not collect account data.
- It does not run background sync jobs.
- It does not bundle third-party SDKs.

If you enable BYO AI analysis with your own OpenAI API key, the selected capture image and related metadata may be sent to OpenAI only when you explicitly run Analyze.

## Retention and local storage

- Temporary drag-export files are created in the system temporary directory for the active drag session.
- Stored captures and their local search index remain in QuickSnap's configured storage location until you remove that app data.
- Archived exports remain in `~/Pictures/QuickSnap` until you remove them.
