#!/usr/bin/env python3
"""KEEL: write Keel's SideStore source (keel-source.json) for one built .ipa.

SideStore checks a downloaded app against its source: version, build number and
file size must match exactly, and (when permission checking is on) every
entitlement and privacy permission in the app must be listed. All of that is
read from the .ipa itself here, so the source can't drift from the build.

Usage:
  make_source.py --ipa Keel.ipa --out keel-source.json --download-url URL \
                 --source-url URL --icon-url URL --entitlements a.plist [b.plist ...] \
                 [--notes "text"] [--date 2026-11-23T10:00:00Z]
"""
import argparse
import datetime as dt
import hashlib
import json
import plistlib
import re
import sys
import zipfile

PRIVACY_KEY = re.compile(r"^NS\w*UsageDescription$")
BUNDLE_ID = "app.seifonyx.keel"


def read_ipa(path):
    """Returns (main Info.plist, [Info.plist of every bundle in the app])."""
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        main = [n for n in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n)]
        if len(main) != 1:
            sys.exit(f"expected one Payload/*.app/Info.plist in {path}, found {main}")
        app_dir = main[0][: -len("Info.plist")]
        bundles = [n for n in names
                   if n.startswith(app_dir) and n.endswith("/Info.plist")
                   and (n == main[0] or re.fullmatch(re.escape(app_dir) + r"PlugIns/[^/]+\.appex/Info\.plist", n))]
        plists = [plistlib.loads(z.read(n)) for n in bundles]
        return plistlib.loads(z.read(main[0])), plists


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ipa", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--download-url", required=True)
    ap.add_argument("--source-url", required=True)
    ap.add_argument("--icon-url", required=True)
    ap.add_argument("--entitlements", nargs="*", default=[])
    ap.add_argument("--notes", default="")
    ap.add_argument("--date", default=None)
    a = ap.parse_args()

    info, plists = read_ipa(a.ipa)
    if info.get("CFBundleIdentifier") != BUNDLE_ID:
        sys.exit(f"bundle id is {info.get('CFBundleIdentifier')!r}, expected {BUNDLE_ID!r}")
    version = str(info["CFBundleShortVersionString"])
    build = str(info["CFBundleVersion"])

    privacy = {}
    for p in plists:
        for k, v in p.items():
            if PRIVACY_KEY.match(k):
                privacy.setdefault(k, str(v))

    entitlements = set()
    for path in a.entitlements:
        with open(path, "rb") as f:
            entitlements.update(plistlib.load(f).keys())

    with open(a.ipa, "rb") as f:
        data = f.read()

    date = a.date or dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    notes = a.notes or f"Build {build}."
    source = {
        "name": "Keel",
        "identifier": "app.seifonyx.keel.source",
        "sourceURL": a.source_url,
        "iconURL": a.icon_url,
        "website": "https://github.com/Seifonyx/Keel",
        "tintColor": "C45F35",
        "apps": [{
            "name": "Keel",
            "bundleIdentifier": BUNDLE_ID,
            "developerName": "Seifonyx",
            "subtitle": "Sideloads, refreshes and updates your apps",
            "localizedDescription": "Keel is a fork of SideStore that also installs app updates from your sources by itself. Built on SideStore and AltStore; AGPL-3.0.",
            "iconURL": a.icon_url,
            "tintColor": "C45F35",
            "versions": [{
                "version": version,
                "buildVersion": build,
                "date": date,
                "localizedDescription": notes,
                "downloadURL": a.download_url,
                "size": len(data),
                "sha256": hashlib.sha256(data).hexdigest(),
                "minOSVersion": str(info.get("MinimumOSVersion", "15.0")),
            }],
            "appPermissions": {
                "entitlements": sorted(entitlements),
                "privacy": dict(sorted(privacy.items())),
            },
        }],
        "news": [],
    }
    with open(a.out, "w") as f:
        json.dump(source, f, indent=2)
        f.write("\n")
    print(f"{a.out}: Keel {version} ({build}), {len(data)} bytes, "
          f"{len(entitlements)} entitlements, {len(privacy)} privacy keys")


if __name__ == "__main__":
    main()
