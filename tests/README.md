# Mudlet Behavior Tests

These specs run inside a real Mudlet instance in GitHub Actions.

Current coverage:

- `boop_targets_spec.lua`
  Confirms target choice behavior for whitelist priority and `retargetOnPriority`.
- `boop_attacks_spec.lua`
  Confirms opener and shieldbreak attack selection.
- `boop_tick_spec.lua`
  Confirms `boop.tick()` sets target and sends the expected actions.
- `boop_rage_modes_spec.lua`
  Confirms rage-mode decisions for `combo`, `tempo`, `aff`, `small`, `big`, and `none`.
- `boop_skill_gating_spec.lua`
  Confirms attack selection falls back correctly when required skills are unknown.
- `boop_gold_spec.lua`
  Confirms auto-gold queueing and pending-gold flush behavior.
- `boop_gold_retry_spec.lua`
  Confirms gold get/put retry and give-up behavior after command failures.
- `boop_safety_spec.lua`
  Confirms flee threshold parsing and flee execution.
- `boop_shields_spec.lua`
  Confirms shield seen/down tracking and shieldbreak attempt state updates.
- `boop_prequeue_spec.lua`
  Confirms prequeue scheduling and queued standard attack behavior.
- `boop_profiles_spec.lua`
  Confirms class/spec-specific standard attack selection for additional profiles.
- `boop_diag_spec.lua`
  Confirms diagnose pauses attacks and resumes them after the diagnose line plus prompt.

Good candidates for future additions:

- more class/spec-specific attack profiles
- shield tracking from trigger events
- queue/prequeue timing flows
- gag summary behavior
- gold retry failure paths
