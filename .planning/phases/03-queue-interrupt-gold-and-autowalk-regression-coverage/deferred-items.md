# Deferred Items

## Plan 03-19: Broad host helper cannot execute the entire test tree

- **Found during:** Task 3 full-host verification.
- **Command:** `env BOOP_REPO_ROOT="$PWD" TESTS_DIRECTORY="$PWD/tests" busted --helper=tests/support/boop_host_busted_helper.lua tests`
- **Observed:** The one-process run reported 320 successes, 47 failures, and 92 errors. The focused helper loads only the Occultist attack profile and omits full Mudlet database and rich-output stubs, so unrelated profile, persistence, gag, and UI specs cannot run as one complete host suite through that helper.
- **Scope decision:** This is pre-existing test-harness coverage debt and is unrelated to Plan 03-19's alias and documentation changes. Expanding the helper would modify an unplanned test-infrastructure file, broaden the package-affecting commit, and invalidate the plan's exact five-file/version contract.
- **Evidence retained:** The complete affected trace, registry, UI, state, runtime, and persistence set passed 87 checks with 0 failures and 0 errors. All production/alias Lua parsed, release gates passed, and Muddler built package 0.1.440.
- **Follow-up:** Either create a genuinely comprehensive host helper with all attack profiles and Mudlet DB/rich-output stubs, or replace the broad command with the authoritative real-Mudlet CI suite.
