# GitHub Setup Phase Plan (QuickSnapApp)

This plan turns the repo into a clean, public, contributor-friendly GitHub project.

## Scope for this phase
- Publish and harden the public GitHub repository.
- Add minimum open-source project files and guardrails.
- Establish a safe PR workflow (CI + review rules).

## Current starting point
- Repo already exists locally (`.git` present).
- Swift Package Manager project (`Package.swift` present).
- Basic README already exists.

## Ordered Task List

### 1) Repository Hygiene and Security (do first)
1. Review tracked files for secrets and machine-local artifacts.
2. Update `.gitignore` for Swift/macOS artifacts as needed.
3. Verify no signing/notarization credentials are in repo history.

Definition of done:
- No credentials/secrets in tracked files.
- `.gitignore` excludes build cache/user-local files.
- Team agrees repo is safe to make public.

### 2) Lock Core Project Decisions
1. Confirm initial license choice (recommend: MIT or Apache-2.0).
2. Confirm support matrix for contributors:
   - Minimum macOS version
   - Xcode version
   - Swift toolchain version
3. Confirm distribution mode for now:
   - Source-only, or
   - GitHub Releases artifact (zip/dmg)

Definition of done:
- Decisions documented in README (and LICENSE added).

### 3) Publish/Verify GitHub Remote
1. Confirm GitHub repo exists and is public.
2. Verify `origin` points to the intended repo.
3. Ensure `main` is pushed and up to date.
4. Add discoverability topics (`macos`, `swift`, `screenshot`, etc.).

Definition of done:
- Public repo is accessible, cloneable, and forkable.

### 4) Add Minimum OSS Project Files
1. Add `LICENSE`.
2. Expand `README.md` with:
   - what the app does
   - requirements
   - build-from-source steps
   - permissions required (Screen Recording/Accessibility if applicable)
3. Add `CONTRIBUTING.md` with setup, tests, style, and PR expectations.
4. Add `CODE_OF_CONDUCT.md` (Contributor Covenant).
5. Add `SECURITY.md` with private vulnerability reporting path.

Definition of done:
- New contributor can understand install/build/contribution flow without asking in chat.

### 5) Add GitHub Collaboration Structure
1. Add PR template (`.github/PULL_REQUEST_TEMPLATE.md`).
2. Add issue templates (`bug report`, `feature request`).
3. Add `.github/CODEOWNERS` with at least initial owner(s).

Definition of done:
- New issues/PRs are structured and auto-routed.

### 6) Add CI for PR Safety
1. Add GitHub Actions workflow (`.github/workflows/ci.yml`) for:
   - build
   - test (if tests exist)
2. Keep CI minimal and fast for initial phase.
3. Optionally add lint/format checks if tools are already used.

Definition of done:
- PRs show required status checks and fail on broken builds/tests.

### 7) Protect `main` Branch
1. Enable branch protection for `main`:
   - PR required
   - at least 1 approval
   - required CI checks
   - restrict direct pushes (as appropriate)
2. Optional: require linear history.

Definition of done:
- No direct unreviewed/broken code can land on `main`.

### 8) Release Readiness (lightweight for now)
1. Decide first tag/version (`v0.1.0` recommended).
2. Create first GitHub Release:
   - source snapshot minimum
   - optional app artifact (`.zip`/`.dmg`)
3. Note unsigned build/Gatekeeper guidance if not notarized yet.

Definition of done:
- Users have a canonical first release entry point.

## Suggested execution order (single workstream)
1. Hygiene/security
2. Decisions (license/support/distribution)
3. Publish/verify repo
4. OSS docs/files
5. Templates + CODEOWNERS
6. CI workflow
7. Branch protection
8. First release

## Deferred (not required for this phase)
- Advanced automation/release pipelines
- Homebrew cask
- Complex multi-job CI matrix
- Full changelog automation

## Deliverables checklist
- [ ] `.gitignore` validated
- [ ] `LICENSE`
- [ ] `README.md` updated
- [ ] `CONTRIBUTING.md`
- [ ] `CODE_OF_CONDUCT.md`
- [ ] `SECURITY.md`
- [ ] `.github/PULL_REQUEST_TEMPLATE.md`
- [ ] `.github/ISSUE_TEMPLATE/bug_report.yml` (or `.md`)
- [ ] `.github/ISSUE_TEMPLATE/feature_request.yml` (or `.md`)
- [ ] `.github/CODEOWNERS`
- [ ] `.github/workflows/ci.yml`
- [ ] Branch protection enabled on GitHub
- [ ] `v0.1.0` release created

## Owner + status tracker
Use this while executing:

| Task | Owner | Status | Notes |
|---|---|---|---|
| Hygiene/security review |  | Not started |  |
| License/support/distribution decisions |  | Not started |  |
| Public repo verification |  | Not started |  |
| OSS docs/files |  | Not started |  |
| Templates + CODEOWNERS |  | Not started |  |
| CI workflow |  | Not started |  |
| Branch protection |  | Not started |  |
| First release (`v0.1.0`) |  | Not started |  |
