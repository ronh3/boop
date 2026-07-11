#!/usr/bin/env python3
"""Local release gates for boop Hunter.

Checks are intentionally dependency-free so maintainers and CI run the same
deterministic gate before Muddler builds the package.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SRC_ROOTS = {
    "scripts": ROOT / "src" / "scripts",
    "aliases": ROOT / "src" / "aliases",
    "triggers": ROOT / "src" / "triggers",
}
MANIFEST_NAMES = {
    "scripts": "scripts.json",
    "aliases": "aliases.json",
    "triggers": "triggers.json",
}
OWNED_STATE_DOMAINS = {
    "combat",
    "targeting",
    "gold",
    "queue",
    "walk",
    "diag",
    "trace",
    "ui",
    "rage",
    "inventory",
    "ih",
    "gag",
}

# Reviewed legacy flat-state accesses that still exist before Phase 2 behavior
# repair work. The gate fails when this baseline grows or shrinks without review.
KNOWN_FLAT_STATE_ACCESS = {
    "src/scripts/boop/boop_events.lua": {},
    "src/scripts/boop/boop_walk.lua": {},
    "src/scripts/boop/boop_attacks.lua": {},
}


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_json(path: Path) -> tuple[object | None, str | None]:
    try:
        return json.loads(path.read_text()), None
    except Exception as exc:  # JSONDecodeError, OSError
        return None, f"{rel(path)}: {exc}"


def manifest_stem(entry: dict[str, object]) -> str:
    script = str(entry.get("script") or "").strip()
    name = str(entry.get("name") or "").strip()
    stem = script or name
    if stem.endswith(".lua"):
        stem = stem[:-4]
    return stem.replace(" ", "_")


def is_folder(entry: dict[str, object]) -> bool:
    value = entry.get("isFolder")
    if isinstance(value, bool):
        return value
    return str(value or "").strip().lower() == "yes"


def check_versions() -> list[str]:
    errors: list[str] = []
    mfile_path = ROOT / "mfile"
    init_path = ROOT / "src" / "scripts" / "boop" / "boop_init.lua"
    codex_path = ROOT / "CODEX.md"

    mfile, err = read_json(mfile_path)
    if err:
        return [err]
    if not isinstance(mfile, dict):
        return [f"{rel(mfile_path)}: expected a JSON object"]

    mfile_version = str(mfile.get("version") or "")
    mfile_title = str(mfile.get("title") or "")
    expected_title = f"boop Hunter {mfile_version}"
    if not mfile_version:
        errors.append("mfile: missing version")
    if mfile_title != expected_title:
        errors.append(
            f"mfile: title {mfile_title!r} must be exactly {expected_title!r}"
        )

    init_text = init_path.read_text()
    init_match = re.search(
        r'boop\.version\s*=\s*boop\.version\s+or\s+"([^"]+)"', init_text
    )
    if not init_match:
        errors.append(f"{rel(init_path)}: could not find boop.version assignment")
    elif init_match.group(1) != mfile_version:
        errors.append(
            f"{rel(init_path)}: boop.version {init_match.group(1)!r} "
            f"does not match mfile.version {mfile_version!r}"
        )

    codex_text = codex_path.read_text()
    codex_match = re.search(
        r"Current synchronized package version:\s*`([^`]+)`", codex_text
    )
    if not codex_match:
        errors.append(f"{rel(codex_path)}: missing synchronized package checkpoint")
    elif codex_match.group(1) != mfile_version:
        errors.append(
            f"{rel(codex_path)}: checkpoint {codex_match.group(1)!r} "
            f"does not match mfile.version {mfile_version!r}"
        )

    return errors


def walk_manifest(
    manifest_path: Path,
    manifest_name: str,
    referenced: set[Path],
    errors: list[str],
    seen: set[Path],
) -> None:
    if manifest_path in seen:
        errors.append(f"{rel(manifest_path)}: recursive manifest loop")
        return
    seen.add(manifest_path)

    data, err = read_json(manifest_path)
    if err:
        errors.append(err)
        return
    if not isinstance(data, list):
        errors.append(f"{rel(manifest_path)}: expected a JSON array")
        return

    manifest_dir = manifest_path.parent
    for index, entry in enumerate(data, start=1):
        if not isinstance(entry, dict):
            errors.append(f"{rel(manifest_path)}[{index}]: expected object entry")
            continue
        name = str(entry.get("name") or "").strip()
        if not name:
            errors.append(f"{rel(manifest_path)}[{index}]: missing name")
            continue
        stem = manifest_stem(entry)
        if not stem:
            errors.append(f"{rel(manifest_path)}[{index}]: empty script/name stem")
            continue

        if is_folder(entry):
            child_dir = manifest_dir / stem
            child_manifest = child_dir / manifest_name
            if not child_dir.is_dir():
                errors.append(
                    f"{rel(manifest_path)}[{index}] {name!r}: "
                    f"missing folder {rel(child_dir)}"
                )
                continue
            if not child_manifest.is_file():
                errors.append(
                    f"{rel(manifest_path)}[{index}] {name!r}: "
                    f"missing child manifest {rel(child_manifest)}"
                )
                continue
            walk_manifest(child_manifest, manifest_name, referenced, errors, seen)
            continue

        lua_path = manifest_dir / f"{stem}.lua"
        referenced.add(lua_path.resolve())
        if not lua_path.is_file():
            errors.append(
                f"{rel(manifest_path)}[{index}] {name!r}: "
                f"missing Lua file {rel(lua_path)}"
            )


def check_manifests() -> list[str]:
    errors: list[str] = []

    for json_path in sorted((ROOT / "src").rglob("*.json")):
        _, err = read_json(json_path)
        if err:
            errors.append(err)

    # mfile is package JSON too, even though it is extensionless.
    _, err = read_json(ROOT / "mfile")
    if err:
        errors.append(err)

    referenced: set[Path] = set()
    for kind, root in SRC_ROOTS.items():
        manifest_name = MANIFEST_NAMES[kind]
        manifest_path = root / manifest_name
        if not manifest_path.is_file():
            errors.append(f"{rel(manifest_path)}: missing root manifest")
            continue
        walk_manifest(manifest_path, manifest_name, referenced, errors, set())

    for root in SRC_ROOTS.values():
        for lua_path in sorted(root.rglob("*.lua")):
            if lua_path.resolve() not in referenced:
                errors.append(f"{rel(lua_path)}: orphan Lua file not in manifest")

    return errors


def scan_flat_state_access(path: Path) -> Counter[str]:
    pattern = re.compile(
        r"\b(?:state|vars|liveState)\.([A-Za-z_][A-Za-z0-9_]*)"
        r"|\bboop\.state\.([A-Za-z_][A-Za-z0-9_]*)"
    )
    counts: Counter[str] = Counter()
    for raw_line in path.read_text().splitlines():
        line = raw_line.split("--", 1)[0]
        for match in pattern.finditer(line):
            key = match.group(1) or match.group(2)
            if key not in OWNED_STATE_DOMAINS:
                counts[key] += 1
    return counts


def check_state_drift() -> list[str]:
    errors: list[str] = []
    for file_name, expected in KNOWN_FLAT_STATE_ACCESS.items():
        path = ROOT / file_name
        if not path.is_file():
            errors.append(f"{file_name}: baseline file is missing")
            continue
        actual = scan_flat_state_access(path)
        expected_counter = Counter(expected)
        if actual == expected_counter:
            continue

        for key in sorted(set(expected_counter) | set(actual)):
            expected_count = expected_counter.get(key, 0)
            actual_count = actual.get(key, 0)
            if expected_count == actual_count:
                continue
            if expected_count == 0:
                errors.append(
                    f"{file_name}: new flat-state access {key!r} "
                    f"appears {actual_count} time(s)"
                )
            elif actual_count == 0:
                errors.append(
                    f"{file_name}: reviewed flat-state access {key!r} "
                    "is gone; update the baseline intentionally"
                )
            else:
                errors.append(
                    f"{file_name}: flat-state access {key!r} changed "
                    f"from {expected_count} to {actual_count}; review baseline"
                )
    return errors


CHECKS = {
    "versions": check_versions,
    "manifests": check_manifests,
    "state-drift": check_state_drift,
}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="append",
        choices=["all", *CHECKS.keys()],
        help="Run one check. May be passed more than once. Default: all.",
    )
    return parser.parse_args(argv)


def selected_checks(values: list[str] | None) -> list[str]:
    if not values or "all" in values:
        return list(CHECKS)
    return values


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    checks = selected_checks(args.check)
    failed = False

    for name in checks:
        errors = CHECKS[name]()
        if errors:
            failed = True
            print(f"[FAIL] {name}")
            for error in errors:
                print(f"  - {error}")
        else:
            print(f"[OK] {name}")

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
