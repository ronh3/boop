# Phase 01: release-gates-and-state-contracts - Pattern Map

**Mapped:** 2026-07-09
**Files analyzed:** 13
**Analogs found:** 13 / 13

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `tools/check_release_gates.py` | utility | batch, file-I/O, transform | `tools/sort_manifests.sh` + `.github/workflows/main.yml` inline Python | role-match |
| `.github/workflows/main.yml` | config | batch, CI orchestration | `.github/workflows/main.yml` | exact |
| `tests/boop_state_contract_spec.lua` or `tests/boop_runtime_spec.lua` | test | event-driven, state-contract | `tests/boop_runtime_spec.lua` | exact |
| `tests/boop_event_transitions_spec.lua` | test | event-driven, state-contract | `tests/boop_event_transitions_spec.lua` | exact |
| `tests/README.md` | documentation | batch inventory | `tests/README.md` | exact |
| `src/aliases/boop/Targeting/Boop_IH.lua` | alias adapter | request-response | `src/aliases/boop/Targeting/IH.lua` | exact |
| `src/aliases/boop/Targeting/aliases.json` | config | request-response manifest | `src/aliases/boop/Targeting/aliases.json` | exact |
| `src/triggers/boop/Shield/Weaponmastery_Two_Handed/triggers.json` | config | event-driven manifest | `src/triggers/boop/Shield/Weaponmastery_Two_Handed/triggers.json` | exact |
| `src/triggers/boop/Shield/Weaponmastery_Two_Handed/Weaponmastery_Two_Handed_Carve.lua` | trigger adapter | event-driven | same folder shield trigger scripts | exact |
| `src/triggers/boop/Shield/Weaponmastery_Two_Handed/Weaponmastery_Two_Handed_Slaughter.lua` | trigger adapter | event-driven | same folder shield trigger scripts | exact |
| `mfile` | config | file-I/O metadata | `mfile` | exact |
| `src/scripts/boop/boop_init.lua` | config/bootstrap | request-response, event-driven init | `src/scripts/boop/boop_init.lua` | exact |
| `CODEX.md` | documentation/config | file-I/O checkpoint | `CODEX.md` | exact |

## Pattern Assignments

### `tools/check_release_gates.py` (utility, batch/file-I/O)

**Analog:** `tools/sort_manifests.sh` for local root discovery and deterministic source scanning. There is no existing repo Python file; use Python stdlib as recommended in research.

**Local script entry/root pattern** (`tools/sort_manifests.sh` lines 1-12):
```sh
#!/usr/bin/env sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

sort_manifest() {
  file="$1"
  tmp="${file}.tmp"
  jq 'sort_by((.name // "")|ascii_downcase)' "$file" > "$tmp"
  mv "$tmp" "$file"
  echo "sorted: $file"
}
```

**Manifest scope and load-order exclusion** (`tools/sort_manifests.sh` lines 14-30):
```sh
# Safe to sort for display order.
sort_manifest "$ROOT/src/aliases/aliases.json"
find "$ROOT/src/aliases/boop" -name aliases.json -type f | sort | while IFS= read -r file; do
  sort_manifest "$file"
done

sort_manifest "$ROOT/src/triggers/triggers.json"
find "$ROOT/src/triggers/boop" -name triggers.json -type f | sort | while IFS= read -r file; do
  sort_manifest "$file"
done

sort_manifest "$ROOT/src/scripts/boop/attacks/scripts.json"

# Intentionally not sorted:
#   src/scripts/boop/scripts.json
# It is load-order sensitive (boop_init/boop_bootstrap/attack registry dependencies).
echo "skipped: $ROOT/src/scripts/boop/scripts.json (load-order sensitive)"
```

**Python stdlib file-read pattern** (`.github/workflows/main.yml` lines 129-141):
```python
from pathlib import Path

lines = Path("/tmp/mudlet.raw.log").read_text(errors="replace").splitlines()
i = 0
while i < len(lines):
    line = lines[i]
    if 'XMLimport::readUnknownElement(' in line and 'UNKNOWN Package Element name: "path".' in line:
        i += 4
        continue
    print(line)
    i += 1
```

**Version sources to parse**:

`mfile` lines 1-5:
```json
{
       "package": "boop Hunter",
      "title": "boop Hunter 0.1.328",
       "description": "Standalone hunting system for Achaea.",
      "version": "0.1.328",
```

