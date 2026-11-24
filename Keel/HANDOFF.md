# Keel: handoff

State on 24 November 2026. Read this first, then `README.md` (top section) and `Keel/TESTING.md`.

## What Keel is

A fork of SideStore (AGPL-3.0) for the owner of the Setpoint iPhone app (github.com/Seifonyx/Setpoint).
Keel does everything SideStore does, plus it **installs app updates from sources by itself**, with its own
identity and a redesigned UI ("Instrument" look: dark ink, terracotta, Space Grotesk, Liquid Glass on iOS 26).

- Repo: github.com/Seifonyx/Keel (a plain repo with SideStore's full history, not a GitHub fork).
  Branch `develop` = releases. `redesign` = same commit as develop now. `keel` = old, can be deleted once the
  owner switches the default branch to `develop` (Settings → General; agents can't change repo settings).
- Bundle id `app.seifonyx.keel`, URL scheme `keel://` (`keel://update` runs the updater), display name Keel.
  The product is still `SideStore.app` internally (on purpose, so upstream build scripts work).
- Latest release: **0.7.11 (build 11)** on the rolling `keel-latest` release, with `keel-source.json`
  (SideStore source format) next to the .ipa. Versions are `0.<minor>.<CI run number>`, build = run number.

## Where things are

- `SideStore/Keel/`: all of Keel's own code.
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
  **CI applies it before building; the committed source keeps SideStore's text** so upstream merges stay clean.
  If upstream rewords a listed string, `apply` fails and names it: update the table.
- `Keel/scripts/make_source.py`: writes `keel-source.json` from the built .ipa (size, sha256, permissions).
- `Keel/Branding/`: icon SVG/PNGs (main + Ink, Terracotta, Sea, Paper alternates).
- `.github/workflows/keel.yml`: tests on ubuntu-latest, build on macos-26 (newest Xcode), release on `develop`.
- Upstream files changed: small and marked `KEEL:` (`git grep -n "KEEL:"`). Colours are edited in asset
  catalogs directly; alternate icons reuse upstream's Dark/Sandy/Blue/Snow slots, the others were deleted.

## How it was built and verified

- No Swift toolchain in the cloud container (swift.org blocked) and the owner is on **Windows**: all compiling
  happens in GitHub Actions. Push to a non-`develop` branch to test-build without releasing, then fast-forward
  `develop`. Check a release by downloading `keel-source.json` + `Keel.ipa` and comparing size/sha256.
- `gh api` works for repo contents, runs, job logs and re-runs; creating repos/forks and repo settings are blocked.
- GitHub's macOS arm64 runners sometimes run out of capacity ("job was not acquired"): re-run the failed jobs.
- Pushes that change only `.md` files don't trigger CI (paths-ignore).

## Gotchas found the hard way

- SideStore defines `class Button: UIButton` and `typealias FetchRequest = NSFetchRequest<…>`: in SwiftUI code
  always write `SwiftUI.Button` and `@SwiftUI.FetchRequest`.
- Unit tests run on Linux: Core code must stay Foundation-only (no `NSURLErrorDomain` symbol, use the string).
- iOS 26 glass: `glassEffect` behind `#available(iOS 26, *)`, `.ultraThinMaterial` fallback (deployment target iOS 15).
- `TabBarController` index-based navigation was redirected to `KeelRoot` (sources tab index, classic My Apps for
  .ipa imports, classic Settings for the error log).

## Open items (in order)

1. **Owner to test 0.7.11 on the phone**, especially Settings → "Trouble signing in?" (one-tap fix).
   Background: since 2026-11-20 Apple ID sign-in fails in SideStore (SideStore issues #1745, #1765, #1749;
   the owner hit ADI -45063). The fix switches to remote anisette `https://mac-ani.jkcoxson.com`, pinned,
   client info "Mac OS X", resets adi.pb. Unconfirmed on a device. Upstream had no fix as of this date:
   `git fetch upstream develop` and check before working on sign-in.
2. Redesign the remaining screens in the same look: first-run setup/onboarding (`SideStore/Views/Onboarding`),
   SideStore's sign-in screen, Sources, app pages. The design canvas (B · Instrument) is the reference.
3. Offer to change Setpoint's update card (`ios/Setpoint/App/UpdateCheck.swift:47` in Seifonyx/Setpoint) to open
   `keel://update` first, then `sidestore://`, then the release page. Not done: don't edit Setpoint unasked.
4. Owner: switch default branch to `develop`, then delete `keel`.
5. Nothing on the phone checklist (`Keel/TESTING.md`) has been confirmed yet.

## Rules the owner set

- Never break refresh (apps expire after 7 days). Auto-update stays separate from renewal and fails safe.
- Keep upstream merges easy: few, marked changes in upstream files.
- Ask before anything outward-facing you're unsure about. Releases on every push to `develop` are approved.
- Credits: the owner wanted them gone; About keeps only the AGPL notice (licence, no warranty, source link).
  Copyright headers in source files and the LICENSE must stay.
- Don't post anything to SideStore's GitHub (their AGENTS.md forbids AI-written PRs, issues and comments).
- Plain wording in the app and in replies; the owner is not a developer.
