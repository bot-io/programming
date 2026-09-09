#!/usr/bin/env python3
"""Regenerate run-batched-tests.sh from the actual test directory listing.

Discovers every *Test.kt class under app/src/test/java, converts paths to
fully-qualified JVM names, and groups them into batches of ~12 classes
(fresh JVM per batch to bound MockK/Kotlin-reflection metaspace growth).

Usage: python3 regenerate-test-batches.py [--batch-size 12] [--check]
  --check: exit 1 if run-batched-tests.sh is out of sync with the test dir
           (used to detect stale coverage after adding test classes)

Auto-detects script location: works from repo root or the android project dir.
"""
import argparse
import subprocess
import sys
from pathlib import Path

TEMPLATE_MARKER = "%_BATCHES%"
CLASSES_PER_BATCH = 8


def find_project_root() -> Path:
    """Locate dual-reader-android root from script location or cwd."""
    script_dir = Path(__file__).resolve().parent
    for candidate in (script_dir, script_dir.parent):
        if (candidate / "app" / "src" / "test" / "java").is_dir():
            return candidate
    # Fall back to cwd
    cwd = Path.cwd()
    if (cwd / "app" / "src" / "test" / "java").is_dir():
        return cwd
    raise SystemExit("ERROR: could not locate dual-reader-android project root")


def discover_test_classes(root: Path) -> list[str]:
    """Return sorted FQNs of all *Test.kt classes under app/src/test/java."""
    test_dir = root / "app" / "src" / "test" / "java"
    classes = []
    for kt in sorted(test_dir.rglob("*Test.kt")):
        rel = kt.relative_to(test_dir).with_suffix("")
        fqn = ".".join(rel.parts)
        classes.append(fqn)
    if not classes:
        raise SystemExit("ERROR: no test classes found under app/src/test/java")
    return classes


def build_batches(classes: list[str], size: int) -> list[list[str]]:
    return [classes[i : i + size] for i in range(0, len(classes), size)]


def render_batches(batches: list[list[str]]) -> str:
    lines = []
    for batch in batches:
        lines.append("run_batch %d \\" % len(batch))
        for fqn in batch:
            lines.append('    --tests "%s" \\' % fqn)
        # replace trailing " \" of last entry with nothing
        lines[-1] = lines[-1].rstrip(" \\")
        lines.append("")
    return "\n".join(lines)


def regenerate(root: Path, batch_size: int) -> tuple[int, int]:
    template_path = root / "test-runner-template.sh"
    out_path = root / "run-batched-tests.sh"
    if not template_path.exists():
        raise SystemExit(f"ERROR: template not found: {template_path}")
    classes = discover_test_classes(root)
    batches = build_batches(classes, batch_size)
    template = template_path.read_text(encoding="utf-8")
    if TEMPLATE_MARKER not in template:
        raise SystemError("template is missing %s marker" % TEMPLATE_MARKER)
    content = template.replace(TEMPLATE_MARKER, render_batches(batches))
    out_path.write_text(content, encoding="utf-8", newline="\n")
    return len(classes), len(batches)


def check_sync(root: Path, batch_size: int) -> bool:
    classes = discover_test_classes(root)
    expected = set(classes)
    script = (root / "run-batched-tests.sh").read_text(encoding="utf-8")
    listed = {
        line.split('"')[1]
        for line in script.splitlines()
        if "--tests" in line and '"' in line
    }
    missing = expected - listed
    stale = listed - expected
    if missing or stale:
        print(f"OUT OF SYNC: {len(missing)} missing, {len(stale)} stale")
        for c in sorted(missing):
            print(f"  missing: {c}")
        for c in sorted(stale):
            print(f"  stale: {c}")
        return False
    print(f"in sync: {len(expected)} classes covered")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--batch-size", type=int, default=CLASSES_PER_BATCH)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = find_project_root()
    if args.check:
        sys.exit(0 if check_sync(root, args.batch_size) else 1)
    n_classes, n_batches = regenerate(root, args.batch_size)
    print(f"regenerated: {n_classes} classes in {n_batches} batches -> run-batched-tests.sh")


if __name__ == "__main__":
    main()