`src/scripts/boop/boop_init.lua` lines 1-3:
```lua
boop = boop or {}

boop.version = boop.version or "0.1.328"
```

`CODEX.md` lines 94-98:
```markdown
## Session Checkpoint
- Branch to continue from: `codex/pre-1.0-hardening-pass`
- The branch tip moves with normal hardening commits; rely on git history rather than this file for the exact latest hash.
- Current synchronized package version: `0.1.328`
```

**Checker command surface from validation**:
```bash
python3 tools/check_release_gates.py
python3 tools/check_release_gates.py --check versions
python3 tools/check_release_gates.py --check manifests
python3 tools/check_release_gates.py --check state-drift
```

**Failure behavior pattern** (`.github/workflows/main.yml` lines 157-162):
```yaml
- name: Check Busted result
  run: |
    if [ -e /tmp/busted-tests-failed ]; then
      echo "Lua tests failed - see the Mudlet test step output above."
      exit 1
    fi
```

**State-drift baseline pattern:** inspect source for flat state accesses, but allow known baseline drift until later behavior phases. These current excerpts must not become Phase 1 red CI by themselves.

`src/scripts/boop/boop_walk.lua` lines 70-104:
```lua
local function blockedReason()
  local state = walkState()
  if not available() then
    return "demonnicAutoWalker is not installed"
  end
  if not state.walkActive then
    return "walk is not active"
  end
  ...
  if state.diagHold then
    return "diag pause is active"
  end
  if state.fleeing then
    return "flee is active"
  end
  if state.autoGrabGoldPending or state.goldGetPending or state.goldPutPending then
    return "loot handling is still pending"
  end
  if tostring(state.currentTargetId or "") ~= "" then
    return "current target still set"
  end
```

`src/scripts/boop/boop_attacks.lua` lines 35-55:
```lua
local state = planningState()
if state and state.combat and state.combat.spec ~= nil then
  return boop.util.trim(tostring(state.combat.spec or ""))
end
return boop.util.trim(tostring(state and state.spec or ""))
...
local state = planningState()
return boop.util.trim(tostring(state and state.currentTargetId or ""))
...
local state = planningState()
return state and state.targetShield or false
```

`src/scripts/boop/boop_events.lua` lines 632-697:
```lua
function boop.onRoomInfo()
  if not gmcp or not gmcp.Room or not gmcp.Room.Info then return end
  local vars = boop.state
  local previousRoom = vars.room

  if vars.room ~= gmcp.Room.Info.num then
    vars.movedRooms = true
    vars.lastRoom = vars.room
    boop.clearGoldQueueIntent()
    ...
    if not vars.fleeing then
      ...
            vars.lastRoomDir = dir
      ...
      vars.lastRoomDir = ""
      vars.fleeing = false
    end
  ...
  vars.room = gmcp.Room.Info.num
  ...
  local pull = vars.pullState
```

### `.github/workflows/main.yml` (config, CI batch)

**Analog:** same file.

**Placement pattern:** insert the local static release gate after checkout and before Muddler/build work. Current checkout and metadata section is lines 17-29:
```yaml
steps:
  - uses: actions/checkout@v4

  - name: Read package metadata
    id: pkg
    run: |
      VERSION=$(jq -r '.version' mfile)
      PACKAGE=$(jq -r '.package' mfile)
      echo "version=$VERSION" >> "$GITHUB_OUTPUT"
      echo "package=$PACKAGE" >> "$GITHUB_OUTPUT"

  - name: Muddle
    uses: demonnic/build-with-muddler@main
```

**Gate step to add:**
```yaml
  - name: Release gates
    run: python3 tools/check_release_gates.py
```

**Shell strictness pattern** (`.github/workflows/main.yml` lines 39-73):
```yaml
- name: Install test dependencies
  run: |
    set -euo pipefail
    ...
    luarocks install /tmp/mediator_lua-1.1.2-0.rockspec
    luarocks install busted
    sudo apt-get update
    sudo apt-get install -y libfuse2 libopengl0 libegl1
```

