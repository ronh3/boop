boop.util = boop.util or {}

function boop.util.trim(s)
  if not s then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function boop.util.starts(s, prefix)
  if not s or not prefix then return false end
  return s:sub(1, #prefix) == prefix
end

function boop.util.contains(list, value)
  if not list then return false end
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

function boop.util.split(s, sep)
  sep = sep or "/"
  local parts = {}
  if not s or s == "" then return parts end
  for part in string.gmatch(s, "[^" .. sep .. "]+") do
    parts[#parts + 1] = part
  end
  return parts
end

function boop.util.echo(msg)
  msg = msg or ""
  if cecho then
    local theme = boop.theme and boop.theme.tags and boop.theme.tags() or nil
    local accent = theme and theme.accent or "<green>"
    local text = theme and theme.text or "<white>"
    local border = theme and theme.border or "<grey>"
    local reset = theme and theme.reset or "<reset>"
    cecho("\n" .. accent .. "boop" .. reset .. " " .. border .. "::" .. reset .. " " .. text .. msg .. reset)
  else
    echo("\nboop: " .. msg)
  end
end

local FEEDBACK_STYLE = {
  INFO = { themeKey = "info", textKey = "text", fallbackTag = "cyan", fallbackText = "white" },
  OK = { themeKey = "ok", textKey = "text", fallbackTag = "green", fallbackText = "white" },
  WARN = { themeKey = "warn", textKey = "text", fallbackTag = "yellow", fallbackText = "white" },
  ERR = { themeKey = "err", textKey = "text", fallbackTag = "red", fallbackText = "white" },
}

function boop.util.feedback(kind, msg)
  local k = boop.util.safeUpper and boop.util.safeUpper(kind) or tostring(kind or "INFO"):upper()
  local style = FEEDBACK_STYLE[k] or FEEDBACK_STYLE.INFO
  msg = tostring(msg or "")
  if cecho then
    local theme = boop.theme and boop.theme.tags and boop.theme.tags() or nil
    local accent = theme and theme.accent or "<green>"
    local border = theme and theme.border or "<grey>"
    local tagColor = theme and theme[style.themeKey] or ("<" .. style.fallbackTag .. ">")
    local textColor = theme and theme[style.textKey] or ("<" .. style.fallbackText .. ">")
    local reset = theme and theme.reset or "<reset>"
    cecho(string.format("\n%sboop%s %s[%s%s%s]%s %s%s%s",
      accent, reset,
      border, tagColor, k, border, reset,
      textColor, msg, reset))
  else
    echo(string.format("\nboop [%s]: %s", k, msg))
  end
end

function boop.util.info(msg)
  boop.util.feedback("INFO", msg)
end

function boop.util.ok(msg)
  boop.util.feedback("OK", msg)
end

function boop.util.warn(msg)
  boop.util.feedback("WARN", msg)
end

function boop.util.err(msg)
  boop.util.feedback("ERR", msg)
end

function boop.util.safeLower(s)
  if not s then return "" end
  return string.lower(s)
end

function boop.util.safeUpper(s)
  if not s then return "" end
  return string.upper(s)
end

function boop.util.formatTarget(cmd, target)
  if not cmd then return "" end
  if not target then target = "" end
  local formatted = cmd:gsub("&tar", target)
  formatted = formatted:gsub("@tar", target)
  return formatted
end

boop.trace = boop.trace or {}

function boop.trace.log(msg)
  if not msg or msg == "" then return end
  if not boop.config or not boop.config.traceEnabled then return end

  boop.state = boop.state or {}
  boop.state.traceBuffer = boop.state.traceBuffer or {}

  local ts = os.date("%H:%M:%S")
  local line = string.format("%s | %s", ts, tostring(msg))
  local buf = boop.state.traceBuffer
  buf[#buf + 1] = line

  local limit = 100
  while #buf > limit do
    table.remove(buf, 1)
  end
end

function boop.trace.show(count)
  boop.state = boop.state or {}
  boop.state.traceBuffer = boop.state.traceBuffer or {}
  local buf = boop.state.traceBuffer
  local total = #buf
  if total == 0 then
    boop.util.info("trace: (empty)")
    return
  end

  local n = tonumber(count) or 20
  if n < 1 then n = 1 end
  if n > total then n = total end
  boop.util.info(string.format("trace: showing %d/%d", n, total))
  for i = total - n + 1, total do
    boop.util.info("  " .. tostring(buf[i]))
  end
end

function boop.trace.clear()
  boop.state = boop.state or {}
  boop.state.traceBuffer = {}
  boop.util.ok("trace: cleared")
end

local function markUnnamableMaulUsed(action)
  if not action or action == "" then return end
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then return end
  local class = boop.util.safeLower(gmcp.Char.Status.class or "")
  if class ~= "unnamable" and class ~= "infernal" then return end

  local normalized = boop.util.safeLower(action)
  local parts = boop.util.split(normalized, boop.lists.separator or "/")
  for _, part in ipairs(parts) do
    local trimmed = boop.util.trim(part)
    if boop.util.starts(trimmed, "hyena maul ")
      or boop.util.starts(trimmed, "hound maul ")
      or boop.util.starts(trimmed, "maul ")
      or boop.util.starts(trimmed, "dominion maul ")
    then
      if boop.rage and boop.rage.setReady then
        boop.rage.setReady("maul", false)
      end
      return
    end
  end
end

local function assistLeader()
  if not boop or not boop.config then
    return ""
  end
  return boop.util.trim(boop.config.assistLeader or "")
end

local function assistEnabled()
  return not not (boop and boop.config and boop.config.assistEnabled and assistLeader() ~= "")
end

local function prependAssist(action)
  local leader = assistLeader()
  if not assistEnabled() or leader == "" or not action or action == "" then
    return action
  end

  local normalized = boop.util.safeLower(boop.util.trim(action))
  if boop.util.starts(normalized, "assist ") then
    return action
  end
  return "assist " .. leader .. "/" .. action
end

function boop.executeAction(action, forceQueue)
  if not action or action == "" then return end
  action = prependAssist(action)

  if boop.config.useQueueing or forceQueue then
    boop.state = boop.state or {}
    if boop.config.useQueueing and boop.state.autoGrabGoldPending then
      if boop.flushPendingGold then
        boop.flushPendingGold("std queue handoff")
      end
      boop.trace.log("std queue blocked: gold pending")
      return
    end
    if boop.config.useQueueing and (boop.state.goldGetPending or boop.state.goldPutPending) then
      boop.trace.log("std queue blocked: gold pending")
      return
    end
    local queuedAction = action

    if boop.state.queueAliasDirty == nil then
      boop.state.queueAliasDirty = true
    end

    local lastAction = boop.state.queueAliasAction or ""
    if boop.state.queueAliasDirty or lastAction ~= queuedAction then
      send("setalias BOOP_ATTACK " .. queuedAction, false)
      boop.state.queueAliasAction = queuedAction
      boop.state.queueAliasDirty = false
    end
    send("queue addclearfull freestand BOOP_ATTACK", false)
    boop.trace.log("std queue: " .. queuedAction)
    markUnnamableMaulUsed(queuedAction)
  else
    local parts = boop.util.split(action, boop.lists.separator or "/")
    for _, part in ipairs(parts) do
      local trimmed = boop.util.trim(part)
      if trimmed ~= "" then
        send(trimmed, false)
        boop.trace.log("std direct: " .. trimmed)
      end
    end
    markUnnamableMaulUsed(action)
  end
end

function boop.executeRageAction(action)
  if not action or action == "" then return end
  action = prependAssist(action)
  local parts = boop.util.split(action, boop.lists.separator or "/")
  for _, part in ipairs(parts) do
    local trimmed = boop.util.trim(part)
    if trimmed ~= "" then
      send(trimmed, false)
      boop.trace.log("rage direct: " .. trimmed)
    end
  end
end
