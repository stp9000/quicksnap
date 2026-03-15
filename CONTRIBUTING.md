# Contributing to QuickSnap

Thanks for contributing.

## Development setup

1. Use macOS 13+ with Swift toolchain and `iconutil` available.
2. Build locally:
   ```bash
   swift build
   ```
3. Run locally:
   ```bash
   swift run
   ```

## Pull request expectations

- Keep PRs focused and small when possible.
- Include a short summary of user-facing changes.
- If UI changes are made, attach a screenshot.
- Run local verification before opening a PR.
- Update `CHANGELOG.md` for user-visible release changes.

## Local checks

Recommended pre-PR checks:

```bash
swift build
swift build -c release
```

For release work, also verify:

```bash
./scripts/package_release.sh
```

## Coding conventions

- Prefer clear names and small helper methods.
- Keep SwiftUI views broken into focused private computed properties where reasonable.
- Avoid introducing dependencies unless there is a clear need.

## Release notes guidance

For release-related PRs, include:

- user-visible changes,
- migration notes (if any),
- known limitations.

## Release flow

- The current app version lives in `VERSION`.
- Use a separate build number for `CFBundleVersion`.
- Follow the release checklist in `docs/RELEASE.md`.
- Use `docs/APPLE_READINESS.md` and `docs/GITHUB_SETUP.md` for environment and repository setup tasks.