**Existing Busted CI gate remains blocking** (`.github/workflows/main.yml` lines 147-162):
```yaml
- name: Run Busted tests in Mudlet
  uses: GabrielBB/xvfb-action@v1.6
  with:
    run: bash /tmp/run-mudlet-tests.sh
  env:
    AUTORUN_BUSTED_TESTS: "true"
    TESTS_DIRECTORY: ${{ github.workspace }}/tests
    QUIT_MUDLET_AFTER_TESTS: "true"
    PRETEST_PACKAGE: ${{ github.workspace }}/build/boop Hunter.mpackage

- name: Check Busted result
  run: |
    if [ -e /tmp/busted-tests-failed ]; then
      echo "Lua tests failed - see the Mudlet test step output above."
      exit 1
    fi
```

### `tests/boop_state_contract_spec.lua` or `tests/boop_runtime_spec.lua` (test, state contract)

**Analog:** `tests/boop_runtime_spec.lua`, with supporting state source in `src/scripts/boop/boop_runtime.lua`.

**Spec setup and side-effect stubs** (`tests/boop_runtime_spec.lua` lines 1-21):
```lua
local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop runtime coordinator", function()
  local send_stub
  local timer_stub
  local kill_timer_stub

  before_each(function()
    helper.reset()
    timer_stub = stub(_G, "tempTimer", function(_, _)
      return 1
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
    send_stub = stub(_G, "send", function(_, _) end)
  end)

  after_each(function()
    if send_stub then send_stub:revert() send_stub = nil end
    if timer_stub then timer_stub:revert() timer_stub = nil end
    if kill_timer_stub then kill_timer_stub:revert() kill_timer_stub = nil end
  end)
```

**Owned state domains to assert** (`src/scripts/boop/boop_runtime.lua` lines 19-88):
```lua
local DOMAIN_DEFAULTS = {
  combat = {
    hunting = false,
    attacking = false,
    fleeing = false,
    class = "",
    spec = "",
    limiters = {
      hunting = false,
      targeting = false,
      setting = false,
      rage = false,
    },
    openerUsedByClass = {},
    pullState = false,
    lastComboTraceKey = nil,
    lastOpenerTraceKey = nil,
    lastRageDecision = nil,
  },
  targeting = {
    currentTargetId = "",
    targetName = "",
    targetShield = false,
    denizens = {},
    room = "",
    lastRoom = "",
    lastRoomDir = "",
    movedRooms = false,
    calledTargetId = "",
    calledTargetRoom = "",
    calledTargetBy = "",
    calledTargetAt = nil,
    incomingWhitelistShares = {},
    pendingWhitelistShare = nil,
  },
  gold = {
    dropped = false,
    shardsDropped = false,
    autoGrabPending = false,
    autoGrabPendingAt = nil,
    autoGrabTimer = nil,
    getPending = false,
    putPending = false,
    getRetries = 0,
    putRetries = 0,
    packTarget = "",
    pendingTimer = nil,
  },
  queue = {
    balanceReadyAt = nil,
    equilibriumReadyAt = nil,
    prequeueTimer = nil,
    prequeuedStandard = false,
    aliasAction = "",
    aliasDirty = true,
  },
  walk = {
    active = false,
    owned = false,
    roomSettled = false,
    moveQueued = false,
    arrivalRoom = "",
    arrivalTimer = nil,
  },
  diag = {
    hold = false,
    awaitPrompt = false,
    timeoutTimer = nil,
    label = "",
  },
```

**State initialization contract** (`src/scripts/boop/boop_runtime.lua` lines 124-145):
```lua
function boop.runtime.ensureState()
  boop.state = boop.state or {}
  local state = boop.state

  for domain, defaults in pairs(DOMAIN_DEFAULTS) do
    local current = rawget(state, domain)
    if type(current) ~= "table" then
      current = {}
      rawset(state, domain, current)
    end
    for key, default in pairs(defaults) do
      if current[key] == nil then
        current[key] = deepCopy(default)
      end
    end
  end
  return state
end

function boop.runtime.state()
  return boop.runtime.ensureState()
end
```

**Existing Busted state assertion pattern** (`tests/boop_runtime_spec.lua` lines 23-33):
```lua
it("maps legacy state aliases onto owned runtime domains", function()
  local state = boop.runtime.state()

  state.targeting.currentTargetId = "42"
  state.queue.prequeuedStandard = true
  boop.state.targeting.calledTargetId = "99"

  assert.are.equal("42", boop.state.targeting.currentTargetId)
  assert.is_true(boop.state.queue.prequeuedStandard)
  assert.are.equal("99", state.targeting.calledTargetId)
end)
```

