boop.wire = boop.wire or {}
boop.wire.separator = boop.wire.separator or "/"

local function markUnnamableMaulUsed(action)
  if not action or action == "" then return end
  if not gmcp or not gmcp.Char or not gmcp.Char.Status then return end
  local class = boop.util.safeLower(gmcp.Char.Status.class or "")
  if class ~= "unnamable" and class ~= "infernal" then return end

  local normalized = boop.util.safeLower(action)
  local parts = boop.util.split(normalized, boop.wire.separator)
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
    observationGeneration = tonumber(authority.observationGeneration),
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
    sourceAuthority = copySourceAuthority(options.sourceAuthority),
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
    and boop.room
    and boop.room.validateRoomSourceAuthority
    and boop.room.validateRoomSourceAuthority(authority)
    or false
  if not valid and boop.trace and boop.trace.log then
    boop.trace.log(string.format(
      "room dispatch rejected: %s | application=%s | room=%s | generation=%s",
      tostring(boundary or "command"),
      tostring(authority and authority.applicationId or ""),
      tostring(authority and authority.roomId or ""),
      tostring(authority and authority.observationGeneration or "")
    ))
  end
  return not not valid
end

local function rawSendCommand(command)
  send(command, false)
end

function boop.wire.executeAction(action, targetId, forceQueue, options)
  if not action or action == "" then return false end
  targetId = tostring(targetId or "")
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
      targetId = targetId,
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
      boop.runtime.registerOutboundExpectation(registration, command, role)
    end
    if boop.perf.on then
      boop.perf.measure("wire.send", nil, rawSendCommand, command)
    else
      rawSendCommand(command)
    end
  end

  if queued then
    local queuedAction = action
    local alias = boop.runtime.standardAliasBinding()
    if alias.dirty or alias.action ~= queuedAction then
      if not dispatchAuthorityCurrent(options, "standard alias") then
        return abortStandard("standard alias authority changed")
      end
      sendOwned("setalias BOOP_ATTACK " .. queuedAction, "control")
      boop.runtime.recordStandardAliasBinding(queuedAction, false)
    end
    if not dispatchAuthorityCurrent(options, "standard queue") then
      return abortStandard("standard queue authority changed")
    end
    sendOwned("queue addclearfull freestand BOOP_ATTACK", "baseline")
    if standardTracked
        and boop.runtime
        and boop.runtime.completeStandardDispatch then
      boop.runtime.completeStandardDispatch(registration, {
        mode = "queued",
        aliasBinding = queuedAction,
      })
    end
    boop.trace.log((standardKind and "std queue: " or "rage queue: ") .. queuedAction)
    return true
  end

  local parts = boop.util.split(action, boop.wire.separator)
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
    sendOwned(wire, index == #wires and "final" or "wire")
    sentAny = true
    boop.trace.log((standardKind and "std direct: " or "rage direct: ") .. wire)
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
    markUnnamableMaulUsed(action)
  elseif not sentAny and standardTracked then
    abortStandard("standard produced no wire commands")
  end
  return sentAny
end

function boop.wire.executeRageAction(action, targetId, options)
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
  return boop.wire.executeAction(action, targetId, false, options)
end
