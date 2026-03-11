# QuickSnap Repository Audit (Pre–Apple Developer Enrollment)

Date: 2026-03-11
Scope: Repository structure, documentation hygiene, and Apple-platform readiness for distribution.

## Executive Summary

QuickSnap is a clean, small Swift Package–based macOS app with a straightforward source layout and build script. The project is in good shape for local development and unsigned distribution, but it is **not yet production-ready for Apple distribution flows** (Developer ID or Mac App Store) due to missing release-process documents and packaging/signing/notarization guidance.

## 1) Repository Structure

### Current strengths

- Clear top-level separation of code (`Sources/QuickSnap`), scripts (`scripts/`), and assets (`Resources/`).
- Minimal dependency surface; no third-party package sprawl.
- Build output directories are ignored via `.gitignore`.

### Gaps against common open-source/app repo conventions

- No `CONTRIBUTING.md` to define contribution expectations.
- No `SECURITY.md` for vulnerability reporting.
- No changelog/release notes template (`CHANGELOG.md`), which becomes useful once distributing signed builds.
- No CI workflow for build verification (e.g., GitHub Actions).

## 2) Documentation Audit

### Current strengths

- `README.md` includes product summary, install path, local run command, and app bundle build command.
- License is present.

### Improvements recommended

- Add a contributor guide (workflow, coding style, commit/PR expectations).
- Add release-process documentation for:
  - Versioning strategy.
  - Signing identity strategy (local dev vs release).
  - Notarization and stapling steps.
- Add explicit privacy behavior notes (what is captured, where files are written, and what is never uploaded).

## 3) Apple Readiness Audit (Pre-signup Checklist)

Status legend: ✅ ready, ⚠️ partial, ❌ missing.

- ⚠️ App identity basics (`CFBundleIdentifier`, app icon, bundle metadata): present in `scripts/build_app.sh`, but generated values are date-based only and not yet aligned to a formal versioning/release process.
- ❌ Signing strategy: ad-hoc signing is used for local runs; no documented Developer ID / distribution certificate flow.
- ❌ Notarization strategy: no `notarytool` workflow documented.
- ❌ Hardened runtime review: no explicit validation step documented.
- ❌ Privacy policy/statement for distribution: not documented in repo.
- ⚠️ Permissions UX: README mentions Screen Recording permission, but a dedicated privacy section with retention/storage behavior would reduce review friction.
- ⚠️ Crash/reporting and telemetry disclosures: no mention (acceptable if none are used, but should be explicitly documented).

## 4) Risks Before Apple Distribution

1. **Release reproducibility risk**: no defined release checklist, so signed builds may differ between maintainers.
2. **Review readiness risk**: missing explicit privacy and data-handling docs can slow external review.
3. **Operational risk**: without CI, regressions may slip into release builds.

## 5) Recommended Next Steps (Priority Order)

### P0 (do before paid Apple enrollment, if possible)

1. Document contribution/release workflow (`CONTRIBUTING.md`).
2. Add a `SECURITY.md` intake path.
3. Define versioning policy (e.g., semantic app version + build number).

### P1 (do immediately after enrollment)

1. Add Developer ID signing + notarization scripts (or a documented manual checklist).
2. Add CI build verification for `swift build -c release`.
3. Add a short "Privacy & Permissions" section in README describing:
   - Screen recording permission usage.
   - Local-only processing.
   - Default export/archive paths.

### P2 (quality-of-life)

1. Add a `CHANGELOG.md`.
2. Add issue/PR templates.
3. Add lightweight architecture notes for `AnnotationDocument` and canvas interaction.

## 6) Conclusion

The codebase is **well-structured for a solo macOS utility app** and already close to distribution readiness from a functionality standpoint. The main blockers are **process/documentation maturity and Apple distribution hardening steps**, not fundamental code architecture issues.
