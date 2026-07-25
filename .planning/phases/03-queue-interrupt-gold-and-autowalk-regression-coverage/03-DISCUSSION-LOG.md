# Phase 03: Queue, Interrupt, Gold, and Autowalk Regression Coverage - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md. This log preserves the alternatives considered.

**Date:** 2026-07-25T22:51:37Z
**Phase:** 03-queue-interrupt-gold-and-autowalk-regression-coverage
**Areas discussed:** Overlapping Holds, Interrupt Release Timing, Gold Room Ownership, Autowalk Movement Safety, Manual Move Semantics, Walker Stop Ownership

---

## Overlapping Holds

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Resume rule | Per-system all-clear; global all-clear; primary blocker only | Per-system all-clear |
| Release boundary | Subsystem-specific release; release all systems; first-owner release | Subsystem-specific release |
| Normal diagnostics | Primary plus count; show all everywhere; primary only | Primary plus count |
| Primary blocker choice | Fixed safety priority; first entered; most recent | Fixed safety priority |

**Notes:** Each subsystem keeps every blocker that affects it. Compact status and complete trace output serve different operator needs.

---

## Interrupt Release Timing

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Completion evidence | Operation-specific evidence; any prompt; shared timeout | Operation-specific evidence |
| Timeout behavior | Controlled recovery; remain held; release existing intent | Controlled recovery |
| Duplicate request | Treat as pending; resend and restart; queue another | Treat as pending |
| Timeout/success race | First signal wins; success overrides; wait for both | First signal wins |

**Notes:** Interrupt operations are idempotent and release exactly once without disturbing unrelated blockers.

---

## Gold Room Ownership

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Pickup ownership | Exact room; same area; no room binding | Exact room |
| Pack after movement | Continue packing; cancel packing; wait for settlement | Continue packing |
| Duplicate gold signal | Coalesce; restart lifecycle; queue another pickup | Coalesce |
| Missing room identity | Defer and revalidate; use last room; pick up immediately | Defer and revalidate |

**Notes:** Pickup is room-owned; confirmed packing is inventory-owned. Uncertain or stale room data cannot send pickup commands.

---

## Autowalk Movement Safety

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Movement gate | Complete all-clear; target-clear only; settled plus target-clear | Complete all-clear |
| Settlement evidence | Same-room GMCP completion; prompt plus room ID; fixed delay | Same-room GMCP completion |
| Missing GMCP recovery | Recover while held; stop automatically; proceed on timeout | Recover while held |
| Movement re-arm | Confirmed room transition; callback alone; retry timer | Confirmed room transition |

**Notes:** Movement requires complete room evidence and produces at most one request per settled room. Recovery is capped and remains fail closed.

---

## Manual Move Semantics

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Command meaning | Safe one-step request; settlement override; full force | Safe one-step request |
| Blocked feedback | Primary reason and unchanged state; full list; silent | Primary reason and unchanged state |
| Duplicate command | Ignore; replace pending; queue another | Ignore |
| Mode after move | Remain active; pause after one room; stop | Remain active |

**Notes:** `boop walk move` follows the automatic safety gate and does not become an implicit override command.

---

## Walker Stop Ownership

| Decision Point | Options Considered | User's Choice |
|----------------|--------------------|---------------|
| Owned versus attached stop | Ownership-aware; always stop all; always detach | Ownership-aware |
| Already queued move | Cancel immediately; finish first; accept late callbacks | Cancel immediately |
| Restart state | Fresh cycle; reuse settled room; resume pending move | Fresh cycle |
| Stop confirmation | Report ownership outcome; generic stopped; no output | Report ownership outcome |

**Notes:** Boop stops what it started and only detaches from independently owned runs. Stop/restart forms a hard generation boundary.

---

## Agent Discretion

- Exact timeout durations, refresh implementation, reason-code names, and test-file organization.
- Exact external walker stop API after confirming the installed integration contract.
- Concise wording that preserves the selected primary-reason and ownership-outcome semantics.

## Deferred Ideas

- Add temporary prefixes and custom attacks after Phase 04 command trust boundaries.
- Verify the successful Infernal hyena maul compact summary during Phase 05 fixture expansion.
