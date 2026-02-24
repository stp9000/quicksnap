# QuickSnap

QuickSnap is a lightweight macOS screenshot annotation app inspired by Skitch.

## Features

- Open any image and annotate it
- Capture your main display instantly
- Draw with pen, rectangle, and arrow tools
- Export annotated output as PNG
- Build a launchable `.app` bundle with a custom app icon

## End-User Install (No Swift/Xcode Required)

1. Download `QuickSnap-macOS-unsigned.zip` from the latest GitHub Release.
2. Unzip the archive.
3. Drag `QuickSnap.app` into `/Applications`.
4. Open the app.

If macOS blocks launch, right-click `QuickSnap.app` -> `Open` -> `Open`.

### Screen Recording Permission
QuickSnap needs macOS Screen Recording permission to capture your display.  
The first time you capture, macOS will prompt you to allow access in **System Settings -> Privacy & Security -> Screen Recording**.

Note: Permission usually persists for the installed app. If you install a new unsigned build/version, macOS may ask again.

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

Brand assets (logo + mark) live in `Resources/Brand/`.

This creates:

- `build/QuickSnap.app`

You can launch it from Finder or with:

```bash
open build/QuickSnap.app
```
