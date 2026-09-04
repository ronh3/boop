#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

EXPECTED_SHA="${1:-$(git rev-parse HEAD)}"
WORKFLOW="${BOOP_CI_WORKFLOW:-main.yml}"
DISCOVERY_TIMEOUT="${BOOP_CI_DISCOVERY_TIMEOUT:-300}"
POLL_SECONDS="${BOOP_CI_POLL_SECONDS:-5}"

fail() {
  printf 'exact-CI gate failed: %s\n' "$*" >&2
  exit 1
}

[[ "$EXPECTED_SHA" =~ ^[0-9a-f]{40}$ ]] || fail "expected a full 40-character commit SHA"
[[ "$(git rev-parse HEAD)" == "$EXPECTED_SHA" ]] || fail "HEAD does not match expected SHA $EXPECTED_SHA"
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || fail "worktree is not clean"
EXPECTED_BRANCH="$(git branch --show-current)"
[[ "$EXPECTED_BRANCH" =~ ^(main|phase/[0-9]+(\.[0-9]+)?-[a-z0-9-]+)$ ]] || fail "expected a named main or phase branch"

command -v gh >/dev/null 2>&1 || fail "gh is not installed"
gh auth status >/dev/null 2>&1 || fail "gh is not authenticated"

remote_match="$(
  git ls-remote --heads origin "refs/heads/$EXPECTED_BRANCH" |
    awk -v sha="$EXPECTED_SHA" '$1 == sha { found = 1 } END { if (found) print sha }'
)"
[[ "$remote_match" == "$EXPECTED_SHA" ]] || fail "origin/$EXPECTED_BRANCH does not point to $EXPECTED_SHA"

deadline=$((SECONDS + DISCOVERY_TIMEOUT))
run_id=""
while [[ -z "$run_id" && $SECONDS -lt $deadline ]]; do
  run_id="$(
    gh run list \
      --workflow "$WORKFLOW" \
      --commit "$EXPECTED_SHA" \
      --branch "$EXPECTED_BRANCH" \
      --event push \
      --limit 20 \
      --json databaseId,headSha \
      --jq "[.[] | select(.headSha == \"$EXPECTED_SHA\")] | first | .databaseId // empty"
  )"
  [[ -n "$run_id" ]] || sleep "$POLL_SECONDS"
done

[[ -n "$run_id" ]] || fail "no $WORKFLOW run appeared for $EXPECTED_SHA within ${DISCOVERY_TIMEOUT}s"

printf 'Watching %s run %s for %s\n' "$WORKFLOW" "$run_id" "$EXPECTED_SHA"
gh run watch "$run_id" --exit-status

run_sha="$(gh run view "$run_id" --json headSha --jq .headSha)"
conclusion="$(gh run view "$run_id" --json conclusion --jq .conclusion)"
run_url="$(gh run view "$run_id" --json url --jq .url)"
run_event="$(gh run view "$run_id" --json event --jq .event)"
run_branch="$(gh run view "$run_id" --json headBranch --jq .headBranch)"
run_attempt="$(gh run view "$run_id" --json attempt --jq .attempt)"

[[ "$run_sha" == "$EXPECTED_SHA" ]] || fail "run headSha $run_sha does not match $EXPECTED_SHA"
[[ "$conclusion" == "success" ]] || fail "run conclusion is $conclusion"
[[ "$run_event" == "push" ]] || fail "run event is $run_event, expected push"
[[ "$run_branch" == "$EXPECTED_BRANCH" ]] || fail "run branch is $run_branch, expected $EXPECTED_BRANCH"
[[ "$(git rev-parse HEAD)" == "$EXPECTED_SHA" ]] || fail "HEAD changed while CI was running"
[[ "$(git branch --show-current)" == "$EXPECTED_BRANCH" ]] || fail "branch changed while CI was running"
[[ -z "$(git status --porcelain --untracked-files=all)" ]] || fail "worktree changed while CI was running"
remote_sha="$(git ls-remote --heads origin "refs/heads/$EXPECTED_BRANCH" | awk '{print $1}')"
[[ "$remote_sha" == "$EXPECTED_SHA" ]] || fail "origin/$EXPECTED_BRANCH changed while CI was running"

printf 'Verified headSha=%s event=%s branch=%s run=%s attempt=%s\n' "$run_sha" "$run_event" "$run_branch" "$run_id" "$run_attempt"
printf 'Exact-CI gate passed: %s\n' "$run_url"
