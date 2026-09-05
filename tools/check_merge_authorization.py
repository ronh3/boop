#!/usr/bin/env python3
"""Check the narrow reviewed closure tail and an external approval tag.

This is a pre-authorization/pre-merge check.  It deliberately is not a normal
release gate: corrections must remain possible before Claude re-reviews them.
Git metadata can bind objects and ordering but cannot authenticate human intent.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import sys

from workflow_guard import git, paths_changed, snapshot


ROOT = Path(__file__).resolve().parents[1]


def reviewed_targets(root: Path, phase: str, candidate: str) -> list[str]:
    path = f".planning/phases/{phase}-agent-handoffs/{phase}-ADVERSARIAL-REVIEW.md"
    # Future contexts may use another slug; find the one phase review artifact.
    try:
        text = snapshot(root, candidate, path)
    except subprocess.CalledProcessError:
        matches = git(root, "ls-tree", "-r", "--name-only", candidate).splitlines()
        suffix = f"/{phase}-ADVERSARIAL-REVIEW.md"
        found = [item for item in matches if item.startswith(".planning/phases/") and item.endswith(suffix)]
        if len(found) != 1:
            raise ValueError(f"cannot locate exactly one {phase} adversarial-review artifact")
        text = snapshot(root, candidate, found[0])
    patterns = [
        r"^\*\*Reviewed SHA:\*\* `([0-9a-f]{40})`",
        r"^\*\*Reviewed target SHA:\*\* `?([0-9a-f]{40})`?",
        r"^Reviewed target SHA:\s*`?([0-9a-f]{40})`?",
    ]
    targets: list[str] = []
    for pattern in patterns:
        targets.extend(re.findall(pattern, text, re.MULTILINE | re.IGNORECASE))
    return targets


def closure_tail_errors(root: Path, phase: str, candidate: str = "HEAD") -> list[str]:
    try:
        targets = reviewed_targets(root, phase, candidate)
        if not targets:
            return ["no independently reviewed target SHA is recorded"]
        reviewed = targets[-1]
        git(root, "merge-base", "--is-ancestor", reviewed, candidate)
        permitted_prefix = f".planning/phases/{phase}-"
        permitted_exact = {
            ".planning/STATE.md",
            ".planning/CODEX-NEXT.md",
            ".planning/CLAUDE-NEXT.md",
        }
        evidence_suffixes = ("-ADVERSARIAL-REVIEW.md", "-VERIFICATION.md", "-UAT.md")
        errors: list[str] = []
        commits = git(root, "rev-list", "--reverse", f"{reviewed}..{candidate}").splitlines()
        for commit in commits:
            parent = f"{commit}^1"
            for path in paths_changed(root, parent, commit):
                permitted = (
                    path in permitted_exact
                    or (path.startswith(permitted_prefix) and path.endswith(evidence_suffixes))
                )
                if not permitted:
                    errors.append(f"{commit}: unreviewed post-review change is not permitted in closure tail: {path}")
        return errors
    except (ValueError, subprocess.CalledProcessError) as exc:
        return [f"cannot check reviewed closure tail: {exc}"]


def tag_message_errors(root: Path, tag: str, phase: str, target: str) -> list[str]:
    errors: list[str] = []
    try:
        kind = git(root, "cat-file", "-t", tag).strip()
        peeled_kind = git(root, "cat-file", "-t", f"{tag}^{{commit}}").strip()
        peeled = git(root, "rev-parse", f"{tag}^{{commit}}").strip()
        message = git(root, "for-each-ref", f"refs/tags/{tag}", "--format=%(contents)")
    except subprocess.CalledProcessError as exc:
        return [f"approval tag {tag} is unavailable: {exc}"]
    if kind != "tag":
        errors.append(f"{tag}: approval tag must be annotated")
    if peeled_kind != "commit":
        errors.append(f"{tag}: approval tag must peel to a commit")
    match = re.fullmatch(rf"phase-{re.escape(phase)}-approved-([0-9a-f]{{12}})", tag)
    if not match:
        errors.append(f"{tag}: approval tag name must bind phase and 12-character SHA")
    elif match[1] != peeled[:12]:
        errors.append(f"{tag}: tag suffix does not match peeled target")
    if peeled != target:
        errors.append(f"{tag}: peeled target does not equal authorized candidate")
    if not re.search(r"human (?:merge )?authoriz", message, re.IGNORECASE):
        errors.append(f"{tag}: annotation must record human authorization")
    if not re.search(r"\b20\d\d-\d\d-\d\d\b", message):
        errors.append(f"{tag}: annotation must record an ISO date")
    if not re.search(rf"\bphase\s+{re.escape(phase)}\b", message, re.IGNORECASE):
        errors.append(f"{tag}: annotation must record phase {phase}")
    shas = re.findall(r"\b[0-9a-f]{40}\b", message)
    if target not in shas:
        errors.append(f"{tag}: annotation must record the exact full target SHA")
    return errors


def approval_tag_errors(root: Path, phase: str, candidate: str = "HEAD", branch: str | None = None) -> list[str]:
    """Validate the latest valid phase approval tag and local/remote parity."""
    try:
        candidate_sha = git(root, "rev-parse", f"{candidate}^{{commit}}").strip()
        branch = branch or git(root, "branch", "--show-current").strip()
        remote_head = git(root, "rev-parse", f"refs/remotes/origin/{branch}^{{commit}}").strip()
        local_head = git(root, "rev-parse", "HEAD^{commit}").strip()
    except subprocess.CalledProcessError as exc:
        return [f"cannot resolve local/remote phase boundary: {exc}"]
    errors: list[str] = []
    if local_head != remote_head or local_head != candidate_sha:
        errors.append("local phase HEAD, origin phase HEAD, and authorized candidate must agree")
    names = git(root, "tag", "-l", f"phase-{phase}-approved-*").splitlines()
    valid: list[tuple[int, str]] = []
    for name in names:
        if tag_message_errors(root, name, phase, git(root, "rev-parse", f"{name}^{{commit}}").strip()):
            continue
        stamp = int(git(root, "for-each-ref", f"refs/tags/{name}", "--format=%(taggerdate:unix)").strip() or "0")
        valid.append((stamp, name))
    if not valid:
        return errors + [f"no valid approval tag exists for phase {phase}"]
    _, latest = max(valid)
    errors.extend(tag_message_errors(root, latest, phase, candidate_sha))
    if latest:
        try:
            local_object = git(root, "rev-parse", latest).strip()
            remote = git(root, "ls-remote", "--tags", "origin", f"refs/tags/{latest}").split()[0]
            if local_object != remote:
                errors.append(f"{latest}: local and origin tag objects differ")
        except (IndexError, subprocess.CalledProcessError):
            errors.append(f"{latest}: cannot verify matching origin tag object")
    return errors


def check_premerge(root: Path, phase: str, candidate: str = "HEAD", branch: str | None = None) -> list[str]:
    return closure_tail_errors(root, phase, candidate) + approval_tag_errors(root, phase, candidate, branch)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--candidate", default="HEAD")
    parser.add_argument("--branch")
    args = parser.parse_args()
    errors = check_premerge(ROOT, args.phase, args.candidate, args.branch)
    for error in errors:
        print(f"[FAIL] {error}")
    if not errors:
        print("[OK] reviewed closure tail and approval tag")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
