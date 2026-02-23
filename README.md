# QuickSnap

QuickSnap is a lightweight macOS screenshot annotation app inspired by Skitch.

## Features

- Open any image and annotate it
- Capture your main display instantly
- Draw with pen, rectangle, and arrow tools
- Export annotated output as PNG
- Build a launchable `.app` bundle with a custom app icon

## Requirements

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
