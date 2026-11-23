#!/usr/bin/env python3
"""KEEL: put Keel's wording into the app at build time.

Keel/rebrand/strings.json lists exact user-visible strings from SideStore's source and
what Keel shows instead. CI runs `rebrand.py apply` just before building, so the
committed source stays identical to SideStore's and upstream merges don't conflict.

  rebrand.py apply   change the working copy (CI does this; don't commit the result)
  rebrand.py check   change nothing; report entries that no longer match
  rebrand.py revert  undo `apply` in the working copy

If SideStore rewords one of these strings, `apply` stops with the file and the old
text, so the table gets updated instead of SideStore's wording quietly coming back.
Afterwards it lists any other visible "SideStore" text it can find, as a reminder.
"""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TABLE = os.path.join(os.path.dirname(__file__), "strings.json")


def quoted(path, text):
    # Swift string literals and storyboard/xib attribute values are both in double quotes.
    return '"%s"' % text


def run(mode):
    table = json.load(open(TABLE, encoding="utf-8"))["files"]
    missing, changed = [], 0
    for rel, pairs in table.items():
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            missing.append((rel, "(file is gone)"))
            continue
        src = open(path, encoding="utf-8").read()
        out = src
        for old, new in pairs:
            frm, to = (quoted(rel, new), quoted(rel, old)) if mode == "revert" else (quoted(rel, old), quoted(rel, new))
            if frm in out:
                out = out.replace(frm, to)
                changed += 1
            elif to in out:
                pass  # already in the wanted state
            else:
                missing.append((rel, old))
        if mode in ("apply", "revert") and out != src:
            open(path, "w", encoding="utf-8").write(out)

    for rel, old in missing:
        print(f"::error file={rel}::Keel wording: SideStore's text was not found (changed upstream?): {old[:120]}")
    print(f"{mode}: {changed} strings {'changed' if mode != 'check' else 'to change'}, {len(missing)} not found")
    if mode == "apply":
        report_leftovers(table)
    return 1 if missing else 0


SKIP = re.compile(r'debugLog|verboseLog|print\(|Logger|os_log|DispatchQueue\(label|forKey|Notification\.Name|#keyPath|named:|'
                  r'forResource|UTTypeDescription|machineName|errorDomain|appendingPathComponent|hasPrefix|starts\(with|'
                  r'contains\(|== "|SideStore\.conf')


def report_leftovers(table):
    """Prints visible-looking SideStore strings that aren't in the table (warnings only)."""
    count = 0
    for top in ("AltStore", "SideStore", "Shared", "AltWidget"):
        for dp, _, files in os.walk(os.path.join(ROOT, top)):
            if "/tvOS" in dp or "/Tests" in dp or "/Keel" in dp:
                continue
            for f in files:
                if not f.endswith((".swift", ".storyboard", ".xib")):
                    continue
                path = os.path.join(dp, f)
                for n, line in enumerate(open(path, encoding="utf-8"), 1):
                    if line.strip().startswith("//") or SKIP.search(line):
                        continue
                    pattern = r'"((?:[^"\\]|\\.)*)"' if f.endswith(".swift") else r'(?:text|title|placeholder)="([^"]*)"'
                    for m in re.finditer(pattern, line):
                        if re.search(r"\bSideStore\b", m.group(1)) and "sidestore.io" not in m.group(1) and "github.com" not in m.group(1):
                            count += 1
                            print(f"  still says SideStore: {os.path.relpath(path, ROOT)}:{n}: {m.group(1)[:90]}")
    print(f"{count} visible-looking SideStore strings left (credits and file names are kept on purpose)")


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "check"
    if mode not in ("apply", "check", "revert"):
        sys.exit(__doc__)
    sys.exit(run(mode))
