# Release Process

This document describes the release flow for local unsigned builds, the tag-triggered GitHub Release flow, and Apple Developer distribution builds.

## Versioning policy

- `VERSION` stores the current semantic app version for `CFBundleShortVersionString`.
- `CFBundleVersion` uses an incrementing build number. The default scripts use a timestamp-derived value for local builds.
- Before tagging a release, update `VERSION` and add release notes to `CHANGELOG.md`.

## Tag-triggered GitHub Release

- Push tags in the format `v<version>`.
- `.github/workflows/release.yml` verifies the tag matches `VERSION`.
- The workflow builds `QuickSnap-v<version>-macOS-unsigned.zip` and publishes it to the matching GitHub Release.
- Release notes are pulled from the matching `CHANGELOG.md` section for that version.
- This workflow currently publishes the unsigned archive only. Notarized distribution remains a manual follow-up.

## Local unsigned release

1. Run `swift build`.
2. Run `swift build -c release`.
3. Run `./scripts/package_release.sh`.
4. Confirm the archive exists in `dist/`.
5. Smoke-test the app from `build/QuickSnap.app`.
6. Validate the current MVP workflows:
   - capture full screen, front window, and selection
   - import an image into the capture library
   - confirm the capture appears in the timeline
   - verify OCR status updates after capture
   - search by OCR text, title, tag, and capture type
   - export PNG, copy Markdown, and export a Markdown file

## Developer ID release

Prerequisites:

- Active Apple Developer membership.
- A `Developer ID Application` certificate installed in Keychain.
- A notarytool keychain profile created with `xcrun notarytool store-credentials`.

Suggested flow:

1. Build the app with `BUILD_NUMBER=2026031101 ./scripts/build_app.sh`.
2. Sign, validate, and notarize with:
   ```bash
   DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
   NOTARY_PROFILE="quicksnap-notary" \
   ./scripts/notarize_app.sh
   ```
3. Verify the stapled app:
   ```bash
   codesign --verify --deep --strict --verbose=2 build/QuickSnap.app
   spctl --assess --type execute --verbose=4 build/QuickSnap.app
   xcrun stapler validate build/QuickSnap.app
   ```
4. Archive the notarized app for distribution.

## Release checklist

- Update `CHANGELOG.md`.
- Confirm README install instructions match the release artifact name.
- Confirm the release tag will match `VERSION`.
- Run CI-equivalent local checks:
  ```bash
  swift build
  swift build -c release
  ```
- Verify privacy and permission docs still match app behavior.
- Verify the local capture library path, SQLite-backed history, OCR indexing, and Markdown outputs still match the documented behavior.
- Follow the Apple checklist in `docs/APPLE_READINESS.md` for signing/notarization prerequisites and clean-machine validation.
- Follow the GitHub checklist in `docs/GITHUB_SETUP.md` for branch protection, release publishing, and repository settings.
- Push the `v<version>` tag after the unsigned archive and release notes are ready.
- If distributing a notarized build, validate it first and then replace or add release assets manually.
