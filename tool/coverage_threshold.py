#!/usr/bin/env python3
"""Fail if line coverage across the workspace drops below a floor.

Run after `melos run test`, which writes one lcov per member:

    python3 tool/coverage_threshold.py            # uses MIN_LINE_COVERAGE below
    python3 tool/coverage_threshold.py 65         # explicit floor
    python3 tool/coverage_threshold.py --report   # per-file table, never fails

A floor (rather than a target) is deliberate: it ratchets. Raise
MIN_LINE_COVERAGE whenever a phase lands real coverage, and it can then never
silently regress. Generated sources and localisations are excluded because
their line counts swamp the hand-written code and would let real regressions
hide behind codegen churn.

Every member that produces an lcov report is measured, not just the
application. Reading one member's report would turn the ratchet into a leak:
extracting a well-tested file into a module would raise the reported figure
by removing lines from the denominator, and extracting a poorly tested one
would hide it entirely.

Pure-Dart members are not covered yet: `dart test --coverage` emits a
different format that needs `format_coverage` to become lcov. Their tests
run, but their lines are counted by neither the numerator nor the
denominator.
"""

import sys
from pathlib import Path

# Ratchet. Raise this — never lower it — as coverage improves.
MIN_LINE_COVERAGE = 78.0

# One per workspace member that has tests.
LCOV_REPORTS = sorted(Path(".").glob("*/*/coverage/lcov.info"))

# Excluded from the aggregate: drift/dart_mappable output and the generated
# AppLocalizations. Nothing here is hand-written, so it is neither meaningful
# to test nor meaningful to count.
EXCLUDE_SUFFIXES = (".g.dart", ".mapper.dart")
EXCLUDE_DIRS = ("lib/l10n/",)


def excluded(path: str) -> bool:
    return path.endswith(EXCLUDE_SUFFIXES) or any(
        d in path for d in EXCLUDE_DIRS
    )


def parse(text: str) -> list[tuple[str, int, int]]:
    """Return [(source_file, lines_found, lines_hit)] per record."""
    out: list[tuple[str, int, int]] = []
    current = None
    found = hit = 0
    for line in text.splitlines():
        if line.startswith("SF:"):
            current, found, hit = line[3:], 0, 0
        elif line.startswith("LF:"):
            found = int(line[3:])
        elif line.startswith("LH:"):
            hit = int(line[3:])
        elif line.startswith("end_of_record") and current is not None:
            out.append((current, found, hit))
            current = None
    return out


def main() -> int:
    args = [a for a in sys.argv[1:]]
    report = "--report" in args
    if report:
        args.remove("--report")
    floor = float(args[0]) if args else MIN_LINE_COVERAGE

    if not LCOV_REPORTS:
        print("No lcov report found — run `melos run test` first.")
        return 1

    # Prefix each record with its member, so two modules owning a
    # lib/src/<same name>.dart are counted and reported separately.
    records = [
        (f"{report.parent.parent}/{path}", found, hit)
        for report in LCOV_REPORTS
        for path, found, hit in parse(report.read_text())
        if not excluded(path)
    ]
    if not records:
        print("No coverage records left after exclusions.")
        return 1

    total_found = sum(r[1] for r in records)
    total_hit = sum(r[2] for r in records)
    pct = 100.0 * total_hit / total_found if total_found else 0.0

    if report:
        for path, found, hit in sorted(
            records, key=lambda r: (r[2] / r[1] if r[1] else 0)
        ):
            share = 100.0 * hit / found if found else 0.0
            print(f"{share:6.1f}%  {hit:5d}/{found:<5d} {path}")
        print()

    print(f"Line coverage: {total_hit}/{total_found} = {pct:.1f}% (floor {floor:.1f}%)")
    if pct + 1e-9 < floor:
        print(f"FAIL: coverage {pct:.1f}% is below the {floor:.1f}% floor.")
        return 1
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
