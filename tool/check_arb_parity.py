#!/usr/bin/env python3
"""Fail if any locale's ARB has drifted from the English key set.

`flutter gen-l10n` is happy to generate from a locale missing half its keys:
the generated class simply falls back, so a dropped translation reaches a
user as English rather than as a build failure. This compares every
app_<locale>.arb against app_en.arb and reports both directions, because an
*extra* key is just as much a sign of a bad merge as a missing one.
"""

import json
import os
import sys

DIRECTORY = "apps/app/lib/l10n"


def keys(path):
    with open(path, encoding="utf-8") as handle:
        return {k for k in json.load(handle) if not k.startswith("@")}


def main():
    names = sorted(
        f for f in os.listdir(DIRECTORY) if f.startswith("app_") and f.endswith(".arb")
    )
    arbs = {name[4:-4]: keys(os.path.join(DIRECTORY, name)) for name in names}
    english = arbs["en"]
    drifted = [
        (locale, sorted(english - found), sorted(found - english))
        for locale, found in arbs.items()
        if locale != "en" and (english - found or found - english)
    ]
    print(f"  {len(arbs)} locales, {len(english)} keys each")
    if not drifted:
        return 0
    print("PARITY ISSUES:")
    for locale, missing, extra in drifted:
        print(f"  {locale}: missing={missing} extra={extra}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
