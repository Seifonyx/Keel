# Keel: handoff

State on 25 November 2026. Read this first, then `README.md` (top section) and `Keel/TESTING.md`.
(This file used to live at `Keel/HANDOFF.md`; it moved to the repo root on 25 Nov.)

## What Keel is

A fork of SideStore (AGPL-3.0) for the owner of the Setpoint iPhone app (github.com/Seifonyx/Setpoint).
Keel does everything SideStore does, plus it **installs app updates from sources by itself**, with its own
identity and a redesigned UI ("B · Instrument" look: dark ink, terracotta, Space Grotesk, Liquid Glass on iOS 26).

- Repo: github.com/Seifonyx/Keel (a plain repo with SideStore's full history, not a GitHub fork).
- Bundle id `app.seifonyx.keel`, URL scheme `keel://` (`keel://update` runs the updater), display name Keel.
  The product is still `SideStore.app` internally (on purpose, so upstream build scripts work).
- The owner is not a developer and is on **Windows with no Mac**: every build happens in GitHub Actions.

## Current state and latest build

- **Latest release: 0.7.12 (build 12)**, published 24 Nov 2026 09:26 UTC on the rolling `keel-latest` release
  (`Keel.ipa`, 15,614,734 bytes, plus `keel-source.json`). Built from `develop` at `90fa76f6`.
  Code is identical to 0.7.11; the build only happened because that commit also touched `Keel/.gitignore`
  (pushes that change only `.md` files don't build).
- Done: auto-updater, Shortcuts action, `keel://update`, Keel's own Apps / Activity / Settings tabs in the
  Instrument look, rebrand of SideStore's strings, icons, "Trouble signing in?" one-tap fix.
- **Nothing has been confirmed on a real iPhone yet.** The owner was about to test (see open items).

## Where things live

### Branches (all pushed, nothing local-only)
- `develop`: the real branch. Every push to it releases. Use this.
- `redesign`: old pointer at `d216182f` (one commit behind develop). Can be deleted.
- `keel`: old, at `ab5ab123`. **It is still GitHub's default branch**, so the upstream "Nightly SideStore Build"
  workflow fires on a schedule there and is skipped (harmless). The owner should switch the default branch to
  `develop` (repo Settings → General); agents can't change repo settings. Then delete `keel` and `redesign`.
- Upstream SideStore is not set up as a git remote in the owner's clone. Check it with
  `gh api "repos/SideStore/SideStore/commits?sha=develop"` or add it: `git remote add upstream https://github.com/SideStore/SideStore.git`.

### Folders
- `SideStore/Keel/`: all of Keel's own app code.
  - `Core/` (Foundation only, unit tested): `KeelAutoUpdatePolicy.swift` (when to update, settings, JSON log),
    `KeelErrorExplainer.swift` (error → plain words + fix).
  - `KeelAutoUpdater.swift` (actor; runs after background refresh, on open, from Shortcut, from `keel://update`;
    uses `AppManager.update()` like the Update button), `KeelLifecycleHooks.swift`, `KeelUpdateAppsIntent.swift`
    (Shortcuts "Update Apps"), `KeelSignInFix.swift`, `InstalledApp+Keel.swift`, `KeelBrand.swift`, `KeelViews.swift`.
  - `UI/`: `KeelRoot.swift` (Keel's tabs, installed into SideStore's TabBarController), `KeelAppsView`,
    `KeelActivityView` (+ `KeelProblemSheet`), `KeelSettingsView` (+ nightly-update steps), `KeelTheme`
    (colours, fonts, `keelGlass`), `KeelNavigator`.
  - `Resources/Fonts/`: Space Grotesk TTFs (SIL OFL, licence file alongside).
- `Keel/Tests/`: SwiftPM package; `Sources/KeelCore` is a symlink to `SideStore/Keel/Core`. `swift test`.
- `Keel/rebrand/`: `strings.json` (100 SideStore strings → Keel wording) + `rebrand.py apply|check|revert`.
- `Keel/scripts/make_source.py`: writes `keel-source.json` from the built .ipa (size, sha256, permissions).
- `Keel/Branding/`: icon SVG/PNGs (main + Ink, Terracotta, Sea, Paper alternates).
- `Keel/TESTING.md`: the 13-step phone checklist.
- Upstream files Keel changed are few and marked `KEEL:` (`git grep -n "KEEL:"`).

### Build setup and services
- `.github/workflows/keel.yml`: unit tests on `ubuntu-latest`, then build on `macos-26` (newest Xcode),
  then on `develop` only, publish to the `keel-latest` release. Other branches build and test without releasing.
  Versions are `0.<minor>.<CI run number>`, build = run number.
- Release: `https://github.com/Seifonyx/Keel/releases/download/keel-latest/keel-source.json` is the source URL
  the phone uses.
- No other services, accounts or secrets. The sign-in fix uses the public anisette server `https://mac-ani.jkcoxson.com`.
- Owner's local clone: `C:\Users\seife\Keel` (Windows; no Swift toolchain, so nothing compiles locally).

## Decisions and why

- **Plain repo, not a GitHub fork**, so it has its own identity and releases; full SideStore history kept for merges.
- **Product stays `SideStore.app`**, and **committed source keeps SideStore's wording**: CI runs `rebrand.py apply`
  before building. Both keep upstream merges clean. If upstream rewords a listed string, `apply` fails and names it:
  update `strings.json`.
- **Auto-update reuses `AppManager.update()`** (the same path as the Update button) and is kept separate from
  refresh, so a failed update can never stop apps being renewed.
- **Own tabs, inserted into SideStore's TabBarController** instead of rewriting SideStore's screens: less upstream
  churn. Classic screens are still reachable where needed (.ipa imports → classic My Apps; error log → classic Settings).
- **Colours edited in asset catalogs directly**; alternate icons reuse upstream's Dark/Sandy/Blue/Snow slots
  (others deleted) to avoid project-file edits.
- **Sign-in fix** (since 20 Nov 2026 Apple ID sign-in fails in SideStore: their issues #1745, #1749, #1761, #1765,
  #1769; owner hit ADI -45063): switch to remote anisette `mac-ani.jkcoxson.com`, pinned, client info "Mac OS X",
  reset `adi.pb`. Chosen because upstream has no fix (no upstream commits since 19 Nov as of 24 Nov).
- **Credits removed** at the owner's request; About keeps only the AGPL notice (licence, no warranty, source link).

## Gotchas

- SideStore defines `class Button: UIButton` and `typealias FetchRequest = NSFetchRequest<…>`: in SwiftUI code
  always write `SwiftUI.Button` and `@SwiftUI.FetchRequest`.
- Unit tests run on Linux: Core code must stay Foundation-only (no `NSURLErrorDomain` symbol, use the string).
- iOS 26 glass: `glassEffect` behind `#available(iOS 26, *)`, `.ultraThinMaterial` fallback (deployment target iOS 15).
- `TabBarController` index-based navigation was redirected to `KeelRoot`.
- GitHub's macOS arm64 runners sometimes say "job was not acquired": re-run the failed jobs (`gh run rerun --failed`).
- Pushes that change only `.md` files don't trigger CI; any other file does, and on `develop` that means a release.
- `gh api` works for contents, runs, logs and re-runs; creating repos/forks and changing repo settings are blocked.
- To check a release: download `keel-source.json` + `Keel.ipa` and compare size/sha256.

## Rules the owner set

- Never break refresh (apps expire after 7 days). Auto-update stays separate from renewal and fails safe.
- Keep upstream merges easy: few, marked (`KEEL:`) changes in upstream files.
- Ask before anything outward-facing you're unsure about. Releases on every push to `develop` are approved.
- Copyright headers in source files and the LICENSE must stay.
- **Never post anything to SideStore's GitHub** (their `AGENTS.md` forbids AI-written PRs, issues, comments).
  `AGENTS.md`/`CLAUDE.md` in this repo are SideStore's contribution rules; they apply to upstream, not to work
  in the owner's own repo.
- Plain wording in the app and in replies; the owner is not a developer.

## Open bugs / unknowns

- **Sign-in fix unconfirmed on a device.** If it fails, get the Error Log text (Settings → Error Log) or a screenshot.
- Upstream issues that may affect Keel too (unverified): #1757 IPA download truncated ("Archive appears to be
  corrupt"), #1762 install/refresh `-1001` timeouts after sign-in problems, #1763 503 errors during sign-in.
- `Keel/TESTING.md` step 4 says "My Apps → clock button"; with Keel's own tabs the auto-update controls may be
  elsewhere now. Check and fix the wording when testing.

## Next steps (in priority order)

1. **Owner tests 0.7.12 on the iPhone**, especially Settings → "Trouble signing in?", then that install and
   refresh work after sign-in. Before touching sign-in code, check upstream for a fix first.
2. **Redesign the remaining screens in the B · Instrument look:** first-run setup/onboarding
   (`SideStore/Views/Onboarding`), SideStore's sign-in screen, Sources, app pages. The design canvas
   (B · Instrument) is the reference; match `KeelTheme` (colours, fonts, `keelGlass`). Prefer new Keel views over
   heavy edits to upstream files. Test-build on a branch, then fast-forward `develop`.
3. Work through `Keel/TESTING.md` with the owner; nothing on it is confirmed yet.
4. Offer to change Setpoint's update card (`ios/Setpoint/App/UpdateCheck.swift:47` in Seifonyx/Setpoint) to open
   `keel://update` first, then `sidestore://`, then the release page. Don't edit Setpoint unasked.
5. Owner: switch the default branch to `develop`, then delete `keel` and `redesign`.
