<!-- KEEL: this section is Keel's. Everything below the line is SideStore's README, unchanged. -->
# Keel

<img src="Keel/Branding/icon-1024.png" width="96" alt="Keel icon: a hull and keel on a waterline">

**Keel is a fork of [SideStore](https://github.com/SideStore/SideStore) that installs app updates by itself.**
It sideloads and refreshes apps exactly like SideStore, and when one of your sources has a newer build of an app you
have installed, Keel downloads, signs and installs it the same way the Update button does.

Keel is built on the work of the SideStore team and of Riley Testut and the [AltStore](https://github.com/altstoreio/AltStore)
team. Nearly all of the code here is theirs. Keel is licensed, like SideStore, under the
[GNU AGPL v3.0](LICENSE); their copyright notices are kept in every file. Please don't report Keel problems to SideStore or AltStore.

## What Keel adds

- **Auto-update.** After each background refresh and whenever you open Keel, it checks each installed app's source
  and installs newer builds. Settings are on the Auto-update screen (the clock button on My Apps):
  - Auto-update apps: on by default.
  - Only on Wi-Fi: off by default. When on, Keel waits for a Wi-Fi connection (cellular and Personal Hotspot don't count).
  - Also update Keel: off by default, so a broken Keel build can never replace the one that keeps your apps refreshed.
    Keel's own updates still show an Update button in My Apps as usual.
  - Recent: what was updated, what failed and why, newest first.
- **An "Update Apps" action for Shortcuts**, for a reliable nightly update (see below).
- **`keel://update`** opens Keel and runs the update check straight away.
- **Its own name, icon, bundle id (`app.seifonyx.keel`) and URL scheme (`keel://`)**, so it can sit next to SideStore.

## Install

1. In SideStore, add this source: `https://github.com/Seifonyx/Keel/releases/download/keel-latest/keel-source.json`,
   then install Keel. (Or download `Keel.ipa` from the [keel-latest release](https://github.com/Seifonyx/Keel/releases/tag/keel-latest).)
2. Open Keel, sign in with your Apple ID and import your pairing file, as you did in SideStore.
3. In Keel, add your app sources (for example Setpoint's) and install your apps from Keel, so Keel keeps track of them.
   Keel signs with the same Apple ID and the same bundle id, so installing over an app you already have should keep
   its data. This hasn't been tried on a phone yet, so back up anything important first.
4. When Keel has refreshed and updated your apps, you can delete SideStore.

> A free Apple ID allows 3 sideloaded apps at once, and SideStore and Keel each count as one.
> With SideStore, Keel and one app installed you're at the limit, so move over one app at a time and remove SideStore once you're done.

## Update every night with Shortcuts (one-time setup)

iOS gives apps very little background time, so background refresh alone can miss updates for days.
A personal automation is the reliable way:

1. Open **Shortcuts**, go to **Automation** and tap **+**.
2. Pick **Time of Day** (for example 03:00, Daily) or **Charger → Is Connected**.
3. Choose **Run Immediately** (and turn off "Notify When Run" if you like).
4. Add the action **Keel → Update Apps** and tap **Done**.

The action opens Keel while it works, because installing needs Keel's connection to your phone (the VPN must be on,
as for refreshing). Keel sends a notification when it updated something or something failed.

## How auto-update stays safe

- **Refresh comes first and is never changed.** The renew step works exactly as in SideStore. Updates run only after refresh
  has finished (background), or on their own (opening Keel, the Shortcut, `keel://update`). A failed update can't stop a refresh.
- **A failed update leaves the installed version working.** Keel uses SideStore's normal update path: the new build is
  downloaded, checked against the source (version, build number, size, and hash when the source gives one), and signed
  before iOS installs it, and iOS only replaces the app when the install succeeds.
- **No guessing.** In the background or from Shortcuts there's no one to answer a prompt, so anything that needs you
  (for example new permissions when permission checking is on) fails, is logged, and waits for you to press Update.
- **Only newer builds.** When a source gives whole-number build numbers (Setpoint uses its CI run number), Keel installs
  only a higher build, never a lower one. Otherwise it follows SideStore's own Update-badge logic.
- Apps you are refreshing or updating by hand are left alone, and only one update check runs at a time.

## Building

GitHub Actions ([`.github/workflows/keel.yml`](.github/workflows/keel.yml)) runs the auto-update unit tests, builds an
unsigned `Keel.ipa` on a GitHub Mac, and on every push to `develop` publishes it with `keel-source.json` to the
[`keel-latest`](https://github.com/Seifonyx/Keel/releases/tag/keel-latest) release. Versions are `0.<minor>.<run number>`
and the build number is the run number, so every build is newer than the last.

Unit tests for the update rules: `cd Keel/Tests && swift test`.

## Keeping up with SideStore

Keel's own code lives in [`SideStore/Keel/`](SideStore/Keel), [`Keel/`](Keel) and `.github/workflows/keel.yml`.
Every change to an upstream file is small and marked `KEEL:`; list them with `git grep -n "KEEL:"`. To merge upstream:

```sh
git remote add upstream https://github.com/SideStore/SideStore.git   # once
git fetch upstream
git merge upstream/develop
git grep -n "KEEL:"   # check each marked change survived
```

Upstream's own workflows are kept but only run in SideStore's repository.

---

# SideStore

> SideStore is an *untethered, community driven* alternative app store for non-jailbroken iOS devices 

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://makeapullrequest.com)
[![Nightly SideStore build](https://github.com/SideStore/SideStore/actions/workflows/nightly.yml/badge.svg)](https://github.com/SideStore/SideStore/actions/workflows/nightly.yml)
[![.github/workflows/beta.yml](https://github.com/SideStore/SideStore/actions/workflows/beta.yml/badge.svg)](https://github.com/SideStore/SideStore/actions/workflows/beta.yml)
[![Discord](https://img.shields.io/discord/949183273383395328?label=Discord)](https://dis.sidestore.io)

![Alt](https://repobeats.axiom.co/api/embed/3a329ce95955690b9a9366f8d5598626a847d96c.svg "Repobeats analytics image")

SideStore is an iOS application that allows you to sideload apps onto your iOS device with just your Apple ID. SideStore resigns apps with your personal development certificate, and then uses a [specially designed VPN](https://github.com/jkcoxson/em_proxy) in order to trick iOS into installing them. SideStore will periodically "refresh" your apps in the background, to keep their normal 7-day development period from expiring.

SideStore's goal is to provide an untethered sideloading experience. It's a community driven fork of [AltStore](https://github.com/rileytestut/AltStore), and has already implemented some of the community's most-requested features.

(Contributions are welcome! 🙂)

## Requirements
- Xcode 15
- iOS 14+
- Rustup (`brew install rustup`)

Why iOS 14? Targeting such a recent version of iOS allows us to accelerate development, especially since not many developers have older devices to test on. This is corrobated by the fact that SwiftUI support is much better, allowing us to transistion to a more modern UI codebase.
## Project Overview

### SideStore
SideStore is a just regular, sandboxed iOS application. The AltStore app target contains the vast majority of SideStore's functionality, including all the logic for downloading and updating apps through SideStore. SideStore makes heavy use of standard iOS frameworks and technologies most iOS developers are familiar with.

### EM Proxy
[EM Proxy](https://github.com/jkcoxson/em_proxy) powers the defining feature of SideStore: untethered app installation. By leveraging a custom-built App Store app with additional entitlements ([LocalDevVPN](https://github.com/jkcoxson/LocalDevVPN)) to create the VPN tunnel for us, it allows SideStore to take advantage of [Jitterbug](https://github.com/osy/Jitterbug)'s loopback method without requiring a paid developer account.

### Minimuxer
[Minimuxer](https://github.com/jkcoxson/minimuxer) is a lockdown muxer that can run inside iOS’s sandbox. It replicates Apple’s usbmuxd protocol on macOS to “discover” devices to interface with LocalDevVPN on-device.

### Roxas
[Roxas](https://github.com/rileytestut/roxas) is Riley Testut's internal framework from AltStore used across many of their iOS projects, developed to simplify a variety of common tasks used in iOS development.

We're hoping to eventually eliminate our dependency on it, as it increases the amount of unnecessary Objective-C in the project.

## Contributing/Compilation Instructions

Please see [CONTRIBUTING.md](./CONTRIBUTING.md)

## Licensing

This project is licensed under the **AGPLv3 license**.
