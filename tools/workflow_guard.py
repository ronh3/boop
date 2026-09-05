"""Git-backed version and evidence-history checks; these cannot authenticate roles."""

from __future__ import annotations

import json
from pathlib import Path
import re
import subprocess


HANDOFF_PATHS = {
    ".planning/CODEX-NEXT.md": "codex",
    ".planning/CLAUDE-NEXT.md": "claude",
}
HANDOFF_FIELDS = {
    "handoff_version", "status", "agent", "mode", "branch",
    "task_base_sha", "review_target_sha", "assigned_by",
}
HANDOFF_STATUSES = {"idle", "ready", "consumed"}
HANDOFF_MODES = {"active_phase", "phase_bootstrap"}


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


def frontmatter(text: str, location: str) -> dict[str, str | None]:
    if not text.startswith("---\n"):
        raise ValueError(f"{location}: missing YAML frontmatter")
    try:
        header = text.split("---", 2)[1]
    except IndexError as exc:
        raise ValueError(f"{location}: unterminated YAML frontmatter") from exc
    values: dict[str, str | None] = {}
    for line in header.splitlines():
        if not line:
            continue
        match = re.fullmatch(r"([a-z_]+): (.*)", line)
        if not match:
            raise ValueError(f"{location}: malformed frontmatter line {line!r}")
        key, value = match.groups()
        if key in values:
            raise ValueError(f"{location}: duplicate frontmatter field {key}")
        values[key] = None if value == "null" else value.strip('"')
    return values


def handoff_at(root: Path, revision: str, path: str) -> dict[str, str | None]:
    values = frontmatter(snapshot(root, revision, path), path)
    if set(values) != HANDOFF_FIELDS:
        missing = sorted(HANDOFF_FIELDS - set(values))
        unknown = sorted(set(values) - HANDOFF_FIELDS)
        raise ValueError(f"{path}: handoff schema mismatch (missing={missing}, unknown={unknown})")
    return values


def handoff_errors(root: Path, revision: str = ":") -> list[str]:
    """Validate mailboxes; this validates structure and ancestry, not human identity."""
    errors: list[str] = []
    for path, expected_agent in HANDOFF_PATHS.items():
        try:
            handoff = handoff_at(root, revision, path)
        except (ValueError, subprocess.CalledProcessError) as exc:
            errors.append(str(exc))
            continue
        status, agent, mode = handoff["status"], handoff["agent"], handoff["mode"]
        if handoff["handoff_version"] != "1":
            errors.append(f"{path}: handoff_version must be 1")
        if agent != expected_agent:
            errors.append(f"{path}: agent must be {expected_agent}")
        if status not in HANDOFF_STATUSES:
            errors.append(f"{path}: status must be idle, ready, or consumed")
        if handoff["assigned_by"] != "Human + ChatGPT/Neon":
            errors.append(f"{path}: assigned_by must be Human + ChatGPT/Neon")
        if status == "idle":
            for field in ("mode", "branch", "task_base_sha", "review_target_sha"):
                if handoff[field] is not None:
                    errors.append(f"{path}: idle handoffs require {field}: null")
            continue
        if mode not in HANDOFF_MODES:
            errors.append(f"{path}: active handoffs require a known mode")
        if agent == "claude" and mode != "active_phase":
            errors.append(f"{path}: Claude may use only mode: active_phase")
        branch = handoff["branch"]
        if not branch or not re.fullmatch(r"phase/[0-9]+(?:\.[0-9]+)?-[a-z0-9-]+", branch):
            errors.append(f"{path}: active handoffs require a valid phase branch")
        base = handoff["task_base_sha"]
        if not base or not re.fullmatch(r"[0-9a-f]{40}", base):
            errors.append(f"{path}: active handoffs require a full task_base_sha")
        else:
            try:
                git(root, "rev-parse", "--verify", f"{base}^{{commit}}")
                git(root, "merge-base", "--is-ancestor", base, "HEAD")
            except subprocess.CalledProcessError:
                errors.append(f"{path}: task_base_sha must resolve to a HEAD ancestor")
        target = handoff["review_target_sha"]
        if agent == "claude" and (not target or not re.fullmatch(r"[0-9a-f]{40}", target)):
            errors.append(f"{path}: Claude ready/consumed handoffs require review_target_sha")
        if target and not re.fullmatch(r"[0-9a-f]{40}", target):
            errors.append(f"{path}: review_target_sha must be null or a full SHA")
        if status == "ready" and mode == "active_phase":
            try:
                state = frontmatter(snapshot(root, revision, ".planning/STATE.md"), ".planning/STATE.md")
                if branch != state.get("active_branch"):
                    errors.append(f"{path}: ready active_phase branch must match STATE active_branch")
            except (ValueError, subprocess.CalledProcessError) as exc:
                errors.append(str(exc))
        # consumed handoffs retain their provenance but are explicitly non-executable.
    return errors


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
    if match and branch == match[1]:
        return []
    # A new phase may receive precisely its CODEX handoff before STATE moves to
    # that phase. This is intentionally a one-commit delivery exception.
    changed = set(paths_changed(root, "HEAD", ":"))
    try:
        handoff = handoff_at(root, ":", ".planning/CODEX-NEXT.md")
        base = handoff["task_base_sha"]
        origin_main = git(root, "rev-parse", "refs/remotes/origin/main^{commit}").strip()
        fork = git(root, "merge-base", "HEAD", "refs/remotes/origin/main").strip()
        bootstrap = (
            handoff["status"] == "ready"
            and handoff["agent"] == "codex"
            and handoff["mode"] == "phase_bootstrap"
            and handoff["branch"] == branch
            and base == origin_main == fork
            and changed == {".planning/CODEX-NEXT.md"}
        )
    except (ValueError, subprocess.CalledProcessError):
        bootstrap = False
    if not bootstrap:
        return ["staged work requires the active phase branch; no direct main or detached commits (except the bounded CODEX phase_bootstrap handoff delivery)"]
    return []


def check_workflow(root: Path) -> list[str]:
    try:
        errors = handoff_errors(root) + check_staged_branch(root)
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
