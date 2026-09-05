---
handoff_version: 1
status: ready
agent: codex
mode: phase_bootstrap
branch: phase/106-refactor-wire-invariant
task_base_sha: 062743fced548cd1b0b4bdcfe66ee0a8eb671cd7
review_target_sha: null
assigned_by: Human + ChatGPT/Neon
---

# Objective

Bootstrap repository workflow Phase 106, which activates
REFACTOR-ROADMAP.md Refactor Phase 6 — Complete the Wire invariant.

This handoff establishes the fixed active context and phase evidence scaffolding.
It does NOT authorize source implementation yet.

# Required Inputs

Read and treat as authority, in repository precedence order:

- AGENTS.md
- .planning/STATE.md
- .planning/ROADMAP.md
- CODEX.md
- README.md
- DESIGN.md
- ARCHITECTURE.md
- ARCHITECTURE-RULES.md
- TARGET-ARCHITECTURE.md
- REFACTOR-ROADMAP.md

Exact completed-phase/main baseline:

062743fced548cd1b0b4bdcfe66ee0a8eb671cd7

Refactor Phase 5 is already landed on main. Refactor Phase 6 is the newly
human-selected work. Do not activate Hardening Phase 6.

# Task

Your first executable action must be:

python3 tools/check_handoff_execution.py --agent codex --fetch

Stop if it fails.

Then bootstrap the new active phase.

Create:

.planning/phases/106-refactor-wire-invariant/106-CONTEXT.md
.planning/phases/106-refactor-wire-invariant/106-VERIFICATION.md
.planning/phases/106-refactor-wire-invariant/106-ADVERSARIAL-REVIEW.md
.planning/phases/106-refactor-wire-invariant/106-UAT.md

Update .planning/STATE.md to activate workflow Phase 106:

active_phase: "106"
active_phase_name: refactor-06-wire-invariant
active_branch: phase/106-refactor-wire-invariant
active_specification: .planning/phases/106-refactor-wire-invariant/106-CONTEXT.md
main_baseline: 062743fced548cd1b0b4bdcfe66ee0a8eb671cd7

Initialize the new phase gates as pending:

independent_review: pending
independent_review_target_sha: null
human_arbitration: pending
live_mudlet_validation: pending_human_determination
phase_closure: pending_human_authorization
merge_authorization: pending_external_exact_sha_authorization

Set factual status to the equivalent of:

phase_bootstrapped_awaiting_implementation

Update last_updated if permitted by AGENTS.md.

Update .planning/ROADMAP.md planning metadata to:

- mark Phase 00.1 complete at merged SHA
  062743fced548cd1b0b4bdcfe66ee0a8eb671cd7
  with approval tag phase-00.1-approved-062743fced54;
- record that workflow Phase 106 activates Refactor Phase 6;
- explicitly preserve Hardening Phase 6 as a separate, still-unactivated namespace.

Do not alter its hardening Phase 3-6 completion checkboxes merely because
Refactor Phase 6 is now active.

FIXED PHASE 106 CONTEXT

106-CONTEXT.md must explicitly establish all of the following.

Identity:
- This is REFACTOR-ROADMAP Refactor Phase 6, not Hardening Phase 6.
- Workflow ID 106 exists only to prevent repository branch/context/tag namespace
  collision between the two Phase 6 sequences.

Primary invariant:
- boop.wire is the only production caller of send() and sendGMCP().
- There is no second sanctioned production sender.

Use the CURRENT ARCHITECTURE.md §6 inventory as implementation truth rather
than blindly copying the older line-number inventory in REFACTOR-ROADMAP.md.

Current measured boundary:
- 16 production send() calls across 9 files;
- one of those is already the raw Wire dispatcher call;
- therefore 15 non-Wire send() calls currently require migration;
- the current inventory includes src/aliases/boop/Targeting/IH.lua;
- the room-item request send site now lives in boop_room.lua after Refactor
  Phase 5;
- 8 sendGMCP() calls remain across boop_init.lua, boop_skills.lua, and
  boop_room.lua.

Required transport design:
Wire exposes distinct concern-appropriate APIs for:
- owned combat dispatch;
- unowned utility commands;
- queue control;
- channel text;
- protocol requests.

