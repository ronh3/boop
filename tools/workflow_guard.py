"""Git-backed version and evidence-history checks; these cannot authenticate roles."""

from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), *args], capture_output=True, check=True
    )
    return result.stdout.decode("utf-8")


def paths_changed(root: Path, before: str, after: str) -> list[str]:
    args = ["diff", "--name-only", "--no-renames", "-z"]
    args += ["--cached", before] if after == ":" else [before, after]
    return [path for path in git(root, *args).split("\0") if path]


def snapshot(root: Path, revision: str, path: str) -> str:
    return git(root, "show", f"{revision.rstrip(':')}:{path}")


def version_at(root: Path, revision: str) -> tuple[int, ...]:
    metadata = json.loads(snapshot(root, revision, "mfile"))
    version = metadata["version"]
    if not isinstance(version, str) or not re.fullmatch(r"\d+\.\d+\.\d+(?:\.\d+)?", version):
        raise ValueError(f"{revision}: version must have three or four numeric components")
    init = snapshot(root, revision, "src/scripts/boop/boop_init.lua")
    codex = snapshot(root, revision, "CODEX.md")
    init_match = re.search(r'boop\.version\s*=\s*"([^"]+)"', init)
    codex_match = re.search(r"Current synchronized package version:\s*`([^`]+)`", codex)
    if (metadata.get("title") != f"boop Hunter {version}"
            or not init_match or init_match[1] != version
            or not codex_match or codex_match[1] != version):
        raise ValueError(f"{revision}: all four version checkpoints must agree")
    parts = tuple(int(part) for part in version.split("."))
    return parts if len(parts) == 4 else (*parts, 0)


def check_transition(root: Path, before: str, after: str) -> list[str]:
    paths = paths_changed(root, before, after)
    if not paths:
        return []
    try:
        old, new = version_at(root, before), version_at(root, after)
    except (ValueError, KeyError, TypeError, subprocess.CalledProcessError) as exc:
        return [f"{after}: cannot verify version transition: {exc}"]
    package_affecting = any(not path.startswith(".planning/") for path in paths)
    if package_affecting and new <= old:
        return [f"{after}: package-affecting commit must increase version above {old}; got {new}"]
    if not package_affecting and new != old:
        return [f"{after}: planning-only commit must preserve version"]
    return []


def phase_baseline(root: Path) -> str:
    state = (root / ".planning/STATE.md").read_text().split("---", 2)[1]
    match = re.search(r"^main_baseline: ([0-9a-f]{40})$", state, re.MULTILINE)
    if not match:
        raise ValueError("STATE.md frontmatter must name a full main_baseline SHA")
    base = match[1]
    # origin/main is the authority even if a local main branch has moved. Do
    # not fall back to HEAD/local main when this ref or its history is absent.
    main_ref = "refs/remotes/origin/main"
    try:
        git(root, "rev-parse", "--verify", f"{main_ref}^{{commit}}")
    except subprocess.CalledProcessError as exc:
        raise ValueError(f"authoritative {main_ref} unavailable; fetch full origin history") from exc
    try:
        git(root, "merge-base", "--is-ancestor", base, main_ref)
    except subprocess.CalledProcessError as exc:
        raise ValueError(f"main_baseline {base} must be an ancestor of {main_ref}") from exc
    git(root, "merge-base", "--is-ancestor", base, "HEAD")
    return base


def transitions(root: Path, base: str) -> list[tuple[str, str]]:
    commits = git(root, "rev-list", "--reverse", f"{base}..HEAD").splitlines()
    return [(f"{sha}^1", sha) for sha in commits] + [("HEAD", ":")]


def check_version_history(root: Path) -> list[str]:
    try:
        errors = []
        for before, after in transitions(root, phase_baseline(root)):
            errors.extend(check_transition(root, before, after))
            if after != ":":
                parents = git(root, "rev-list", "--parents", "-n", "1", after).split()[2:]
                for parent in parents:
                    errors.extend(check_transition(root, parent, after))
        return errors
    except (OSError, ValueError, IndexError, subprocess.CalledProcessError) as exc:
        return [f"cannot check version history (full Git history required): {exc}"]


def check_review_transition(root: Path, before: str, after: str) -> list[str]:
    errors = []
    old_paths = set(git(root, "ls-tree", "-r", "--name-only", "-z", before).split("\0"))
    for path in paths_changed(root, before, after):
        if (path not in old_paths or not path.startswith(".planning/phases/")
                or not path.endswith(("-ADVERSARIAL-REVIEW.md", "-UAT.md", "-VERIFICATION.md"))):
            continue
        old = snapshot(root, before, path)
        try:
            new = snapshot(root, after, path)
        except subprocess.CalledProcessError:
            errors.append(f"{after}: {path}: recorded evidence must not be deleted")
            continue
        if not new.startswith(old):
            errors.append(f"{after}: {path}: recorded evidence must remain an unchanged prefix")
    return errors


def check_staged_branch(root: Path) -> list[str]:
    if not paths_changed(root, "HEAD", ":"):
        return []
    branch = git(root, "branch", "--show-current").strip()
    state = snapshot(root, ":", ".planning/STATE.md").split("---", 2)[1]
    match = re.search(r"^active_branch: (phase/[0-9]+(?:\.[0-9]+)?-[a-z0-9-]+)$", state, re.MULTILINE)
    if not match or branch != match[1]:
        return ["staged work requires the active phase branch; no direct main or detached commits"]
    return []


def check_workflow(root: Path) -> list[str]:
    try:
        errors = check_staged_branch(root)
        if (root / ".planning/config.json").exists():
            errors.append("retired .planning/config.json must not be operational")
        for before, after in transitions(root, phase_baseline(root)):
            errors.extend(check_review_transition(root, before, after))
            # A merge must preserve recorded history from every parent, too.
            if after != ":":
                parents = git(root, "rev-list", "--parents", "-n", "1", after).split()[2:]
                for parent in parents:
                    errors.extend(check_review_transition(root, parent, after))
        return errors
    except (OSError, ValueError, IndexError, subprocess.CalledProcessError) as exc:
        return [f"cannot check workflow history: {exc}"]
