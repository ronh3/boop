# Testing Patterns

**Analysis Date:** 2026-07-09

## Test Framework

**Runner:**
- Busted runs inside a real Mudlet profile in GitHub Actions, configured by `.github/workflows/main.yml`.
- Lua 5.1.5 is installed through `leafo/gh-actions-lua@v8.0.0` in `.github/workflows/main.yml`.
- Mudlet runtime is provided by `Mudlet-4.20.1-linux-x64.AppImage.tar` in `.github/workflows/main.yml`.
- Config: no `.busted` or `busted.lua` config file is detected; the runner is controlled by environment variables in `.github/workflows/main.yml`.

**Assertion Library:**
- Busted/luassert assertions are used throughout `tests/`: `assert.are.equal`, `assert.are.same`, `assert.is_true`, `assert.is_false`, `assert.is_nil`, `assert.has_no.errors`, and `assert.stub(...)`.

**Run Commands:**
```bash
muddle
AUTORUN_BUSTED_TESTS="true" TESTS_DIRECTORY="$PWD/tests" QUIT_MUDLET_AFTER_TESTS="true" PRETEST_PACKAGE="$PWD/build/boop Hunter.mpackage" /tmp/Mudlet.AppImage --profile "GithubTests" --mirror
Not detected              # Watch mode
Not detected              # Coverage
```

## Test File Organization

**Location:**
- Tests live in a top-level `tests/` directory, separate from package source under `src/`.
- Shared setup helpers live in `tests/support/boop_test_helper.lua`.
- Coverage inventory and suite intent are documented in `tests/README.md`.

**Naming:**
- Use `tests/boop_<domain>_spec.lua` for behavior specs: `tests/boop_targets_spec.lua`, `tests/boop_gold_spec.lua`, `tests/boop_ui_spec.lua`, `tests/boop_runtime_spec.lua`.
- Use contract/matrix names for data-driven profile coverage: `tests/boop_openers_contract_spec.lua`, `tests/boop_rage_contract_spec.lua`, `tests/boop_profile_matrix_spec.lua`.

**Structure:**
```text
tests/
├── boop_<domain>_spec.lua
├── boop_<domain>_contract_spec.lua
├── boop_<domain>_matrix_spec.lua
└── support/
    └── boop_test_helper.lua
```

## Test Structure

**Suite Organization:**
```lua
local helper = dofile(os.getenv("TESTS_DIRECTORY") .. "/support/boop_test_helper.lua")

describe("boop attack selection", function()
  before_each(function()
    helper.reset()
    helper.setClass("Occultist")
    helper.setTarget("42", "a test denizen", "100%")
    helper.learnSkills({
      { name = "Attend", group = "Occultism" },
      { name = "Lycantha", group = "Domination" },
    })
  end)

  it("prefers the full-hp opener when available", function()
    helper.setRage(0)

    local actions = boop.attacks.choose()

    assert.are.equal("attend 42", actions.standard)
    assert.are.equal("", actions.rage)
    assert.is_true(actions.standardIsOpener)
  end)
end)
```

**Patterns:**
- Start every spec by loading `tests/support/boop_test_helper.lua` through `TESTS_DIRECTORY`, as in `tests/boop_attacks_spec.lua`, `tests/boop_tick_spec.lua`, and `tests/boop_ui_spec.lua`.
- Reset the real package state in `before_each` with `helper.reset()` from `tests/support/boop_test_helper.lua`.
- Seed GMCP, class/spec, target, denizens, rage, skills, lists, and config through helper methods before calling production functions, as in `tests/boop_event_transitions_spec.lua` and `tests/boop_rage_modes_spec.lua`.
- Keep assertions behavior-level: verify outgoing commands, config persistence calls, state transitions, rendered text fragments, and returned action tables in `tests/boop_tick_spec.lua`, `tests/boop_persistence_spec.lua`, `tests/boop_ui_spec.lua`, and `tests/boop_attacks_spec.lua`.

## Mocking

**Framework:** Busted stubs/spies through `stub(...)` and `assert.stub(...)`, used in `tests/boop_tick_spec.lua`, `tests/boop_gold_spec.lua`, `tests/boop_ui_spec.lua`, and `tests/boop_menu_wiring_spec.lua`.

