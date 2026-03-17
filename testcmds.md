# Help Test Commands

Use this as a quick way to exercise the current `boop help` surface in live Mudlet.

## Mudlet Alias

Pattern:

```text
^boophelptest$
```

Script:

```lua
local commands = {
  "boop help",
  "boop help home",
  "boop help 1",
  "boop help 2",
  "boop help 3",
  "boop help 4",
  "boop help 5",
  "boop help 6",
  "boop help start",
  "boop help control",
  "boop help hunting",
  "boop help party",
  "boop help stats",
  "boop help diagnostics",
  "boop help unknown",
}

cecho("\n<cyan>Running boop help test sweep (" .. #commands .. " commands)...<reset>\n")

for i, cmd in ipairs(commands) do
  tempTimer((i - 1) * 0.35, function()
    cecho(string.format("\n<yellow>[%02d/%02d]<reset> %s\n", i, #commands, cmd))
    send(cmd, false)
  end)
end
```

## What It Covers

- `boop help`
- `boop help home`
- every numbered help topic
- every canonical topic key:
  - `start`
  - `control`
  - `hunting`
  - `party`
  - `stats`
  - `diagnostics`
- one invalid topic path:
  - `boop help unknown`

## Raw Manual List

```text
boop help
boop help home
boop help 1
boop help 2
boop help 3
boop help 4
boop help 5
boop help 6
boop help start
boop help control
boop help hunting
boop help party
boop help stats
boop help diagnostics
boop help unknown
```