Do not force unrelated commands through the Standard dispatch lifecycle merely
to centralize egress.

Required Phase 6 structural work:
- add/complete Wire outbound registration and observation machinery;
- migrate every remaining production send() caller through Wire;
- migrate every production sendGMCP() caller through Wire;
- preserve boop.executeAction as the justified external compatibility forwarder;
- keep target identity caller-supplied; Wire must not depend on Targets;
- extract boop_standard.lua from Runtime for queued-Standard lifecycle ownership:
  dispatch generations, baseline, candidate buffering/disposition, grace,
  retry/recovery, terminals, and mutation barrier;
- update manifest/load order as required by the new Standard module;
- narrow architectural send/sendGMCP guardrails so only boop_wire.lua may call
  the Mudlet primitives directly.

F4:
- investigate markUnnamableMaulUsed on direct versus queued dispatch;
- determine whether trigger-driven boop.rage.onHoundMaulUsed /
  boop.rage.onHyenaMaulUsed already cover the queued path;
- record the factual result;
- DO NOT change F4 behavior in this phase without separate Human + Neon approval.

Compatibility/behavior:
- preserve S1 alias syntax and semantics;
- preserve exact command text and ordering;
- preserve queue timing and queue-control semantics;
- preserve settarget synchronization behavior;
- preserve Standard lifecycle behavior;
- preserve GMCP payloads and request sequencing;
- preserve IH alias ordering: boop.ih.start() remains before the outbound "ih";
- no unapproved observable behavior change.

Acceptance:
- byte-identical outbound game/protocol behavior for covered regression cases;
- exactly one production send( primitive call, in boop_wire.lua;
- exactly one production sendGMCP( primitive call, in boop_wire.lua;
- architecture guard enforces that invariant;
- full relevant regression suite green;
- manifest/version/release gates green;
- measured dependency/SCC evidence recorded;
- no SCC-monotonicity requirement before Refactor Phase 8.

Required regression emphasis includes at minimum:
- boop_prequeue_spec
- boop_assist_spec
- boop_tick_spec
- boop_interrupt_spec
- boop_pull_spec
- boop_gold_spec
- boop_safety_spec
- boop_target_call_spec
- boop_whitelist_share_spec
- boop_rage_ingestion_spec
- boop_event_transitions_spec
- boop_trace_spec
- architecture-guard tests
- manifest/release gates

Out of scope:
- Refactor Phase 7 canonical accessor work;
- Refactor Phase 8 Gold/Interrupt/Inventory subsystem extraction;
- Hardening Phase 6;
- command-validation redesign;
- Mnemosyne/Nemesine;
- unrelated UI, gameplay, performance, or feature changes;
- any F4 behavioral fix.

The context may contain a proposed implementation/commit decomposition, but that
decomposition must remain subordinate to this fixed scope.

# Constraints

This bootstrap execution is PLANNING ONLY.

Do not modify:
- src/
- tools/
- tests/
- root architecture documents
- package manifests
- package version fields

All bootstrap-commit paths must remain under .planning/.

Package version remains exactly 0.1.496.10.

Do not begin Phase 6 source implementation in this handoff.

Do not create a Claude review handoff yet.

# Verification

Before committing:

python3 tools/check_release_gates.py
python3 tests/test_workflow_gates.py
git diff --check

Confirm all staged paths are under .planning/ and version remains 0.1.496.10.

# Completion Boundary

Commit the planning-only phase activation/scaffolding coherently.

Suggested commit:

docs(phase): bootstrap Refactor Phase 6 wire invariant

At completion, retire your own handoff by changing only:

status: ready
to:
status: consumed

Do not alter any other CODEX-NEXT frontmatter value or body byte during
retirement.

Push phase/106-refactor-wire-invariant.

Run exact-SHA CI for the resulting bootstrap HEAD.

Then STOP.

Report:
- bootstrap commit SHA;
- branch;
- context path;
- confirmation workflow Phase 106 maps to Refactor Phase 6;
- confirmation Hardening Phase 6 remains untouched;
- STATE summary;
- version remains 0.1.496.10;
- local gate results;
- exact-SHA CI result;
- confirmation no source implementation occurred.