**Prompt/effect contract pattern** (`tests/boop_runtime_spec.lua` lines 61-74):
```lua
it("releases diagnose hold from prompt effects", function()
  boop.state.diag.hold = true
  boop.state.diag.awaitPrompt = true
  boop.state.diag.label = "matic"
  boop.state.diag.timeoutTimer = 44

  local result = boop.runtime.step({ type = "prompt", context = boop.runtime.context() })
  boop.runtime.applyEffects(result, boop.runtime.context())

  assert.is_false(boop.state.diag.hold)
  assert.is_false(boop.state.diag.awaitPrompt)
  assert.are.equal("", boop.state.diag.label)
  assert.stub(kill_timer_stub).was_called_with(44)
end)
```

**Helper reset contract** (`tests/support/boop_test_helper.lua` lines 93-164):
```lua
function M.reset()
  assert(boop, "boop package is not loaded")
  local desiredGroups = boop.skills and boop.skills.desiredGroups or nil

  resetDb()

  gmcp = {
    Char = {
      Name = { name = "TestCharacter" },
      Status = { class = "", name = "TestCharacter" },
      Vitals = {
        hp = 5000,
        maxhp = 5000,
        bal = "1",
        eq = "1",
        charstats = {},
      },
      Skills = {},
      Items = {},
    },
    Room = {
      Info = {
        area = "UNKNOWN",
        num = 1,
        exits = {},
      },
    },
    IRE = {
      Target = {
        Set = "",
        Info = {
          id = "",
          hpperc = "100%",
        },
      },
      Display = {
        ButtonActions = {},
      },
    },
  }
  ...
  resetTableData(boop.state)
  boop.state.init()
  ...
  return boop
end
```

### `tests/boop_event_transitions_spec.lua` (test, event-driven state)

**Analog:** same file. Use this for event-driven Busted structure, but do not add Phase 2 behavior assertions that are currently known drift unless the implementation also repairs the behavior.

**Event spec setup pattern** (`tests/boop_event_transitions_spec.lua` lines 1-40):
```lua
local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop event-driven state transitions", function()
  local send_stub
  local send_gmcp_stub
  local timer_stub
  local kill_timer_stub
  local scheduled_callback

  before_each(function()
    helper.reset()
    scheduled_callback = nil

    send_stub = stub(_G, "send", function(_, _) end)
    send_gmcp_stub = stub(_G, "sendGMCP", function(_) end)
    timer_stub = stub(_G, "tempTimer", function(_, callback)
      scheduled_callback = callback
      return 99
    end)
    kill_timer_stub = stub(_G, "killTimer", function(_) end)
  end)

  after_each(function()
    if send_stub then
      send_stub:revert()
      send_stub = nil
    end
    ...
  end)
```

**Current room/gold transition assertion pattern** (`tests/boop_event_transitions_spec.lua` lines 125-154):
```lua
it("clears gold intent and remembers the return exit when the room changes", function()
  boop.state.targeting.room = 100
  boop.state.combat.fleeing = false
  boop.state.targeting.targetShield = { attempted = false, timer = 57 }
  boop.state.gold.getPending = true
  boop.state.gold.putPending = true
  boop.state.gold.getRetries = 1
  boop.state.gold.putRetries = 1
  boop.state.gold.packTarget = "pack"

  gmcp.Room.Info.num = 200
  gmcp.Room.Info.exits = {
    north = 100,
    south = 300,
  }

  boop.onRoomInfo()

  assert.is_true(boop.state.targeting.movedRooms)
  assert.are.equal(100, boop.state.targeting.lastRoom)
  assert.are.equal("north", boop.state.targeting.lastRoomDir)
  assert.are.equal(200, boop.state.targeting.room)
  assert.is_false(boop.state.targeting.targetShield)
  assert.is_false(boop.state.gold.getPending)
  assert.is_false(boop.state.gold.putPending)
  assert.are.equal(0, boop.state.gold.getRetries)
  assert.are.equal(0, boop.state.gold.putRetries)
  assert.are.equal("", boop.state.gold.packTarget)
  assert.stub(kill_timer_stub).was_called_with(57)
end)
```

### `tests/README.md` (documentation, test inventory)

**Analog:** same file.

