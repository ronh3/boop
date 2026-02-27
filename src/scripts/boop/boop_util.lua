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
    cecho("\n<green>boop<reset>: " .. msg)
  else
    echo("\nboop: " .. msg)
  end
end

function boop.util.safeLower(s)
  if not s then return "" end
  return string.lower(s)
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
    boop.util.echo("trace: (empty)")
    return
  end

  local n = tonumber(count) or 20
  if n < 1 then n = 1 end
  if n > total then n = total end
  boop.util.echo(string.format("trace: showing %d/%d", n, total))
  for i = total - n + 1, total do
    boop.util.echo("  " .. tostring(buf[i]))
  end
end

function boop.trace.clear()
  boop.state = boop.state or {}
  boop.state.traceBuffer = {}
  boop.util.echo("trace: cleared")
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

function boop.executeAction(action, forceQueue)
  if not action or action == "" then return end

  if boop.config.useQueueing or forceQueue then
    boop.state = boop.state or {}
    local queuedAction = action
    if boop.config.useQueueing and boop.state.autoGrabGoldPending then
      local normalized = boop.util.safeLower(boop.util.trim(queuedAction))
      if normalized ~= "get sovereigns" and not boop.util.starts(normalized, "get sovereigns/") then
        local prefix = "get sovereigns"
        local pack = boop.util.trim(boop.config.goldPack or "")
        if boop.markGoldQueueIntent then
          boop.markGoldQueueIntent(pack)
        end
        if pack ~= "" then
          prefix = prefix .. "/put sovereigns in " .. pack
        end
        queuedAction = prefix .. "/" .. queuedAction
      end
      if boop.state.autoGrabGoldTimer then
        killTimer(boop.state.autoGrabGoldTimer)
        boop.state.autoGrabGoldTimer = nil
      end
      boop.state.autoGrabGoldPending = false
      boop.state.goldDropped = false
    end

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
  local parts = boop.util.split(action, boop.lists.separator or "/")
  for _, part in ipairs(parts) do
    local trimmed = boop.util.trim(part)
    if trimmed ~= "" then
      send(trimmed, false)
      boop.trace.log("rage direct: " .. trimmed)
    end
  end
end
