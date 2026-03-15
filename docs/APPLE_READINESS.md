# Apple Readiness Checklist

Use this checklist to prepare QuickSnap for Developer ID distribution outside the Mac App Store.

## Account and credentials

- [ ] Confirm the Apple Developer Program membership is active.
- [ ] Install the production `Developer ID Application` certificate on the release Mac.
- [ ] Create a `notarytool` keychain profile with `xcrun notarytool store-credentials`.
- [ ] Record the exact certificate name and team ID used for releases.

## App identity and metadata

- [ ] Confirm `com.quicksnap.app` is the final bundle identifier.
- [ ] Update `VERSION` before each release.
- [ ] Choose the release build number for `CFBundleVersion`.
- [ ] Confirm the release zip name matches the documented `QuickSnap-v<version>-macOS-unsigned.zip` convention.

## Release validation

- [ ] Run `swift build`.
- [ ] Run `swift build -c release`.
- [ ] Run `./scripts/package_release.sh`.
- [ ] Build a release app with an explicit build number:
  ```bash
  BUILD_NUMBER=2026031101 ./scripts/build_app.sh
  ```
- [ ] Sign and notarize with:
  ```bash
  DEVELOPER_ID_APPLICATION="Developer ID Application: Your Name (TEAMID)" \
  NOTARY_PROFILE="quicksnap-notary" \
  ./scripts/notarize_app.sh
  ```
- [ ] Verify the final app with:
  ```bash
  codesign --verify --deep --strict --verbose=2 build/QuickSnap.app
  spctl --assess --type execute --verbose=4 build/QuickSnap.app
  xcrun stapler validate build/QuickSnap.app
  ```

## Clean-machine checks

- [ ] Install the signed app on a Mac that has not previously run QuickSnap.
- [ ] Confirm the app launches from `/Applications`.
- [ ] Confirm the app icon, name, and Finder presentation look correct.
- [ ] Confirm Screen Recording permission is prompted only when capture is used.
- [ ] Confirm full-screen capture works.
- [ ] Confirm front-window capture works.
- [ ] Confirm selection capture works.
- [ ] Confirm importing an existing image stores it in the local capture library.
- [ ] Confirm new captures appear in the timeline after app restart.
- [ ] Confirm OCR status updates and search works for OCR text, titles, tags, and capture type filters.
- [ ] Confirm export PNG works.
- [ ] Confirm Markdown copy/export workflows work for stored captures.
- [ ] Confirm drag export works and archives to `~/Pictures/QuickSnap`.
- [ ] Confirm "Reveal Library in Finder" opens the configured local library.

## Privacy and review readiness

- [ ] Re-check `PRIVACY.md` against the shipping build behavior.
- [ ] Re-check that the documented local library behavior and SQLite metadata storage match the shipping build, including custom storage locations.
- [ ] Re-check `README.md` install instructions against the actual release artifact.
- [ ] Confirm no new telemetry, background sync, or third-party SDKs were added.
- [ ] Confirm whether Apple requires a privacy manifest or additional metadata for the release.

## Release sign-off

- [ ] Update `CHANGELOG.md`.
- [ ] Tag the release as `v<version>`.
- [ ] Upload the final zip to GitHub Releases.
- [ ] Save release notes from the changelog into the GitHub Release entry.
