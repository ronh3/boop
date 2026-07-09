# Phase 01: release-gates-and-state-contracts - Research

**Researched:** 2026-07-09
**Domain:** Mudlet/Muddler release gates, GitHub Actions CI, Lua/Busted state-contract tests
**Confidence:** HIGH for repo-local gate design; MEDIUM for external CI/test framework documentation

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
## Implementation Decisions

### Gate Strictness
- **D-01:** All deterministic gates added in Phase 1 should block CI when they fail.
- **D-02:** Deterministic gates include version synchronization, JSON validity, manifest parity, and state-contract regression checks.
- **D-03:** Phase 1 gates must establish a passing baseline on the current codebase. Known defects that require behavior changes should be documented and left for the appropriate later phase, not introduced as permanently failing CI in Phase 1.
- **D-04:** The same checks should be reusable locally, not only embedded in GitHub Actions. Prefer local scripts or test commands that CI calls directly.
- **D-05:** Phase 1 should keep CI dependency-risk cleanup minimal. Broad pinning of Muddler, test-in-Mudlet, actions, or LuaRocks dependencies is out of scope unless it is directly necessary for the new deterministic gates or is a low-risk supporting cleanup.

### the agent's Discretion
- The planner may choose the exact script names, test file names, and CI step placement, provided the checks are deterministic, pass on the current codebase, and can be run locally.
- The planner may decide whether a specific gate is best implemented as shell, Lua/Busted, or a small helper script, based on the existing test/build patterns.
- The planner may leave known behavior defects as documented follow-up evidence for later phases when making a Phase 1 gate pass would otherwise require behavior fixes.

### Deferred Ideas (OUT OF SCOPE)
## Deferred Ideas

None — discussion stayed within Phase 1 scope.
</user_constraints>

## Summary

Phase 01 should add a reusable local release-gate entrypoint, then call that same entrypoint from `.github/workflows/main.yml` before Muddler build/test steps. [VERIFIED: codebase grep] GitHub Actions `run` steps execute shell commands as runner processes, and the documented Bash shell behavior makes non-zero script exits suitable blocking gates when `continue-on-error` is not used. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] The current workflow has no `continue-on-error` gate bypasses and already uses shell steps with `set -euo pipefail` in several places. [VERIFIED: codebase grep]

The static release gates should cover REL-01 and REL-02 with a structured parser, not grep-only checks. [VERIFIED: codebase grep] Current version fields are synchronized at `0.1.327` across `mfile.version`, `mfile.title`, `src/scripts/boop/boop_init.lua` `boop.version`, and `CODEX.md` checkpoint. [VERIFIED: codebase grep] Current JSON files under `src/scripts`, `src/aliases`, and `src/triggers` parse successfully with `jq`, but a manifest parity dry-run found baseline drift: `src/aliases/boop/Targeting/Boop_IH.lua` is orphaned, and two `Weaponmastery Two-Handed` shield trigger names map to non-existent hyphenated filenames while underscore-named Lua files exist. [VERIFIED: codebase grep]

For REL-04, do not make future Phase 2 state repairs a Phase 1 blocker. [VERIFIED: CONTEXT.md] The current source still contains flat state reads/writes in `boop_events.lua`, `boop_walk.lua`, and `boop_attacks.lua` for room, pull, walk, diag, flee, gold, and target paths. [VERIFIED: codebase grep] Use two complementary gates: passing Busted tests for owned-domain contracts that are already stable, plus a static known-drift allowlist that fails when new flat-state access is introduced or when an existing allowlisted item changes without review. [VERIFIED: codebase grep]

