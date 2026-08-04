# Deferred Items

## Plan 03-19: Broad host helper cannot execute the entire test tree

- **Found during:** Task 3 full-host verification.
- **Command:** `env BOOP_REPO_ROOT="$PWD" TESTS_DIRECTORY="$PWD/tests" busted --helper=tests/support/boop_host_busted_helper.lua tests`
- **Observed:** The one-process run reported 320 successes, 47 failures, and 92 errors. The focused helper loads only the Occultist attack profile and omits full Mudlet database and rich-output stubs, so unrelated profile, persistence, gag, and UI specs cannot run as one complete host suite through that helper.
- **Scope decision:** This is pre-existing test-harness coverage debt and is unrelated to Plan 03-19's alias and documentation changes. Expanding the helper would modify an unplanned test-infrastructure file, broaden the package-affecting commit, and invalidate the plan's exact five-file/version contract.
- **Evidence retained:** The complete affected trace, registry, UI, state, runtime, and persistence set passed 87 checks with 0 failures and 0 errors. All production/alias Lua parsed, release gates passed, and Muddler built package 0.1.440.
- **Follow-up:** Either create a genuinely comprehensive host helper with all attack profiles and Mudlet DB/rich-output stubs, or replace the broad command with the authoritative real-Mudlet CI suite.

## Plan 03-29: Aggregate-owner tick expectations predate exact queued-standard ownership

- **Found during:** Task 1 full-host verification after the 206-check cross-gap suite passed.
- **Command:** Fresh-process execution of each `tests/*_spec.lua`, including `tests/boop_tick_spec.lua` in isolation.
- **Observed:** Six aggregate-owner cases in `boop_tick_spec.lua` expect a new standard plus Rage dispatch immediately after the final synthetic operation lock clears, but the exact queued-standard lifecycle retained from Plan 03-25 correctly leaves that mutation barrier pending. The isolated spec reports 16 successes and 6 failures; an immutable `git archive HEAD` of Plan 03-29's starting commit reproduces the same six failures exactly.
- **Scope decision:** This is pre-existing stale test expectation, not a Plan 03-29 trace regression. The only production behavior changed here is live trace admission, and the plan explicitly keeps unrelated gap tests read-only. The required nine-spec queue/interrupt/gold/Rage/trace regression gate passed 206 checks with zero failures or errors.
- **Follow-up:** Reconcile the six aggregate-owner cases with the exact standard owner/generation terminal path in a dedicated test-maintenance plan; do not weaken the queued-standard barrier to restore immediate dispatch.
