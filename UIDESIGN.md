Configuration UI Design Specification

Overview

This document defines the architecture and behavior of a configuration UI for boop.

The UI is:
- Inline-first
- Namespace-scoped (`boop config` prefix required)
- Keyboard-driven
- Mouse-enhanced (optional miniwindow)
- Designed for non-technical public users
- Limited to approximately 20 settings

The UI must not intercept or consume bare numeric input.

Current product state

- `boop` is now the home dashboard.
- `boop control` is the live control dashboard.
- `boop config` is the guided settings hub.
- `boop party` is the party dashboard for leader, assist, and walk state.
- `boop stats` is the optimization/stats dashboard.
- `boop help` is a curated workflow-oriented help surface.
- `boop roster` is separate from `boop party`.
- `boop preset solo|party|leader-call` exists as a shortcut for recommended baseline setups.

This file still documents the config system in detail, but new UX work should preserve coherence across all of the above surfaces rather than treating `boop config` as the entire UI.

Core Design Principles

- No global hotkeys.
- No modal input capture.
- All config commands require the `boop config` prefix.
- Instant apply for setting changes.
- Confirmation required only for destructive actions.
- Alignment and visual consistency are mandatory.
- Miniwindow is optional enhancement only. Inline must be fully functional.

Command Grammar

Prefix: `boop config`

Base commands
- `boop config`
  - Redraw current view (home or active section).
- `boop config home`
  - Show section list.
- `boop config back`
  - Return to previous level.
- `boop config help`
  - Display usage summary.

Related top-level surfaces
- `boop`
  - Home dashboard.
- `boop control`
  - Live control dashboard.
- `boop party`
  - Party dashboard.
- `boop stats`
  - Stats dashboard and drill-down entrypoint.
- `boop help`
  - Reference/help entrypoint.

Navigation
- `boop config <section>`
- `boop config <number>` (from home view)
- Both open a section.

Setting activation (inside section)
- `boop config <number>`
- Behavior depends on setting type:
  - Boolean: toggle immediately.
  - Enum: cycle to next value.
  - Number: arm pending value input and print usage.
  - String: arm pending value input and print usage.
  - Action: initiate confirmation flow.

Non-modal value entry
- `boop config value <value>`
  - Valid only when a pending number/string setting is armed.
  - Applies to the armed setting, validates, confirms, redraws.
- `boop config set <key> <value>` (optional power feature)
  - Direct key/value write path without index navigation.

Important: "prompt for value" means "print instructions and wait for explicit prefixed command." It does not capture free-typed input.

Confirmation flow
- `boop config confirm`
- `boop config cancel`

Rendering Specification (Inline)

Layout structure
- Header:
  - `CONFIGURATION`
  - or `CONFIGURATION > <Section>`
- Divider:
  - Single muted grey line
  - Consistent width
- Groups:
  - Group title in cyan, uppercase
  - No blank lines between settings
  - One blank line between groups
- Footer:
  - Single line instruction summary
  - In rich Mudlet rendering, footer commands should be clickable.

Alignment rules
- Constants:
  - `LABEL_COL_WIDTH = 28`
  - `BUTTON_COL_WIDTH = 12`
- Row format:
  - `[n] <label padded to LABEL_COL_WIDTH> <button padded to BUTTON_COL_WIDTH>`
- Example:
  - `[3] Limb tracking               [ OFF ]`
- Rules:
  - Labels left-aligned and padded with spaces.
  - Button column should begin at the same character position within a section, using the longest visible label in that section as the alignment anchor when practical.
  - Button must always be bracketed.
  - Button width must remain constant.
  - Pad plain text first, then apply color to button content only.

Current visual language expectations

- Sectioned dashboards should use the shared themed row renderer where available.
- Rich Mudlet screens should prefer concise rows with hover hints over long visible prose.
- Plain-text fallback should remain readable and deterministic for tests.
- Older raw/debug-dump output should be treated as technical debt and cleaned up when touched.

Button rendering
- Format: `[ <value> ]`
- Color rules:
  - Only button content is colorized.
  - `ON` = green
  - `OFF` = red
  - Modified-from-default = yellow
  - Disabled/unavailable = grey
- Text must remain readable without color.

Setting Types

Boolean
- Values: `ON` / `OFF`
- `boop config n` toggles immediately
- Print confirmation message
- Redraw section

Enum
- `boop config n` cycles to next valid value
- `boop config set key value` sets directly
- Print confirmation
- Redraw section

Number
- `boop config n` arms pending value input and prints:
  - `boop config value <number>`
- Validate against defined range
- On invalid: print error, no change
- On valid: apply immediately, confirm, redraw

String
- `boop config n` arms pending value input and prints:
  - `boop config value <text>`
- Apply immediately
- Confirm and redraw

Action
- Requires confirmation flow

Confirmation Flow

Triggered by destructive actions:
- `reset section`
- `reset all`
- `import overwrite`

Flow:
1. Print warning message.
2. Display: `Type: boop config confirm | boop config cancel`
3. Store one pending action.
4. `boop config confirm` executes action.
5. `boop config cancel` clears pending state.

Pending confirmation rules:
- Expires after one use.
- No modal blocking allowed.
- Clears on any command except:
  - `boop config confirm`
  - `boop config cancel`
  - `boop config help`

Data Model

UI session state
- `current_view` (`home` | `section`)
- `current_section_id` (string or nil)
- `pending_confirm_action` (function/id or nil)
- `pending_value_setting_id` (string or nil)
- `pending_value_type` (`number` | `string` | nil)

Setting object fields
- `id` (string)
- `label` (string)
- `type` (`boolean` | `enum` | `number` | `string` | `action`)
- `section` (string)
- `group` (string)
- `default` (value)
- `value` (current value)
- `valid` (enum list or number range)
- `description` (string)
- `requires_confirm` (boolean)
- `on_change` (optional function hook)

Section object fields
- `id` (string)
- `label` (string)
- ordered list of settings

Numbering
- Assigned dynamically per section
- Reset numbering inside each section

Miniwindow Enhancement (Optional)

Miniwindow must:
- Render same sections and settings
- Provide clickable section navigation
- Provide clickable buttons
- Provide hover tooltip showing description/default/valid values
- Not introduce functionality unavailable in inline mode

Keyboard commands must remain fully functional regardless of miniwindow state.

Acceptance Criteria

System is complete when:
- `boop config` redraws current view
- Bare numeric input does not change settings
- Navigation works via `boop config <section>` and `boop config <number>`
- Boolean toggles apply instantly
- Number and string inputs validate correctly
- Modified values visibly differ from defaults
- Confirmation flow works correctly
- Layout alignment remains consistent at 80 columns
- Miniwindow (if enabled) mirrors inline functionality
- All persisted values survive package reload/reconnect and redraw identically
  - except explicitly session-local values such as `partySize`

Release-phase guidance

- New UX changes should bias toward discoverability, consistency, and operator clarity.
- Avoid introducing parallel menu systems or one-off layouts when an existing dashboard pattern fits.
- If a new command changes the operator workflow, update `boop help`, `README.md`, and the relevant dashboard entrypoints together.

Implementation Order

1. Data model and storage
2. Inline renderer
3. Command parser
4. Setting activation logic
5. Confirmation system
6. Miniwindow renderer