**Coverage inventory style** (`tests/README.md` lines 19-24):
```markdown
- `boop_tick_spec.lua`
  Confirms `boop.tick()` sets target and sends the expected actions.
- `boop_runtime_spec.lua`
  Confirms the runtime coordinator exposes owned state domains, emits tick effects, and resolves prompt/diag hold effects.
- `boop_planner_spec.lua`
  Confirms the combat planner returns unexecuted plan data, applies modifiers separately, and executes a prepared plan.
```

**Update pattern:** if adding `tests/boop_state_contract_spec.lua`, add one bullet in this same list near `boop_runtime_spec.lua`. If extending `tests/boop_runtime_spec.lua`, update its existing two-line description rather than adding a duplicate bullet.

### `src/aliases/boop/Targeting/Boop_IH.lua` and `src/aliases/boop/Targeting/aliases.json` (alias adapter + manifest)

**Analog:** `src/aliases/boop/Targeting/IH.lua` and the local `aliases.json`.

**Current registered IH manifest entry** (`src/aliases/boop/Targeting/aliases.json` lines 121-127):
```json
{
  "name": "IH",
  "isActive": "yes",
  "regex": "^(?i)ih$",
  "script": "",
  "isFolder": "no"
}
```

**Registered alias script** (`src/aliases/boop/Targeting/IH.lua` lines 1-2):
```lua
boop.ih.start()
send("ih", false)
```

**Orphan duplicate content** (`src/aliases/boop/Targeting/Boop_IH.lua` lines 1-2):
```lua
boop.ih.start()
send("ih", false)
```

**Pattern:** alias files are thin request-response adapters. For manifest parity, either delete `Boop_IH.lua` as an orphan duplicate or add a real `Boop IH` manifest entry if the command surface intentionally supports `boop ih`. Do not leave an unmanifested Lua file in `src/aliases/boop/Targeting/`.

### `src/triggers/boop/Shield/Weaponmastery_Two_Handed/triggers.json` and trigger scripts (manifest + event adapters)

**Analog:** same folder. The current drift is name-to-file mapping: manifest names contain `Two-Handed`, while actual files use `Two_Handed`.

**Current manifest entries** (`src/triggers/boop/Shield/Weaponmastery_Two_Handed/triggers.json` lines 3-32 and 35-52):
```json
{
  "name": "Weaponmastery Two-Handed Carve",
  "isActive": "yes",
  "isFolder": "no",
  ...
  "patterns": [
    {
      "pattern": "^(\\w+) delivers a terrible stroke with .+, scything straight through the magical shield surrounding (.+)\\.$",
      "type": "regex"
    },
    ...
  ],
  "script": ""
},
{
  "name": "Weaponmastery Two-Handed Slaughter",
  "isActive": "yes",
  "isFolder": "no",
  ...
  "script": ""
}
```

**Actual trigger scripts** (`Weaponmastery_Two_Handed_Carve.lua` lines 1-5):
```lua
-- Generated from Foxhunt shield-related triggers.
boop.targets.onShieldDownTrigger({
  source = "Weaponmastery/Two-Handed/Carve.lua",
  target = { kind = "match", index = 3 },
}, matches, line or "")
```

`Weaponmastery_Two_Handed_Slaughter.lua` lines 1-5:
```lua
-- Generated from Foxhunt shield-related triggers.
boop.targets.onShieldDownTrigger({
  source = "Weaponmastery/Two-Handed/Slaughter.lua",
  target = { kind = "match", index = 3 },
}, matches, line or "")
```

**Manifest naming rule** (`CODEX.md` lines 14-17):
```markdown
- `mfile` version drives `@VERSION@`/`@PKGNAME@` replacements in code.
- Each object folder needs a manifest JSON: `scripts.json`, `aliases.json`, `triggers.json`, etc.
- Names in JSON map to Lua filenames (spaces → underscores).
- Build locally with `muddle` (or Docker wrapper) from repo root; output typically under `build/tmp/` unless `outputFile` changes.
```

**Pattern:** keep trigger scripts thin and delegate to domain handlers. Resolve parity by making manifest names and filenames agree under the existing spaces-to-underscores convention; avoid introducing new punctuation mapping assumptions just for these two entries.

## Shared Patterns

### Version Synchronization

**Sources:** `mfile`, `src/scripts/boop/boop_init.lua`, `CODEX.md`, `AGENTS.md`
**Apply to:** release gate checker, every commit/push version bump

