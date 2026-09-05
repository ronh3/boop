#!/usr/bin/env python3
"""Validate the selected ready handoff before an agent starts its assignment.

This is a structural, repository-local guard. It cannot authenticate the human
assigner or prove that an agent actually invoked it.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

from workflow_guard import git, handoff_at, handoff_errors, paths_changed


ROOT = Path(__file__).resolve().parents[1]
PATHS = {"codex": ".planning/CODEX-NEXT.md", "claude": ".planning/CLAUDE-NEXT.md"}


def execution_errors(root: Path, agent: str) -> list[str]:
    path = PATHS[agent]
    errors = handoff_errors(root)
    try:
        handoff = handoff_at(root, ":", path)
        branch = git(root, "branch", "--show-current").strip()
        if handoff["status"] != "ready":
            errors.append(f"{path}: handoff must be ready before execution")
        if branch != handoff["branch"]:
            errors.append(f"{path}: current branch must equal handoff branch")
        remote = git(root, "rev-parse", f"refs/remotes/origin/{branch}^{{commit}}").strip()
        head = git(root, "rev-parse", "HEAD^{commit}").strip()
        if head != remote:
            errors.append(f"{path}: local branch must equal origin branch")
        base = handoff["task_base_sha"]
        if base:
            commits = git(root, "rev-list", "--reverse", f"{base}..HEAD").splitlines()
            allowed = set(PATHS.values()) | {".planning/STATE.md"}
            phase = handoff["branch"].removeprefix("phase/").split("-", 1)[0] if handoff["branch"] else ""
            phase_prefix = f".planning/phases/{phase}-"
            for commit in commits:
                for changed in paths_changed(root, f"{commit}^1", commit):
                    if (not changed.startswith(".planning/")
                            or (changed not in allowed and not changed.startswith(phase_prefix))):
                        errors.append(f"{commit}: unexpected pre-execution change: {changed}")
        if handoff["mode"] == "phase_bootstrap":
            origin_main = git(root, "rev-parse", "refs/remotes/origin/main^{commit}").strip()
            fork = git(root, "merge-base", "HEAD", "refs/remotes/origin/main").strip()
            if handoff["task_base_sha"] != origin_main or fork != origin_main:
                errors.append(f"{path}: phase_bootstrap must fork exactly from its origin/main task base")
    except (ValueError, subprocess.CalledProcessError) as exc:
        errors.append(str(exc))
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--agent", required=True, choices=sorted(PATHS))
    parser.add_argument("--fetch", action="store_true", help="fetch origin and tags before evaluating")
    args = parser.parse_args()
    if args.fetch:
        subprocess.run(["git", "-C", str(ROOT), "fetch", "origin", "--tags", "--prune"], check=True)
    errors = execution_errors(ROOT, args.agent)
    for error in errors:
        print(f"[FAIL] {error}")
    if not errors:
        print(f"[OK] {args.agent} ready handoff may execute")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