**Primary recommendation:** Add `tools/check_release_gates.py` as the deterministic local static gate, call it from a CI step before Muddler, fix or explicitly account for the current manifest parity drift, and add a passing state-contract baseline that prevents new flat-state drift without requiring Phase 2 behavior fixes.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|--------------|----------------|-----------|
| Version synchronization gate | CI / Tooling | Package metadata | The gate compares committed metadata in `mfile`, `boop_init.lua`, and `CODEX.md`; CI should fail before build artifacts are produced. [VERIFIED: codebase grep] |
| JSON validity gate | CI / Tooling | Muddler source manifests | Source JSON lives under `src/**` and `mfile`; validating it before Muddler gives faster failures than waiting for package import. [VERIFIED: codebase grep] |
| Manifest/file parity gate | CI / Tooling | Muddler package source | Muddler consumes Lua and JSON source to produce an `.mpackage`, so package membership drift belongs in a source-level gate. [CITED: https://github.com/demonnic/muddler] |
| State-contract regression checks | Test layer | Runtime state modules | Owned runtime domains are defined in `boop_runtime.lua`; focused Busted specs and static drift checks should guard those contracts before behavior changes land. [VERIFIED: codebase grep] |
| CI integration | GitHub Actions | Local scripts | Context requires local reusability; CI should call the local checker rather than duplicate gate logic inline. [VERIFIED: CONTEXT.md] |
| Dependency-risk cleanup | CI config | Planning documentation | Broad pinning is explicitly deferred unless directly required for deterministic gates or low-risk supporting cleanup. [VERIFIED: CONTEXT.md] |

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| REL-01 | CI fails when `mfile.version`, `mfile.title`, `src/scripts/boop/boop_init.lua` `boop.version`, or the `CODEX.md` session checkpoint disagree. | Version fields and checkpoint are currently synchronized at `0.1.327`; implement a parser-based gate over all four values and call it from CI. [VERIFIED: codebase grep] |
| REL-02 | CI validates source JSON and Muddler manifest/file parity for scripts, aliases, and triggers without auto-sorting runtime-sensitive manifests. | `jq` currently validates source JSON; manifest parity dry-run found current drift that must be fixed or allowlisted before the gate can block CI. [VERIFIED: codebase grep] |
| REL-04 | High-risk runtime paths have focused regression tests before behavior changes land. | Existing runtime domains and Busted helper patterns support owned-state tests; current flat-state drift means Phase 1 should baseline and prevent new drift, not force all future behavior repairs. [VERIFIED: codebase grep] |
</phase_requirements>

## Project Constraints (from AGENTS.md)

- Read `README.md` and `DESIGN.md` before changes; both were read for this research. [VERIFIED: codebase grep]
- Read `CODEX.md` for workflow guidance; it was read for this research. [VERIFIED: codebase grep]
- Read `UIDESIGN.md` for UI/UX work; this phase is CI/test tooling, so UI work is not in scope. [VERIFIED: AGENTS.md]
- Check version fields before changes; current version fields are synchronized at `0.1.327`. [VERIFIED: codebase grep]
- On every commit and push, keep `mfile.version`, `mfile.title`, `src/scripts/boop/boop_init.lua` `boop.version`, and the `CODEX.md` checkpoint synchronized. [VERIFIED: AGENTS.md]
- Work only under `src/` for package content and never edit built artifacts; Phase 1 tooling may use `tools/`, `tests/`, `.github/workflows/`, and `.planning/` without editing generated `build/` output. [VERIFIED: AGENTS.md]
- Keep docs and command help in sync with command-surface changes; Phase 1 should avoid command-surface changes. [VERIFIED: AGENTS.md]
- Prefer polish, consistency, operator clarity, and stability over feature expansion; Phase 1 should not expand runtime behavior. [VERIFIED: AGENTS.md]

## Standard Stack

### Core

| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Python standard library (`json`, `pathlib`, `re`) | Local `python3` 3.14.6; CI already invokes `python` inline | Implement deterministic version, JSON, and manifest parity checks without new packages. | Structured JSON parsing avoids brittle shell text parsing and requires no new dependency. [VERIFIED: shell probe] |
| Bash | Local 5.3.15; GitHub-hosted runner shell documented as Bash on Linux/macOS | Thin local wrapper and CI `run` step execution. | Existing workflow already uses shell steps; Bash non-zero exits can block CI. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] |
| GitHub Actions | Hosted workflow, no repo-pinned version | CI gate integration, Muddler build, in-Mudlet Busted test run, artifact upload. | Existing `.github/workflows/main.yml` is the release automation surface. [VERIFIED: codebase grep] |
| Muddler | Local `muddle` wrapper uses Docker image `demonnic/muddler`; CI uses `demonnic/build-with-muddler@main` | Build Mudlet `.mpackage` from `mfile` and `src/**` manifests. | Muddler is the existing package builder and its docs describe transforming Lua/JSON project files into an `.mpackage`. [CITED: https://github.com/demonnic/muddler] |
| Busted | Local 2.3.0; CI installs `busted` through LuaRocks | Focused Lua/Mudlet state-contract specs. | Existing test suite is Busted-in-Mudlet; official docs support Lua >= 5.1, assertions, setup hooks, stubs, and mocks. [CITED: https://lunarmodules.github.io/busted/] |

### Supporting

| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `jq` | Local 1.8.1; CI already uses `jq` | Existing metadata reads and quick JSON smoke checks. | Keep for existing workflow steps; the new static gate can use Python for richer manifest recursion. [VERIFIED: shell probe] |
| Docker | Local 29.6.1 | Runs local `muddle` wrapper. | Needed for local package builds because `/usr/local/bin/muddle` wraps `docker run demonnic/muddler`. [VERIFIED: shell probe] |
| `tests/support/boop_test_helper.lua` | Repo-local | Reset and seed Mudlet/Busted state. | Use for any REL-04 Busted spec additions. [VERIFIED: codebase grep] |
| `tools/sort_manifests.sh` | Repo-local | Manual manifest sorting helper for safe manifests. | Use only for display-order manifests; do not use it as the parity gate and do not sort `src/scripts/boop/scripts.json`. [VERIFIED: codebase grep] |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Python static checker | Bash plus `jq` only | Shell plus `jq` can validate JSON and simple fields, but recursive manifest/file parity is clearer and safer with a structured language. [VERIFIED: codebase grep] |
| Local checker called by CI | Inline-only GitHub Actions commands | Inline-only checks would violate the local reusability decision and duplicate logic across local/CI paths. [VERIFIED: CONTEXT.md] |
| Manifest parity gate | Auto-sorting all manifests | Sorting would hide ordering intent and can break `src/scripts/boop/scripts.json`, which is documented as load-order sensitive. [VERIFIED: codebase grep] |
| Busted state-contract tests | New Lua test framework | Existing CI already runs Busted in a real Mudlet profile; a new test framework would add dependency risk without Phase 1 value. [VERIFIED: codebase grep] |

**Installation:**

```bash
# No new external package installs are recommended for Phase 01.
```

**Version verification:**

| Item | Current Observed Value | Verification |
|------|------------------------|--------------|
| `mfile.version` | `0.1.327` | `jq -r '.version' mfile` equivalent via file read. [VERIFIED: codebase grep] |
| `mfile.title` | `boop Hunter 0.1.327` | Parsed from `mfile`. [VERIFIED: codebase grep] |
| `boop.version` | `0.1.327` | Parsed from `src/scripts/boop/boop_init.lua`. [VERIFIED: codebase grep] |
| `CODEX.md` checkpoint | `0.1.327` | Parsed from `CODEX.md`. [VERIFIED: codebase grep] |
| `jq` | 1.8.1 | Local shell probe. [VERIFIED: shell probe] |
| `busted` | 2.3.0 local | Local shell probe. [VERIFIED: shell probe] |

## Package Legitimacy Audit

Phase 01 should not install new external packages. [VERIFIED: CONTEXT.md] The existing workflow already installs `busted` and `mediator_lua`, but dependency-risk cleanup is explicitly minimal in this phase unless directly needed for the deterministic gates. [VERIFIED: codebase grep]

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| none added | n/a | n/a | n/a | n/a | n/a | No package legitimacy gate required because no new package install is recommended. [VERIFIED: CONTEXT.md] |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Architecture Patterns

### System Architecture Diagram

```text
+---------------------+
| Maintainer / CI    |
| local preflight or |
| GitHub Actions     |
+----------+----------+
           |
           v
+-----------------------------+
| tools/check_release_gates.py |
| - parse version sources      |
| - parse source JSON          |
| - traverse manifests         |
| - audit flat-state drift     |
+--------------+--------------+
               |
       pass    |    fail
               v
+-----------------------------+        +----------------------+
| Muddler build step           |        | Non-zero exit blocks |
| existing CI builder          |        | CI and local preflight |
+--------------+--------------+        +----------------------+
               |
               v
+-----------------------------+
| Mudlet AppImage test profile |
| imports built package        |
| runs Busted specs            |
+--------------+--------------+
               |
               v
+-----------------------------+
| Artifact upload / PR comment |
+-----------------------------+
```

### Recommended Project Structure

```text
tools/
├── check_release_gates.py      # Static deterministic gates for REL-01 and REL-02 plus state-drift allowlist
└── sort_manifests.sh           # Existing manual sorter; not the blocking parity gate
tests/
├── boop_state_contract_spec.lua # Focused passing REL-04 owned-state contracts, if not extending existing specs
└── support/
    └── boop_test_helper.lua
.github/workflows/
└── main.yml                    # Calls the local static gate before Muddler and keeps Busted run blocking
```

### Pattern 1: Local Static Gate Called By CI

**What:** Put deterministic static checks in one local script, then call it from CI with a normal `run` step. [VERIFIED: CONTEXT.md]

**When to use:** Use for version sync, JSON parsing, manifest/file parity, and static state-drift allowlist checks. [VERIFIED: codebase grep]

**Example:**

```yaml
# Source: GitHub Actions workflow syntax docs and existing .github/workflows/main.yml
- name: Release gates
  run: python3 tools/check_release_gates.py
```

### Pattern 2: Structured Version Contract

**What:** Parse all version sources and compare exact values. [VERIFIED: codebase grep]

**When to use:** Use for REL-01 before Muddler reads `mfile` for artifact naming. [VERIFIED: codebase grep]

**Example:**

```python
# Source: repo-local mfile, boop_init.lua, CODEX.md
expected_title = f"boop Hunter {mfile_version}"
assert mfile_title == expected_title
assert boop_init_version == mfile_version
assert codex_checkpoint_version == mfile_version
```

### Pattern 3: Recursive Manifest/File Parity

**What:** Treat each manifest entry as a source membership contract: folder entries must have child directories and child manifests; leaf entries must map to a Lua file by explicit `script` or by Muddler's name-to-filename convention. [VERIFIED: codebase grep]

**When to use:** Use for REL-02 over `src/scripts`, `src/aliases`, and `src/triggers`. [VERIFIED: codebase grep]

**Example:**

```python
# Source: CODEX.md documents names with spaces map to underscores.
stem = entry.get("script") or entry["name"].replace(" ", "_")
lua_path = manifest_dir / f"{stem}.lua"
```

### Pattern 4: State-Contract Baseline Without Behavior Repair

**What:** Combine passing Busted contracts for stable owned-domain behavior with a static allowlist for known flat-state drift. [VERIFIED: CONTEXT.md]

**When to use:** Use for REL-04 until Phase 2 migrates remaining flat state paths. [VERIFIED: codebase grep]

**Example:**

```lua
-- Source: tests/support/boop_test_helper.lua and boop_runtime.lua
it("initializes owned runtime domains", function()
  helper.reset()
  local state = boop.runtime.state()
  assert.is_table(state.combat)
  assert.is_table(state.targeting)
  assert.is_table(state.gold)
  assert.is_table(state.queue)
  assert.is_table(state.walk)
  assert.is_table(state.diag)
end)
```

### Anti-Patterns to Avoid

- **CI-only gate logic:** Duplicating checks inline in `.github/workflows/main.yml` violates the local reusability decision. [VERIFIED: CONTEXT.md]
- **Grep-only JSON parsing:** JSON validity and manifest traversal need structured parsing to avoid false positives and quoting bugs. [VERIFIED: codebase grep]
- **Auto-sorting `src/scripts/boop/scripts.json`:** That manifest is load-order sensitive and intentionally skipped by `tools/sort_manifests.sh`. [VERIFIED: codebase grep]
- **Future behavior tests as Phase 1 blockers:** State-contract tests must pass on current code; future behavior fixes belong to later phases. [VERIFIED: CONTEXT.md]
- **Broad CI dependency cleanup:** Pinning all third-party actions and LuaRocks dependencies is out of scope unless directly required for the deterministic gates. [VERIFIED: CONTEXT.md]

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON validity | Regex or line-oriented JSON checks | Python `json` or existing `jq` | Source manifests contain escaped regex strings; structured parsers avoid broken quoting assumptions. [VERIFIED: codebase grep] |
| Manifest parity | Manual spot checks | Recursive source traversal script | The repo has 118 JSON files and 641 Lua files under package source paths, so manual review will miss drift. [VERIFIED: shell probe] |
| State-contract baseline | One giant behavior test that asserts Phase 2 outcomes | Small Busted specs plus static known-drift allowlist | The phase must pass on current code and prevent new drift without forcing known behavior repairs. [VERIFIED: CONTEXT.md] |
| CI gate behavior | `continue-on-error` warnings | Normal non-zero exit from local script | Phase decisions require deterministic gates to block CI. [VERIFIED: CONTEXT.md] |
| Manifest order safety | Auto-sort every manifest | Keep `tools/sort_manifests.sh` exclusions | `src/scripts/boop/scripts.json` encodes runtime load order. [VERIFIED: codebase grep] |

**Key insight:** Phase 01 is a release confidence phase, not a runtime repair phase. The best gates are strict about metadata and package membership, but conservative about state-contract drift that already exists. [VERIFIED: CONTEXT.md]

## Common Pitfalls

### Pitfall 1: Making Current Manifest Drift a Permanent Exception

**What goes wrong:** REL-02 becomes noisy or weak because current mismatches are broadly allowlisted. [VERIFIED: codebase grep]

**Why it happens:** A parity dry-run currently finds `Boop_IH.lua` orphaned and two `Weaponmastery Two-Handed` shield trigger filename mismatches. [VERIFIED: codebase grep]

**How to avoid:** Fix the small manifest/file mismatches in Phase 1 before enabling the blocking gate, unless a mismatch is intentionally documented as non-package source. [VERIFIED: codebase grep]

**Warning signs:** The parity checker includes broad glob ignores such as "ignore all unreferenced Lua" or "ignore trigger filename punctuation." [VERIFIED: codebase grep]

### Pitfall 2: Forgetting the `CODEX.md` Version Checkpoint

**What goes wrong:** CI enforces the package fields but misses the session checkpoint required by REL-01. [VERIFIED: REQUIREMENTS.md]

**Why it happens:** Existing CI reads only `mfile` for package/version metadata. [VERIFIED: codebase grep]

**How to avoid:** Parse `CODEX.md` `Current synchronized package version:` and compare it to `mfile.version`, `mfile.title`, and `boop.version`. [VERIFIED: codebase grep]

**Warning signs:** The checker reports only three version fields. [VERIFIED: AGENTS.md]

### Pitfall 3: Turning Known State Bugs Into Phase 1 Red CI

**What goes wrong:** The phase lands failing tests for room, pull, walk, flee, or gold behavior that later phases are supposed to repair. [VERIFIED: CONTEXT.md]

**Why it happens:** Existing source still has flat-state access in high-risk runtime paths. [VERIFIED: codebase grep]

**How to avoid:** Use a state-drift allowlist that freezes current flat access, then add green Busted contracts for owned domains that already behave correctly. [VERIFIED: CONTEXT.md]

**Warning signs:** A Phase 1 test expects `boop.onRoomInfo()` or `boop.walk.start()` to be fully migrated before Phase 2. [VERIFIED: codebase grep]

### Pitfall 4: Running Static Gates After Expensive CI Steps

**What goes wrong:** Version or manifest failures are discovered only after Muddler, dependency install, or Mudlet AppImage setup. [VERIFIED: codebase grep]

**Why it happens:** Existing workflow starts with metadata read and then builds before any new static gate. [VERIFIED: codebase grep]

**How to avoid:** Put the static release-gate step immediately after checkout and before Muddler. [VERIFIED: codebase grep]

**Warning signs:** The release-gate step appears after `Run Busted tests in Mudlet`. [VERIFIED: codebase grep]

### Pitfall 5: Relying on Local Lua Version for Gate Scripts

**What goes wrong:** A local Lua-based gate passes on the developer machine but does not match CI's Lua 5.1.5 or Mudlet Lua environment. [VERIFIED: shell probe]

**Why it happens:** Local `lua` is 5.5.0, while CI installs Lua 5.1.5 for tests. [VERIFIED: shell probe]

**How to avoid:** Use Python stdlib or shell/jq for static gates, and use Busted inside Mudlet for runtime contracts. [VERIFIED: codebase grep]

**Warning signs:** A static checker uses Lua 5.4/5.5 syntax or requires non-Mudlet Lua modules. [VERIFIED: shell probe]

## Code Examples

### Version Gate Shape

```python
# Source: repo-local version fields
errors = []
if mfile["title"] != f"boop Hunter {mfile['version']}":
  errors.append("mfile.title must be boop Hunter <mfile.version>")
if boop_init_version != mfile["version"]:
  errors.append("boop.version must match mfile.version")
if codex_checkpoint_version != mfile["version"]:
  errors.append("CODEX.md checkpoint must match mfile.version")
if errors:
  raise SystemExit("\n".join(errors))
```

### Manifest Parity Shape

```python
# Source: repo-local manifest convention
def entry_stem(entry):
  script = entry.get("script") or ""
  if script.strip():
    return script.strip()
  return entry["name"].replace(" ", "_")
```

### State Drift Allowlist Shape

```python
# Source: rg audit of current flat state reads/writes
KNOWN_FLAT_STATE_ACCESS = {
  "src/scripts/boop/boop_events.lua:vars.room",
  "src/scripts/boop/boop_events.lua:vars.pullState",
  "src/scripts/boop/boop_walk.lua:state.walkActive",
  "src/scripts/boop/boop_walk.lua:state.diagHold",
}
```

### Busted Contract Shape

```lua
-- Source: existing tests/boop_runtime_spec.lua pattern
local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop state contracts", function()
  before_each(function()
    helper.reset()
  end)

  it("provides the owned domains future behavior tests must use", function()
    local state = boop.runtime.state()
    assert.is_table(state.combat)
    assert.is_table(state.targeting)
    assert.is_table(state.gold)
    assert.is_table(state.queue)
    assert.is_table(state.walk)
    assert.is_table(state.diag)
    assert.is_table(state.inventory)
    assert.is_table(state.gag)
  end)
end)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Policy-only version sync | Blocking version gate over `mfile`, `boop_init.lua`, and `CODEX.md` | Phase 01 planned | Prevents runtime/package/checkpoint version drift before artifact upload. [VERIFIED: REQUIREMENTS.md] |
| Muddler failure as manifest feedback | Source manifest parity check before Muddler | Phase 01 planned | Finds missing/orphaned Lua files quickly and locally. [VERIFIED: codebase grep] |
| Broad future-state assertions | Passing baseline plus known-drift allowlist | Phase 01 planned | Keeps CI green now while preventing new state-contract drift. [VERIFIED: CONTEXT.md] |
| CI-only commands | Local script invoked by CI | Phase 01 planned | Maintainers can reproduce failures before push. [VERIFIED: CONTEXT.md] |

**Deprecated/outdated:**
- Treating version sync as a manual checklist is outdated for this milestone; REL-01 requires CI failure on mismatch. [VERIFIED: REQUIREMENTS.md]
- Treating manifest maintenance as only a sorting problem is incomplete; REL-02 requires file membership parity and must not sort runtime-sensitive manifests. [VERIFIED: REQUIREMENTS.md]

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| n/a | No `[ASSUMED]` claims are used in this research. | n/a | n/a |

**If this table is empty:** All claims in this research were verified or cited; no user confirmation needed.

## Open Questions

1. **Should the existing manifest drift be fixed or allowlisted?**
   - What we know: The dry-run found one orphan alias file and two trigger filename mismatches. [VERIFIED: codebase grep]
   - What's unclear: Whether `Boop_IH.lua` is intentionally retained as a duplicate source file or should be deleted/registered. [VERIFIED: codebase grep]
   - Recommendation: Fix the manifest/file drift in Phase 1 before enabling REL-02; only use allowlists for intentionally non-package source, not accidental package membership drift. [VERIFIED: codebase grep]

2. **What is the current in-Mudlet suite status on CI?**
   - What we know: The local machine lacks `/tmp/Mudlet.AppImage`, while CI downloads/caches Mudlet and runs Busted in the `GithubTests` profile. [VERIFIED: shell probe]
   - What's unclear: Whether the latest remote CI run is already red because local Mudlet execution was not run during research. [VERIFIED: shell probe]
   - Recommendation: Planner should schedule a Wave 0 verification step to run or inspect the existing CI/Busted baseline before adding new blocking state-contract tests. [VERIFIED: codebase grep]

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|-------------|-----------|---------|----------|
| `python3` | Static release gate | yes | 3.14.6 local | Use existing `jq` plus shell only for simple checks; keep manifest recursion structured. [VERIFIED: shell probe] |
| `bash` | Local wrapper and CI run steps | yes | 5.3.15 local | `sh` can run simple wrappers, but Bash is already the workflow default on Ubuntu. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax] |
| `jq` | Existing metadata read and JSON validation | yes | 1.8.1 local | Python `json` can replace new gate needs. [VERIFIED: shell probe] |
| `busted` | Local focused spec execution | yes | 2.3.0 local | Full authoritative run remains CI's Mudlet profile. [VERIFIED: shell probe] |
| `lua` | Local Lua scripts | yes | 5.5.0 local | Avoid for static gates because CI test Lua is 5.1.5. [VERIFIED: shell probe] |
| `luarocks` | CI test dependency installs | yes | 3.13.0 local | Existing CI installs dependencies. [VERIFIED: shell probe] |
| `muddle` | Local package build | yes | wrapper, version not reported | CI uses `demonnic/build-with-muddler@main`; local wrapper requires Docker. [VERIFIED: shell probe] |
| Docker | Local `muddle` wrapper | yes | 29.6.1 | Use CI build if Docker unavailable. [VERIFIED: shell probe] |
| Mudlet AppImage | Local full in-Mudlet suite | no | not present at `/tmp/Mudlet.AppImage` | CI downloads/caches `Mudlet-4.20.1-linux-x64.AppImage.tar`. [VERIFIED: codebase grep] |

**Missing dependencies with no fallback:**
- None for static Phase 1 gates. [VERIFIED: shell probe]

**Missing dependencies with fallback:**
- Local Mudlet AppImage is missing; use CI for full in-Mudlet Busted execution or run the workflow setup locally. [VERIFIED: shell probe]

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Busted 2.3.0 local; CI installs `busted` and runs inside Mudlet. [VERIFIED: shell probe] |
| Config file | none detected; CI controls runner through environment variables. [VERIFIED: codebase grep] |
| Quick run command | `python3 tools/check_release_gates.py` once added. [VERIFIED: CONTEXT.md] |
| Full suite command | Existing CI command imports `build/boop Hunter.mpackage` into Mudlet and runs Busted with `AUTORUN_BUSTED_TESTS=true TESTS_DIRECTORY=$PWD/tests QUIT_MUDLET_AFTER_TESTS=true PRETEST_PACKAGE=$PWD/build/boop Hunter.mpackage`. [VERIFIED: codebase grep] |

### Phase Requirements -> Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|--------------|
| REL-01 | Version fields and CODEX checkpoint mismatch fails before build | static unit/gate | `python3 tools/check_release_gates.py --check versions` or full gate command | no, Wave 0 add `tools/check_release_gates.py`. [VERIFIED: codebase grep] |
| REL-02 | Source JSON invalidity or manifest/file drift fails before build | static unit/gate | `python3 tools/check_release_gates.py --check manifests` or full gate command | no, Wave 0 add `tools/check_release_gates.py`; current dry-run found drift. [VERIFIED: codebase grep] |
| REL-04 | New high-risk flat-state drift fails; stable owned domains remain covered | Busted plus static gate | `python3 tools/check_release_gates.py --check state-drift` and selected Busted spec in CI | partial, existing `tests/boop_runtime_spec.lua` covers domain initialization; add focused state-contract baseline or extend existing specs. [VERIFIED: codebase grep] |

### Sampling Rate

- **Per task commit:** Run `python3 tools/check_release_gates.py` after the checker exists. [VERIFIED: CONTEXT.md]
- **Per wave merge:** Run the full GitHub Actions-equivalent path, including Muddler build and in-Mudlet Busted suite. [VERIFIED: codebase grep]
- **Phase gate:** Static release gates and current Busted suite must be green before `$gsd-verify-work`. [VERIFIED: CONTEXT.md]

### Wave 0 Gaps

- [ ] `tools/check_release_gates.py` - implements REL-01, REL-02, and static state-drift allowlist. [VERIFIED: codebase grep]
- [ ] `.github/workflows/main.yml` - call the local static gate immediately after checkout. [VERIFIED: codebase grep]
- [ ] `src/aliases/boop/Targeting/Boop_IH.lua` handling - delete, register, or document as non-package source before enabling REL-02. [VERIFIED: codebase grep]
- [ ] `src/triggers/boop/Shield/Weaponmastery_Two_Handed/triggers.json` or filenames - align two `Two-Handed` manifest entries with actual underscore filenames before enabling REL-02. [VERIFIED: codebase grep]
- [ ] `tests/boop_state_contract_spec.lua` or extensions to `tests/boop_runtime_spec.lua` - add green REL-04 contracts for owned domains and known-drift baseline. [VERIFIED: codebase grep]

## Security Domain

Security enforcement is enabled in `.planning/config.json`, with ASVS level 1 configured. [VERIFIED: codebase grep] OWASP ASVS provides a standard for verifying web application security controls; this local Mudlet package is not a web app, so only the categories relevant to CI/tooling and input validation apply directly. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|------------------|
| V2 Authentication | no for package runtime; limited CI token relevance | No runtime auth is present; CI should keep `GITHUB_TOKEN` permissions least-privilege where low-risk. [CITED: https://docs.github.com/en/actions/tutorials/authenticate-with-github_token] |
| V3 Session Management | no | No web sessions or remote user sessions exist in this phase. [VERIFIED: codebase grep] |
| V4 Access Control | yes for CI permissions | Replace `permissions: write-all` only if low-risk and compatible with artifact upload and PR comments; otherwise document for later dependency-risk cleanup. [VERIFIED: codebase grep] |
| V5 Input Validation | yes | Parse JSON with structured parsers, normalize manifest paths, reject path traversal outside `src/scripts`, `src/aliases`, and `src/triggers`. [VERIFIED: codebase grep] |
| V6 Cryptography | no | No cryptography is introduced; do not add checksums or signing policy in Phase 1 unless directly required. [VERIFIED: CONTEXT.md] |

### Known Threat Patterns for CI / Static Gate Tooling

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Over-privileged CI token | Elevation of privilege | GitHub recommends granting the least required `GITHUB_TOKEN` permissions; Phase 1 may reduce only if low-risk for existing artifact/comment behavior. [CITED: https://docs.github.com/en/actions/tutorials/authenticate-with-github_token] |
| Path traversal in manifest checker | Tampering | Resolve paths and assert every checked leaf stays under the expected source root before reporting parity. [VERIFIED: codebase grep] |
| False-green gate via `continue-on-error` | Repudiation | Do not set `continue-on-error` on deterministic release gates. [VERIFIED: CONTEXT.md] |
| Network-dependent static gate | Denial of service | Keep `tools/check_release_gates.py` offline and source-only; use existing CI network steps only after static gates pass. [VERIFIED: codebase grep] |

## Sources

### Primary (HIGH confidence)

- `AGENTS.md` - startup, versioning, and workflow constraints. [VERIFIED: codebase grep]
- `CODEX.md` - CI, version sync, Muddler, and current checkpoint guidance. [VERIFIED: codebase grep]
- `.planning/phases/01-release-gates-and-state-contracts/01-CONTEXT.md` - locked Phase 1 decisions. [VERIFIED: codebase grep]
- `.planning/REQUIREMENTS.md` - REL-01, REL-02, REL-04. [VERIFIED: codebase grep]
- `.planning/ROADMAP.md` - Phase 1 goal and success criteria. [VERIFIED: codebase grep]
- `.github/workflows/main.yml` - current CI build/test pipeline. [VERIFIED: codebase grep]
- `src/scripts/boop/boop_runtime.lua`, `boop_events.lua`, `boop_walk.lua`, `boop_init.lua` - state domains, state drift, and version source. [VERIFIED: codebase grep]
- `tests/README.md`, `tests/support/boop_test_helper.lua`, `tests/boop_runtime_spec.lua` - existing test patterns. [VERIFIED: codebase grep]

### Secondary (MEDIUM confidence)

- GitHub Actions workflow syntax - `run` steps and shell behavior. [CITED: https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax]
- GitHub Actions `GITHUB_TOKEN` permissions guidance. [CITED: https://docs.github.com/en/actions/tutorials/authenticate-with-github_token]
- Busted official docs - Lua version support and test/assertion patterns. [CITED: https://lunarmodules.github.io/busted/]
- Muddler repository docs - Lua/JSON project files to Mudlet `.mpackage`. [CITED: https://github.com/demonnic/muddler]
- Mudlet package manager docs - package contents and `.mpackage` concept. [CITED: https://wiki.mudlet.org/w/Manual%3APackage_Manager]
- OWASP ASVS project page - security verification framing. [CITED: https://owasp.org/www-project-application-security-verification-standard/]

### Tertiary (LOW confidence)

- None used.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Existing repo stack and local tool versions were read/probed; external docs were used only for CI/Busted/Muddler framing. [VERIFIED: shell probe]
- Architecture: HIGH - Gate placement and state-contract boundaries are based on repo files and locked context. [VERIFIED: codebase grep]
- Pitfalls: HIGH - Manifest drift, version sync gap, and flat-state drift were directly observed in source and workflow files. [VERIFIED: codebase grep]

**Research date:** 2026-07-09
**Valid until:** 2026-08-08 for repo-local gate design; re-check external GitHub Actions/Busted/Muddler details if CI dependencies are changed.