Current synchronized package version observed in source is `0.1.328`. Generated research/codebase maps contain older values; the checker and future commits should parse current files, not rely on generated map text.

`AGENTS.md` lines 11-17:
```markdown
## Versioning Rule
- On every commit and every push, keep all boop version fields synchronized.
- Update `mfile.version`.
- Update `mfile.title` to `boop Hunter <version>`.
- Update `src/scripts/boop/boop_init.lua` `boop.version`.
- Never leave those fields mismatched.
- Before committing or pushing, verify the current version with a quick search/read of those files.
```

`CODEX.md` lines 30-37:
```markdown
## CI & Versioning
- CI reads `mfile` for `package` and `version`, builds with Muddler, and uploads `build/tmp/` as `<package>-<version>`.
- Versioning: bump the boop version on every change we commit/merge/push (even docs/config-only); keep it monotonically increasing.
- Sync rule: every version bump must update all three fields together with the exact same version value:
  - `mfile.version`
  - `mfile.title` as `boop Hunter <version>`
  - `src/scripts/boop/boop_init.lua` `boop.version`
- Never commit or push with those version fields mismatched.
```

### Manifest Parity

**Sources:** `tools/sort_manifests.sh`, `CODEX.md`, source manifests
**Apply to:** `tools/check_release_gates.py`, manifest drift fixes

Use structured JSON parsing. Scope the parity check to `src/scripts`, `src/aliases`, and `src/triggers`. Respect `src/scripts/boop/scripts.json` load order; do not sort it or treat ordering as a parity failure.

Top-level folder manifest pattern (`src/triggers/triggers.json` lines 1-8):
```json
[
  {
    "name": "boop",
    "isActive": "no",
    "isFolder": "yes",
    "script": ""
  }
]
```

Load-order-sensitive script manifest (`src/scripts/boop/scripts.json` lines 1-22):
```json
[
  {"name": "boop_init", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_util", "isActive": "yes", "isFolder": "no", "script": ""},
  ...
  {"name": "boop_events", "isActive": "yes", "isFolder": "no", "script": ""},
  {"name": "boop_bootstrap", "isActive": "yes", "isFolder": "no", "script": ""}
]
```

### Busted Test Style

**Source:** `tests/support/boop_test_helper.lua`, `tests/boop_runtime_spec.lua`, `tests/boop_event_transitions_spec.lua`
**Apply to:** all new or extended state-contract tests

Pattern:
- `local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")`
- `before_each` calls `helper.reset()`
- stub Mudlet side effects (`send`, `sendGMCP`, `tempTimer`, `killTimer`) only at the boundary
- assert production state/effects, not helper internals
- revert every stub in `after_each`

### CI Gate Behavior

**Source:** `.github/workflows/main.yml`
**Apply to:** release gate step and existing Busted result check

Use a normal blocking `run` step. Do not add `continue-on-error`. Put static checks before Muddler, LuaRocks installs, Mudlet download/cache setup, and artifact upload.

### State Ownership Boundary

**Source:** `src/scripts/boop/boop_runtime.lua`
**Apply to:** state-contract Busted tests and static state-drift checker

Preferred domains:
```text
boop.state.combat
boop.state.targeting
boop.state.gold
boop.state.queue
boop.state.walk
boop.state.diag
boop.state.trace
boop.state.ui
boop.state.rage
boop.state.inventory
boop.state.ih
boop.state.gag
```

Do not add new Phase 1 Busted assertions that require known flat-state behavior repairs in `boop_events.lua`, `boop_walk.lua`, or `boop_attacks.lua` unless those repairs are explicitly included in the same plan and verified green. Freeze new drift in the static checker instead.

## No Analog Found

No concrete implementation file is without a usable analog. The only gap is exact language/style precedent for a Python utility script.

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `tools/check_release_gates.py` exact implementation style | utility | batch, file-I/O, transform | No existing Python file in repo. Use `tools/sort_manifests.sh` for local gate scope and `.github/workflows/main.yml` inline Python for stdlib file-reading style. |

## Metadata

**Analog search scope:** `tools/`, `.github/workflows/`, `tests/`, `src/scripts/`, `src/aliases/`, `src/triggers/`, `mfile`, `CODEX.md`, `AGENTS.md`
**Files scanned:** 641 Lua files, 118 JSON manifests, plus workflow/tool/test/documentation files
**Pattern extraction date:** 2026-07-09
