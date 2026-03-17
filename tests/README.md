# Mudlet Behavior Tests

These specs run inside a real Mudlet instance in GitHub Actions.

Current coverage:

- `boop_targets_spec.lua`
  Confirms target choice behavior for whitelist priority and `retargetOnPriority`.
- `boop_target_call_spec.lua`
  Confirms leader target-call gating waits for a designated party leader to call a room target ID before attacking it.
- `boop_attacks_spec.lua`
  Confirms opener and shieldbreak attack selection, plus preferred standard attack overrides and fallback when a preferred option is unavailable.
- `boop_assist_spec.lua`
  Confirms assist-mode leader configuration and attack prefixing for direct, queued, and rage actions.
- `boop_openers_contract_spec.lua`
  Confirms `openerAt100` behavior for all profiles that define one.
- `boop_tick_spec.lua`
  Confirms `boop.tick()` sets target and sends the expected actions.
- `boop_rage_modes_spec.lua`
  Confirms rage-mode decisions for `combo`, `tempo`, `aff`, `small`, `big`, and `none`.
- `boop_rage_contract_spec.lua`
  Confirms generic rage-mode contracts across all rage-enabled profiles.
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
- `boop_profile_matrix_spec.lua`
  Confirms spec-based standard and shield commands across all by-spec profiles.
- `boop_diag_spec.lua`
  Confirms diagnose pauses attacks and resumes them after the diagnose line plus prompt.
- `boop_diag_timeout_spec.lua`
  Confirms diagnose timeout resumes attacks if the expected confirmation never arrives.
- `boop_event_transitions_spec.lua`
  Confirms room and target gmcp transitions clear stale combat state and retarget correctly.
- `boop_gag_spec.lua`
  Confirms condensed gag summaries for attack and kill replay lines.
- `boop_skills_spec.lua`
  Confirms skill GMCP ingestion, direct skill lookups, and learned/not-learned handling.
- `boop_rage_ingestion_spec.lua`
  Confirms rage readiness fallback, rage gain sampling, rage affliction trigger ingestion, and optional suppression of party affliction callouts.
- `boop_persistence_spec.lua`
  Confirms public config, including rage affliction callout settings, with party size intentionally kept session-local, plus whitelist/blacklist and whitelist-tag edits through the DB hooks.
- `boop_db_spec.lua`
  Confirms DB guard paths degrade to warnings instead of throwing when optional Mudlet sheets are missing in an older local profile DB.
- `boop_walk_spec.lua`
  Confirms the external `demonnicAutoWalker` integration only advances once a room is settled and clear under `boop`'s own targeting rules.
- `boop_ui_spec.lua`
  Confirms the bare `boop` command shows an operations dashboard with mode/blocker guidance, plus the new mode, theme, and party-operations dashboards.
- `boop_stats_spec.lua`
  Confirms gold/xp accumulation across session/login/trip/lifetime scopes, party-size-aware mob xp bucketing, stats help output, per-target efficiency and profitability summaries, richer area rankings, trip comparison output, rage-efficiency summaries, per-ability damage/crit/kill summaries, crit/record rollups, reset behavior, whitelist rendering, and human-readable stats summaries.

Good candidates for future additions:

- more text replay cases from live combat logs
- Mudlet DB integration tests beyond save-hook verification
