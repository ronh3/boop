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

local function routineLiveFingerprint(message)
  local text = tostring(message or "")
  if text == "tick: no target" then
    return "tick_no_target", text
  end
  if text:find("room_partial", 1, true) then
    return "room_partial", text
  end
  if boop.util.starts(text, "target lost:")
      or text:find("target_lost", 1, true) then
    return "target_removal", text
  end
  return nil, nil
end

local function shouldRenderLiveTrace(message)
  local text = tostring(message or "")
  if boop.util.starts(text, "operation enter:")
      or boop.util.starts(text, "operation exit:")
      or boop.util.starts(text, "interrupt terminal:") then
    return true
  end

  local category, fingerprint = routineLiveFingerprint(text)
  if not category then
    return true
  end

  boop.state.trace.liveRoutine = boop.state.trace.liveRoutine or {}
  if boop.state.trace.liveRoutine[category] == fingerprint then
    return false
  end
  boop.state.trace.liveRoutine[category] = fingerprint
  return true
end

function boop.trace.log(msg)
  if not msg or msg == "" then return end
  if not boop.config or not boop.config.traceEnabled then return end

  boop.state = boop.state or {}
  boop.state.trace.buffer = boop.state.trace.buffer or {}

  local ts = os.date("%H:%M:%S")
  local line = string.format("%s | %s", ts, tostring(msg))
  local buf = boop.state.trace.buffer
  buf[#buf + 1] = line

  local limit = 100
  while #buf > limit do
    table.remove(buf, 1)
  end

  if boop.state.trace.live and shouldRenderLiveTrace(msg) then
    boop.util.info("trace live: " .. line)
  end
end

function boop.trace.show(count)
  boop.state = boop.state or {}
  boop.state.trace.buffer = boop.state.trace.buffer or {}
  local buf = boop.state.trace.buffer
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
  boop.state.trace.buffer = {}
  boop.state.trace.liveRoutine = {}
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

local function copySourceAuthority(authority)
  if type(authority) ~= "table" then
    return false
  end
  return {
    applicationId = tonumber(authority.applicationId),
    roomId = tostring(authority.roomId or ""),
    observationGeneration = tonumber(
      authority.observationGeneration
    ),
  }
end

local function normalizeDispatchOptions(options)
  if type(options) == "table"
      and options.applicationId ~= nil
      and options.sourceAuthority == nil then
    return {
      roomOwned = true,
      sourceAuthority = copySourceAuthority(options),
      outcomeRegistration = false,
      dispatchMode = "",
      standardRetryBudget = nil,
    }
  end
  options = type(options) == "table" and options or {}
  return {
    roomOwned = options.roomOwned == true,
    sourceAuthority = copySourceAuthority(
      options.sourceAuthority
    ),
    outcomeRegistration = type(options.outcomeRegistration) == "table"
        and options.outcomeRegistration
      or false,
    dispatchMode = tostring(options.dispatchMode or ""),
    standardRetryBudget = tonumber(options.standardRetryBudget),
  }
end

local function dispatchAuthorityCurrent(options, boundary)
  if not options.roomOwned then
    return true
  end
  local authority = copySourceAuthority(options.sourceAuthority)
  local valid = authority
    and boop.runtime
    and boop.runtime.validateRoomSourceAuthority
    and boop.runtime.validateRoomSourceAuthority(authority)
    or false
  if not valid and boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "room dispatch rejected: %s | application=%s | room=%s | generation=%s",
      tostring(boundary or "command"),
      tostring(authority and authority.applicationId or ""),
      tostring(authority and authority.roomId or ""),
      tostring(
        authority
          and authority.observationGeneration
          or ""
      )
    ))
  end
  return not not valid
end

local function rawSendCommand(command)
  send(command, false)
end