**Patterns:**
```lua
local send_stub
local timer_stub
local kill_timer_stub

before_each(function()
  helper.reset()
  timer_stub = stub(_G, "tempTimer", function(_, callback)
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

**What to Mock:**
- Mock Mudlet side effects and external runtime functions: `_G.send`, `_G.sendGMCP`, `_G.tempTimer`, `_G.killTimer`, `_G.cecho`, `_G.cechoLink`, `_G.echo`, `_G.echoLink`, `_G.enableTrigger`, `_G.disableTrigger`, `_G.appendCmdLine`, and `_G.clearCmdLine`, as shown in `tests/boop_tick_spec.lua`, `tests/boop_ih_spec.lua`, and `tests/boop_menu_wiring_spec.lua`.
- Mock persistence hooks when testing command/UI behavior without writing to DB: `boop.db.saveConfig`, `boop.db.deleteConfig`, `boop.db.saveList`, and `boop.db.saveWhitelistTags` in `tests/boop_persistence_spec.lua`.
- Mock `boop.util.ok`, `boop.util.warn`, `boop.util.info`, and `boop.util.echo` when asserting user-facing output in plain text mode, as in `tests/boop_ui_spec.lua` and `tests/boop_weapon_spec.lua`.

**What NOT to Mock:**
- Do not mock the domain under test. Exercise real `boop.attacks.choose`, `boop.tick`, `boop.runtime.context`, `boop.targets.choose`, `boop.ui.config`, and `boop.stats.command` from `src/scripts/boop/` unless the test is explicitly checking a wiring boundary.
- Do not bypass `helper.reset()` in `tests/support/boop_test_helper.lua`; it resets GMCP, config, state domains, skills, rage, stats, afflictions, and DB-backed tables to a known baseline.

## Fixtures and Factories

**Test Data:**
```lua
helper.setDenizens({
  { id = "42", name = "a test denizen" },
})

helper.learnSkills({
  { name = "Lycantha", group = "Domination" },
  { name = "Warp", group = "Occultism" },
  { name = "harry", group = "Attainment" },
})
```

**Location:**
- The shared fixture/factory surface is `tests/support/boop_test_helper.lua`.
- Inline data tables are preferred for case-local GMCP payloads, denizens, profile expectations, and UI output captures in `tests/boop_event_transitions_spec.lua`, `tests/boop_profile_matrix_spec.lua`, and `tests/boop_ui_spec.lua`.
- Data-driven contract cases may be generated from production registries, as in `tests/boop_profile_matrix_spec.lua` and `tests/boop_rage_contract_spec.lua`.

## Coverage

**Requirements:** No numeric coverage threshold is detected in `.github/workflows/main.yml`, `.luacov*`, or `tests/README.md`.

**View Coverage:**
```bash
Not detected
```

## Test Types

**Unit Tests:**
- Behavior-focused unit tests call individual domains with helper-seeded state: target selection in `tests/boop_targets_spec.lua`, attack selection in `tests/boop_attacks_spec.lua`, safety in `tests/boop_safety_spec.lua`, skills in `tests/boop_skills_spec.lua`, and rage ingestion in `tests/boop_rage_ingestion_spec.lua`.

**Integration Tests:**
- Mudlet integration-style specs run inside the Mudlet profile and cover GMCP transitions, DB guard paths, trigger folder sync, rich UI callbacks, command queueing, timers, and package-level tick behavior: `tests/boop_event_transitions_spec.lua`, `tests/boop_db_spec.lua`, `tests/boop_persistence_spec.lua`, `tests/boop_menu_wiring_spec.lua`, and `tests/boop_tick_spec.lua`.

**E2E Tests:**
- Browser-style E2E is not used. The closest end-to-end coverage is the GitHub Actions Mudlet AppImage run in `.github/workflows/main.yml`, which imports the built package from `build/boop Hunter.mpackage` and runs all Busted specs under `tests/`.
- `tests/boop_walk_spec.lua` contains an intentionally disabled suite for walk integration; add meaningful walker tests there when the external walker behavior has a stable mockable boundary.

## Common Patterns

**Async Testing:**
```lua
local scheduled_callback

timer_stub = stub(_G, "tempTimer", function(_, callback)
  scheduled_callback = callback
  return 99
end)

boop.onRoomItemsRemove()
assert.is_function(scheduled_callback)
scheduled_callback()
```

**Error Testing:**
```lua
boop.db.handle = setmetatable({}, {
  __index = function(_, key)
    if key == "mob_xp_v2" then
      error("Attempt to access sheet")
    end
    return nil
  end,
})

assert.has_no.errors(function()
  boop.db.clearMobXpStats()
end)
```

**UI Testing:**
- Stub `boop.util.echo`, `boop.util.ok`, `boop.util.warn`, and `boop.util.info`, then assert deterministic text fragments in `tests/boop_ui_spec.lua`, `tests/boop_stats_spec.lua`, and `tests/boop_weapon_spec.lua`.
- For rich Mudlet links, stub `_G.cecho` and `_G.cechoLink`, collect callbacks/hints, execute callbacks, and assert routed functions or seeded command lines in `tests/boop_ui_spec.lua` and `tests/boop_menu_wiring_spec.lua`.

---

*Testing analysis: 2026-07-09*
