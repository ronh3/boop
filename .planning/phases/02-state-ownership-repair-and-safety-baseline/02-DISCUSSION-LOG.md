# Phase 02: State Ownership Repair and Safety Baseline - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md. This log preserves the alternatives considered.

**Date:** 2026-07-10T22:32:51Z
**Phase:** 02-state-ownership-repair-and-safety-baseline
**Areas discussed:** State Migration Strictness, Unsafe-State Blockers, Flee And Target Loss Policy, Status And Trace Surface, Pull Lifecycle Boundaries, GMCP Recovery Policy, Autowalk Scope Boundary

---

## State Migration Strictness

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Remaining flat `boop.state.*` access | Strict removal; temporary compatibility shims; agent decides | Strict removal |
| Enforcement | CI/static gate; test coverage only; both where practical | CI/static gate |
| Partially migrated files | No partial allowance; narrow reviewed allowance; agent decides | No partial allowance |
| Helpers and fixtures | Migrate helpers/fixtures; production only; agent decides | Migrate helpers/fixtures |
| Migration order | Safety-critical runtime first; module-by-module cleanup; agent decides | Safety-critical runtime first |
| Refactor allowance | Behavior-preserving only; clean module boundaries; agent decides | Clean module boundaries where useful |
| Old flat-state tests | Rewrite to owned-domain behavior; keep temporarily; agent decides | Rewrite to owned-domain behavior |
| Obsolete flat keys | Remove now; leave harmlessly; agent decides | Remove now |

**Notes:** The user chose strict migration and strong CI enforcement. Refactors are allowed only when they reduce state-ownership risk.

---

## Unsafe-State Blockers

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Default incomplete-state behavior | Hard-hold automation; risk-specific hold; agent decides | Hard-hold automation |
| Operator output | One concise blocker line; detailed report; agent decides | Concise default, details on demand |
| Resume trust condition | GMCP refresh; prompt plus GMCP refresh; manual resume | Prompt plus GMCP refresh |
| Room change behavior | Persist across rooms; reevaluate immediately; agent decides | Reevaluate immediately |
| Explicit missing-state coverage | Core safety only; core plus movement/loot; agent decides | Core safety only |
| Message rate limiting | Rate-limit repeats; warn every blocked tick; agent decides | Rate-limit repeated reasons |
| Saved enabled config | Temporary runtime hold; disable saved config; agent decides | Temporary runtime hold |
| Manual commands | Automation only; block risky manual boop commands; agent decides | Automation only |
| Machine-readable reasons | Structured reasons; text only; agent decides | Structured blocker reasons |

**Notes:** The user wants fail-closed automation with low-scroll operator feedback and structured state for tests/status/trace.

---

## Flee And Target Loss Policy

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Auto-flee combat intent | Cancel all combat intent; pause and restore; agent decides | Cancel all combat intent |
| Auto-flee walking/gold intent | Cancel both; pause both; agent decides | Cancel both |
| Hunting re-enable after flee | No automatic re-enable; re-enable after safe room; agent decides | No automatic re-enable |
| Target disappears from room items | Clear target and attack intent; keep until IRE.Target update; agent decides | Clear target and attack intent |
| Active pull exception | Same cleanup rules; preserve during pull; agent decides | Preserve during pull |
| Pull ends and target absent | Clear then; keep until IRE.Target update; agent decides | Clear after pull recovery ends |
| Target-loss warning | Once per loss event; trace only; agent decides | Warn once per loss event |
| Flee cleanup output | Single summary line; separate lines; agent decides | Single summary line |
| Flee cleanup test order | Assert order; final state only; agent decides | Assert cleanup before send |
| Retarget timing | Same tick if trustworthy; next prompt only; agent decides | Same tick if trustworthy |

**Notes:** The user corrected one answer: target disappearance should use option 1, clear target and attack intent, not keep target until explicit target update.

---

## Status And Trace Surface

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Status/dashboard blocker display | Compact blocker summary; full state dump; agent decides | Compact blocker summary |
| Trace content | State transitions only; full per-tick context; agent decides | State transitions by default, targeted per-tick details when explicitly enabled |
| State values shown | Normalized owned state; raw plus normalized; agent decides | Normalized owned-state values |
| Live hunting output volume | Minimal; moderate; agent decides | Minimal live output, details on request |
| Help/docs updates | Help/docs; help only; agent decides | Update command help/docs where relevant |
| Reason-code display | Stable codes; human wording only; both code and label | Both stable code and short human label |
| UAT surface | Include in UAT; tests only; minimal UAT checkpoint | Minimal UAT checkpoint |

**Notes:** The user asked for short impact summaries and recommendation reasons going forward. The selected status format should be diagnostic but compact.

---

## Pull Lifecycle Boundaries

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Pull ownership | Movement pause/resume only; pull owns target exception; agent decides | Movement lifecycle plus narrow target-loss exception |
| Pull timeout while away | Stay held/off; resume anyway; agent decides | Stay paused/held while away; resume only after return and trustworthy state |
| Pull blocker/status reasons | Structured reasons; keep separate; agent decides | Structured reasons only when actively holding automation |
| Pull command validation | No state/lifecycle only; harden inputs now; agent decides | No validation changes in Phase 02 |

**Notes:** Pull remains a movement lifecycle owner, not a broad targeting owner.

---

## GMCP Recovery Policy

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Missing IRE modules | Retry and hard-hold; retry but continue partial automation; agent decides | Retry immediately and hard-hold target-dependent automation |
| Retry aggressiveness | Immediate then throttled; every prompt; agent decides | One immediate retry, then short throttle/backoff |
| Operator output | Concise warning once; silent unless status requested; agent decides | One concise warning on entering recovery |
| Recovery tests | Focused synthetic tests; live validation only; agent decides | Synthetic tests in Phase 02, live validation in Phase 06 |

**Notes:** The chosen policy prevents missed support retries without creating repeated GMCP negotiation spam.

---

## Autowalk Scope Boundary

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Phase 02 autowalk scope | Only migrate blocker state; fully fix now; agent decides | Migrate blocker reads and prevent unsafe advancement now |
| Walk interactions blocked | Target/flee only; target/flee/GMCP/pull; agent decides | Target/flee/GMCP/pull now; gold/diag depth waits for Phase 03 unless touched |
| Test location | Walk spec; runtime/event specs; agent decides | Focused blocker tests wherever harness is cleanest |
| `demonnicAutoWalker` install/status | No; yes; agent decides | Do not change unless required for blocker reason |

**Notes:** The user wants Phase 02 to close immediate safety risk without absorbing Phase 03's dedicated walk regression scope.

---

## Agent Discretion

- Exact reason-code names may be chosen during planning, provided they are stable, documented, and testable.
- Test location may be chosen by harness suitability.
- Small module extraction is allowed only when it directly lowers state-migration risk.

## Deferred Ideas

- Full walker behavior suite: Phase 03.
- Command-fragment validation: Phase 04.
- Full live reconnect validation: Phase 06.
- Broad release/operator documentation: Phase 06 unless Phase 02 changes an immediate command workflow.
