# Mudlet Behavior Tests

These specs run inside a real Mudlet instance in GitHub Actions.

Current coverage:

Owner-keyed operation tests cover interrupt, pull, and gold clear order plus exact-owner exclusion; compatibility blockers cannot hold production work.
Interrupt and pull tests cover idempotent repeats, first-terminal callbacks, and stale generations.
Gold tests cover room-owned pickup, variable direct-to-inventory sovereign lines, inventory-owned packing, get-confirm-put order, and wrong-room retries.
Room observation tests require current Room.Info plus a complete current room item list, reconcile newer generation-bound Add/Remove deltas before application, trace both response orders and their outstanding half, correlate short-lived outbound movement intent with combat-only early lists, let a natural tick claim the exact pending application ahead of its timer, compute readiness without release owners, and reject stale authority.
Walker tests cover computed automatic/manual gating, one move per room generation, stale-target reconciliation, owned stop, attached detach, explicit install, and package loss.
SAFE-02 tests cover disabled and manual-targeting holds plus existing release actions.
Attack profile tests cover Magi Scintilla and Staff-gated Dissolution preference selection while preserving Horripilation as the default, class/spec-scoped temporary preference precedence and reset, class-agnostic session shield modes, and configurable rage-pool threshold behavior including shieldbreak and free-rage exemptions.
Standard GSD SUMMARY/STATE/ROADMAP/REQUIREMENTS/phase-completion commits are planning-only and version-exempt when every staged path is under .planning; plan task commits touching tests, docs, or source are package-affecting and synchronize all four version checkpoints.
Repository terminal CI authority is the mandatory AGENTS.md/CODEX.md extension: after upstream GSD execution and every repository mutation finish, the parent pushes immutable FINAL_SHA and runs tools/wait_for_exact_ci.sh "$FINAL_SHA"; CI evidence remains uncommitted, and any later mutation requires a rerun.

- `boop_targets_spec.lua`
  Confirms target choice behavior, global-blacklist precedence, stale-target reconciliation, and the active-pull preservation exception.
- `boop_whitelist_share_spec.lua`
  Confirms whitelist party-share packet output plus `merge`, `merge-reorder`, and `overwrite` apply behavior for incoming shares.
- `boop_target_call_spec.lua`
  Confirms leader target-call gating waits for a designated party leader to call a room target ID before attacking it.
- `boop_attacks_spec.lua`
  Confirms opener and shieldbreak attack selection, saved and temporary standard attack preference precedence, and fallback when a preferred option is unavailable.
- `boop_assist_spec.lua`
  Confirms assist-mode leader configuration and attack prefixing for direct, queued, and rage actions.
- `boop_openers_contract_spec.lua`
  Confirms `openerAt100` behavior for all profiles that define one.
- `boop_tick_spec.lua`
  Confirms `boop.tick()` sets target and sends the expected actions.
- `boop_runtime_spec.lua`
  Confirms computed lifecycle/room readiness, operation-only holds, compatibility migration, tick effects, and prompt/diag operation effects.
- `boop_state_contract_spec.lua`
  Confirms owned runtime domain defaults and runtime context mapping for high-risk state-contract drift.
- `boop_planner_spec.lua`
  Confirms the combat planner returns unexecuted plan data, applies modifiers separately, and executes a prepared plan.
- `boop_rage_modes_spec.lua`
  Confirms rage-mode decisions for `combo`, `tempo`, `aff`, `small`, `big`, and `none`.
- `boop_rage_contract_spec.lua`
  Confirms generic rage-mode contracts across all rage-enabled profiles.
- `boop_skill_gating_spec.lua`
  Confirms attack selection falls back correctly when required skills are unknown.
- `boop_gold_spec.lua`
  Confirms staged room-owned pickup, direct-to-inventory packing without a redundant get, and get-confirm-put command order.
- `boop_gold_retry_spec.lua`
  Confirms gold get/put retry and give-up behavior after command failures.
- `boop_safety_spec.lua`
  Confirms flee threshold parsing and flee execution.
- `boop_shields_spec.lua`
  Confirms shield seen/down tracking, shieldbreak attempt state updates, packaged shieldmode command wiring, session reset behavior, and that Magi Staffcast damage is not packaged as shield-down evidence.
- `boop_prequeue_spec.lua`
  Confirms prequeue scheduling, queued standard attack behavior, class-attack rebuilds in both shield-mode directions, and that a shield-gain/rebound rebuild cannot be downgraded to normal damage before the shieldbreak executes.
- `boop_profiles_spec.lua`
  Confirms class/spec-specific standard attack selection for additional profiles.
- `boop_profile_matrix_spec.lua`
  Confirms spec-based standard and shield commands across all by-spec profiles.
- `boop_diag_spec.lua`
  Confirms diagnose pauses attacks and resumes after the GMCP affliction snapshot or visible result fallback plus prompt.
- `boop_diag_timeout_spec.lua`
  Confirms diagnose timeout resumes attacks and cannot leave stale evidence that consumes every later diagnose result.
- `boop_interrupt_spec.lua`
  Confirms prompt-resume queued interrupt commands such as `matic` pause attacks, queue their action, and resume on prompt.
- `boop_pull_spec.lua`
  Confirms pull command construction, GMCP return completion, timeout cleanup for stuck pull state, and separator safety.
- `boop_event_transitions_spec.lua`
  Confirms room and target gmcp transitions clear stale combat state and retarget correctly.
- `boop_wield_spec.lua`
  Confirms inventory GMCP list/add/update/remove events track currently wielded left/right-hand items.
- `boop_weapon_spec.lua`
  Confirms `boop weapon` saves and clears class-scoped weapon designations consumed by weapon-dependent profiles.
- `boop_gag_spec.lua`
  Confirms condensed gag summaries for attack, mob-damage, and kill replay lines.
- `boop_skills_spec.lua`
  Confirms skill GMCP ingestion, direct skill lookups, and learned/not-learned handling.
- `boop_rage_ingestion_spec.lua`
  Confirms rage readiness fallback, rage gain sampling, rage affliction trigger ingestion, and optional suppression of party affliction callouts.
- `boop_trace_spec.lua`
  Confirms `boop trace` captures compact GMCP room, item, and gold-related item events plus the response-fence half still awaited for debugging live hunting flow.
- `boop_persistence_spec.lua`
  Confirms public config, including rage affliction callout settings, with party size and shield mode intentionally kept session-local, trigger-folder sync for hunting on/off, plus whitelist/blacklist and whitelist-tag edits through the DB hooks.
- `boop_db_spec.lua`
  Confirms DB guard paths degrade to warnings instead of throwing when optional Mudlet sheets are missing in an older local profile DB.
- `boop_ui_spec.lua`
  Confirms the bare `boop` command shows the home dashboard, `boop status` shows the installed version and computed status, and control, party, roster, and related UI flows remain coherent.
- `boop_ui_registry_spec.lua`
  Confirms the shared config, screen, mode, preset, and help registries exist and drive the corresponding UI commands.
- `boop_menu_wiring_spec.lua`
  Confirms rich Mudlet dashboard/help callbacks seed commands or route to the expected UI functions.
- `boop_stats_spec.lua`
  Confirms gold/xp accumulation across session/login/trip/lifetime scopes, party-size-aware mob xp bucketing, workflow-style stats help output, per-target efficiency and profitability summaries, richer area rankings, trip comparison output, rage-efficiency summaries, per-ability damage/crit/kill summaries, crit/record rollups, reset behavior, whitelist rendering, and human-readable stats summaries.

Good candidates for future additions:

- more text replay cases from live combat logs
- Mudlet DB integration tests beyond save-hook verification