function boop.executeAction(action, forceQueue, options)
  if not action or action == "" then return false end
  options = normalizeDispatchOptions(options)
  if not dispatchAuthorityCurrent(options, "standard start") then
    return false
  end
  action = prependAssist(action)
  local suppliedRegistration = options.outcomeRegistration
  local kind = type(suppliedRegistration) == "table"
      and tostring(suppliedRegistration.kind or "standard")
    or "standard"
  if kind == "" then kind = "standard" end
  local standardKind = kind == "standard"
  local standardTracked = standardKind
    and boop.config
    and boop.config.enabled ~= false
  if boop.runtime
      and boop.runtime.standardMutationBarrier
      and boop.runtime.standardMutationBarrier() then
    if boop.trace and boop.trace.log then
      boop.trace.log("dispatch held: exact standard lifecycle pending")
    end
    return false
  end

  local queued = boop.config.useQueueing or forceQueue
  if options.dispatchMode == "direct" then
    queued = false
  elseif options.dispatchMode == "queued" then
    queued = true
  end

  local registration = suppliedRegistration
  if standardTracked
      and boop.runtime
      and boop.runtime.beginStandardDispatch then
    registration = boop.runtime.beginStandardDispatch({
      outcomeRegistration = suppliedRegistration,
      mode = queued and "queued" or "direct",
      action = action,
      aliasBinding = action,
      targetId = boop.state
        and boop.state.targeting
        and boop.state.targeting.currentTargetId
        or "",
      sourceAuthority = options.sourceAuthority,
      retryBudget = options.standardRetryBudget,
    })
    if not registration then
      return false
    end
  end

  local function abortStandard(reason)
    if standardTracked
        and boop.runtime
        and boop.runtime.abortStandardDispatch then
      boop.runtime.abortStandardDispatch(registration, reason)
    end
    return false
  end

  local function sendOwned(command, role)
    if registration
        and boop.runtime
        and boop.runtime.registerOutboundExpectation then
      boop.runtime.registerOutboundExpectation(
        registration,
        command,
        role
      )
    end
    if boop.perf.on then
      boop.perf.measure("wire.send", nil, rawSendCommand, command)
    else
      rawSendCommand(command)
    end
  end

  if queued then
    boop.state = boop.state or {}
    local queuedAction = action

    if boop.state.queue.aliasDirty == nil then
      boop.state.queue.aliasDirty = true
    end

    local lastAction = boop.state.queue.aliasAction or ""
    if boop.state.queue.aliasDirty or lastAction ~= queuedAction then
      if not dispatchAuthorityCurrent(options, "standard alias") then
        return abortStandard("standard alias authority changed")
      end
      sendOwned("setalias BOOP_ATTACK " .. queuedAction, "control")
      boop.state.queue.aliasAction = queuedAction
      boop.state.queue.aliasDirty = false
    end
    if not dispatchAuthorityCurrent(options, "standard queue") then
      return abortStandard("standard queue authority changed")
    end
    sendOwned(
      "queue addclearfull freestand BOOP_ATTACK",
      "baseline"
    )
    if standardTracked
        and boop.runtime
        and boop.runtime.completeStandardDispatch then
      boop.runtime.completeStandardDispatch(registration, {
        mode = "queued",
        aliasBinding = queuedAction,
      })
    end
    if standardKind
        and boop.gag
        and boop.gag.noteStandardIntent then
      boop.gag.noteStandardIntent(action)
    end
    boop.trace.log(
      (standardKind and "std queue: " or "rage queue: ")
        .. queuedAction
    )
    return true
  else
    local parts = boop.util.split(action, boop.lists.separator or "/")
    local wires = {}
    for _, part in ipairs(parts) do
      local trimmed = boop.util.trim(part)
      if trimmed ~= "" then
        wires[#wires + 1] = trimmed
      end
    end
    local sentAny = false
    for index, wire in ipairs(wires) do
      if not dispatchAuthorityCurrent(
          options,
          standardKind and "standard direct" or "rage direct"
        ) then
        return abortStandard("direct authority changed")
      end
      sendOwned(
        wire,
        index == #wires and "final" or "wire"
      )
      sentAny = true
      boop.trace.log(
        (standardKind and "std direct: " or "rage direct: ")
          .. wire
      )
    end
    if sentAny
        and standardTracked
        and boop.runtime
        and boop.runtime.completeStandardDispatch then
      boop.runtime.completeStandardDispatch(registration, {
        mode = "direct",
        aliasBinding = action,
      })
    end
    if sentAny and standardKind then
      if boop.gag and boop.gag.noteStandardIntent then
        boop.gag.noteStandardIntent(action)
      end
      markUnnamableMaulUsed(action)
    elseif not sentAny and standardTracked then
      abortStandard("standard produced no wire commands")
    end
    return sentAny
  end
end

function boop.executeRageAction(action, options)
  if not action or action == "" then return false end
  options = type(options) == "table" and options or {}
  local registration = type(options.outcomeRegistration) == "table"
      and options.outcomeRegistration
    or (
      boop.runtime
      and boop.runtime.newOutboundRegistration
      and boop.runtime.newOutboundRegistration("rage")
      or {}
    )
  options = {
    roomOwned = options.roomOwned == true,
    sourceAuthority = options.sourceAuthority,
    dispatchMode = "direct",
    outcomeRegistration = {
      owner = registration.owner,
      generation = registration.generation,
      dispatchId = registration.dispatchId,
      kind = "rage",
    },
  }
  return boop.executeAction(action, false, options)
end
