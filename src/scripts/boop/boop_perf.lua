boop.perf = boop.perf or {}

-- Source reloads are common in the test profile and during development.
-- Unwrap the previous generation before replacing its registration table.
if type(boop.perf._registrations) == "table" then
  for index = #boop.perf._registrations, 1, -1 do
    local registration = boop.perf._registrations[index]
    if type(registration) == "table"
        and registration.wrapper
        and type(registration.target) == "table"
        and registration.target[registration.key] == registration.wrapper then
      registration.target[registration.key] = registration.original
    end
  end
end

local MAX_ACTIVE_DEPTH = 8
local unpackValues = table.unpack or unpack
local HISTOGRAM_LIMITS = { 0.00005, 0.0001, 0.00025, 0.0005, 0.001, 0.0025, 0.01 }
local HISTOGRAM_LABELS = {
  "<0.05ms", "<0.1ms", "<0.25ms", "<0.5ms",
  "<1ms", "<2.5ms", "<10ms", ">=10ms",
}
local PROBE_SPECS = {
  { "prompt_total", "wall" },
  { "prompt.callback", "wall" },
  { "tick", "wall" },
  { "context", "cpu" },
  { "targets.choose", "cpu" },
  { "attacks.plan", "cpu" },
  { "attacks.selectRage", "cpu" },
  { "attacks.applyModifiers", "cpu" },
  { "prequeue.schedule", "wall" },
  { "prequeue.standard", "wall" },
  { "prequeue.refresh", "wall" },
  { "gmcp.Char.Afflictions.List", "wall" },
  { "gmcp.Char.Items.List", "wall" },
  { "gmcp.Char.Items.Add", "wall" },
  { "gmcp.Char.Items.Remove", "wall" },
  { "gmcp.Char.Items.Update", "wall" },
  { "gmcp.Room.Info", "wall" },
  { "gmcp.IRE.Display.ButtonActions", "wall" },
  { "gmcp.IRE.Display.FixedFont", "wall" },
  { "gmcp.IRE.Display.Ohmap", "wall" },
  { "gmcp.IRE.Target.Set", "wall" },
  { "gmcp.IRE.Target.Info", "wall" },
  { "gmcp.Char.Status", "wall" },
  { "gmcp.Char.Vitals", "wall" },
  { "gmcp.Char.Skills.Groups", "wall" },
  { "gmcp.Char.Skills.List", "wall" },
  { "gmcp.Char.Skills.Info", "wall" },
  { "sysDataSendRequest", "wall" },
  { "sysConnectionEvent", "wall" },
  { "demonwalker.arrived", "wall" },
  { "demonwalker.finished", "wall" },
  { "db.saveStats", "wall" },
  { "db.saveConfig", "wall" },
  { "db.recordMobXpObservation", "wall" },
  { "combatlog.line", "cpu" },
  { "applyEffects", "wall" },
  { "wire.send", "wall" },
}
local COUNTER_NAMES = {
  "ticks_suppressed_by_limiter",
  "contexts_built",
  "deepcopy_items",
  "stats_flushes",
}

local PROBE_CLOCKS = {}
local PROBE_ORDER = {}
local COUNTER_SET = {}
for index, spec in ipairs(PROBE_SPECS) do
  PROBE_ORDER[index] = spec[1]
  PROBE_CLOCKS[spec[1]] = spec[2]
end
for _, name in ipairs(COUNTER_NAMES) do COUNTER_SET[name] = true end

local function wallNow()
  if type(getEpoch) == "function" then return tonumber(getEpoch()) or 0 end
  return 0
end

local function cpuNow()
  return tonumber(os.clock()) or 0
end

local function bucketIndex(seconds)
  for index, limit in ipairs(HISTOGRAM_LIMITS) do
    if seconds < limit then return index end
  end
  return 8
end

local function normalizeTickSource(source)
  if source == "vitals" or source == "prompt" or source == "target"
      or source == "room" or source == "walk" or source == "charstatus" then
    return source
  end
  return "other"
end

local function newRecord(name, clock, id)
  local record = {
    id = id,
    name = name,
    clock = clock,
    count = 0,
    totalSeconds = 0,
    maxSeconds = 0,
    lastSeconds = 0,
    lastPromptSeq = 0,
    depth = 0,
    starts = {},
    tokenIds = {},
    promptSeqs = {},
    sourceKeys = {},
    histogram = { 0, 0, 0, 0, 0, 0, 0, 0 },
  }
  for depth = 1, MAX_ACTIVE_DEPTH do
    record.starts[depth] = 0
    record.tokenIds[depth] = 0
    record.promptSeqs[depth] = 0
    record.sourceKeys[depth] = false
  end
  if name == "tick" then
    record.sources = {
      vitals = 0, prompt = 0, target = 0, room = 0,
      walk = 0, charstatus = 0, other = 0,
    }
  end
  return record
end

local function resetCorrelation()
  boop.perf.promptSeq = 0
  boop.perf.completedPromptEpochs = 0
  boop.perf.correlatedTicks = 0
  boop.perf.correlationMode = false
  boop.perf.pendingVitalsSeconds = 0
  boop.perf.pendingVitalsTicks = 0
  boop.perf.pendingVitalsSegments = 0
  boop.perf.openPrompt = false
  boop.perf._activeCallback = false
  boop.perf._activeCallbackTicks = 0
end

local function allocateStorage()
  local records = {}
  local recordsById = {}
  for index, spec in ipairs(PROBE_SPECS) do
    local record = newRecord(spec[1], spec[2], index)
    records[spec[1]] = record
    recordsById[index] = record
  end
  local counters = {}
  for _, name in ipairs(COUNTER_NAMES) do counters[name] = 0 end
  boop.perf._records = records
  boop.perf._recordsById = recordsById
  boop.perf._counters = counters
  boop.perf._nextToken = 0
  boop.perf.droppedSpans = 0
end

local function ensureStorage()
  if type(boop.perf._records) ~= "table"
      or type(boop.perf._counters) ~= "table" then
    allocateStorage()
  end
end

local function recordNow(record)
  if record.clock == "cpu" then return cpuNow() end
  return wallNow()
end

local function recordElapsed(record, elapsed, promptSeq, source)
  elapsed = math.max(0, tonumber(elapsed) or 0)
  record.count = record.count + 1
  record.totalSeconds = record.totalSeconds + elapsed
  record.lastSeconds = elapsed
  if elapsed > record.maxSeconds then record.maxSeconds = elapsed end
  record.lastPromptSeq = tonumber(promptSeq) or 0
  local bucket = bucketIndex(elapsed)
  record.histogram[bucket] = record.histogram[bucket] + 1
  if source and record.sources then
    record.sources[source] = record.sources[source] + 1
  end
end

function boop.perf.enter(name, source)
  if boop.perf.on ~= true then return false end
  ensureStorage()
  local record = boop.perf._records[name]
  if not record then return false end
  if record.depth >= MAX_ACTIVE_DEPTH then
    boop.perf.droppedSpans = boop.perf.droppedSpans + 1
    return false
  end

  boop.perf._nextToken = boop.perf._nextToken + 1
  local token = record.id * 1000000000 + boop.perf._nextToken
  local depth = record.depth + 1
  record.depth = depth
  record.starts[depth] = recordNow(record)
  record.tokenIds[depth] = token
  record.promptSeqs[depth] = tonumber(boop.perf.promptSeq) or 0
  record.sourceKeys[depth] = name == "tick"
    and normalizeTickSource(source)
    or false
  return token
end

function boop.perf.exit(token)
  if boop.perf.on ~= true or type(token) ~= "number" then return false end
  local probeId = math.floor(token / 1000000000)
  local record = boop.perf._recordsById
    and boop.perf._recordsById[probeId]
    or nil
  if not record or record.depth <= 0 then return false end
  local depth = record.depth
  if record.tokenIds[depth] ~= token then return false end

  local elapsed = recordNow(record) - (tonumber(record.starts[depth]) or 0)
  local source = record.sourceKeys[depth]
  local promptSeq = record.promptSeqs[depth]
  record.depth = depth - 1
  record.starts[depth] = 0
  record.tokenIds[depth] = 0
  record.promptSeqs[depth] = 0
  record.sourceKeys[depth] = false
  recordElapsed(record, elapsed, promptSeq, source)

  if record.name == "tick"
      and (boop.perf._activeCallback == "vitals"
        or boop.perf._activeCallback == "prompt") then
    boop.perf._activeCallbackTicks =
      (tonumber(boop.perf._activeCallbackTicks) or 0) + 1
  end
  return math.max(0, elapsed)
end

local function pack(...)
  return { n = select("#", ...), ... }
end

local function invokeMeasured(name, source, callbackKind, fn, ...)
  local args = pack(...)
  local token = boop.perf.enter(name, source)
  local priorCallback = boop.perf._activeCallback
  local priorTicks = boop.perf._activeCallbackTicks
  if callbackKind then
    boop.perf._activeCallback = callbackKind
    boop.perf._activeCallbackTicks = 0
    if callbackKind == "prompt" then
      boop.perf.promptSeq = (tonumber(boop.perf.promptSeq) or 0) + 1
    end
  end
  local results = pack(xpcall(function()
    return fn(unpackValues(args, 1, args.n))
  end, function(err)
    return err
  end))
  local callbackTicks = tonumber(boop.perf._activeCallbackTicks) or 0
  if callbackKind then
    boop.perf._activeCallback = priorCallback
    boop.perf._activeCallbackTicks = priorTicks
  end
  local elapsed = boop.perf.exit(token)
  if callbackKind then
    boop.perf._completeCallback(callbackKind, tonumber(elapsed) or 0, callbackTicks)
  end
  if not results[1] then error(results[2], 0) end
  return unpackValues(results, 2, results.n)
end

function boop.perf.measure(name, source, fn, ...)
  if boop.perf.on ~= true then return fn(...) end
  return invokeMeasured(name, source, false, fn, ...)
end

local function commitPromptEpoch(seconds, ticks, promptSeq)
  recordElapsed(boop.perf._records.prompt_total, seconds, promptSeq, false)
  boop.perf.completedPromptEpochs =
    (tonumber(boop.perf.completedPromptEpochs) or 0) + 1
  boop.perf.correlatedTicks =
    (tonumber(boop.perf.correlatedTicks) or 0) + (tonumber(ticks) or 0)
end

function boop.perf._completeCallback(kind, seconds, ticks)
  if kind == "vitals" then
    if boop.perf.correlationMode == "trailing"
        and type(boop.perf.openPrompt) == "table" then
      boop.perf.openPrompt.seconds = boop.perf.openPrompt.seconds + seconds
      boop.perf.openPrompt.ticks = boop.perf.openPrompt.ticks + ticks
      boop.perf.openPrompt.vitalsSegments =
        boop.perf.openPrompt.vitalsSegments + 1
    else
      boop.perf.pendingVitalsSeconds =
        (tonumber(boop.perf.pendingVitalsSeconds) or 0) + seconds
      boop.perf.pendingVitalsTicks =
        (tonumber(boop.perf.pendingVitalsTicks) or 0) + ticks
      boop.perf.pendingVitalsSegments =
        (tonumber(boop.perf.pendingVitalsSegments) or 0) + 1
    end
    return
  end
  if kind ~= "prompt" then return end

  local promptSeq = tonumber(boop.perf.promptSeq) or 0
  if not boop.perf.correlationMode then
    boop.perf.correlationMode = boop.perf.pendingVitalsSegments > 0
      and "leading"
      or "trailing"
  end
  if boop.perf.correlationMode == "leading" then
    commitPromptEpoch(
      boop.perf.pendingVitalsSeconds + seconds,
      boop.perf.pendingVitalsTicks + ticks,
      promptSeq
    )
    boop.perf.pendingVitalsSeconds = 0
    boop.perf.pendingVitalsTicks = 0
    boop.perf.pendingVitalsSegments = 0
    return
  end

  if type(boop.perf.openPrompt) == "table" then
    commitPromptEpoch(
      boop.perf.openPrompt.seconds,
      boop.perf.openPrompt.ticks,
      boop.perf.openPrompt.promptSeq
    )
  end
  boop.perf.openPrompt = {
    seconds = seconds,
    ticks = ticks,
    promptSeq = promptSeq,
    vitalsSegments = 0,
  }
end

function boop.perf.count(name, amount)
  if boop.perf.on ~= true or not COUNTER_SET[name] then return false end
  ensureStorage()
  boop.perf._counters[name] = boop.perf._counters[name]
    + (tonumber(amount) or 1)
  return true
end

local function installRegistration(registration)
  if registration.wrapper then return end
  local original = registration.target[registration.key]
  if type(original) ~= "function" then return end
  registration.original = original
  registration.wrapper = function(...)
    if boop.perf.on ~= true then return original(...) end
    local name = registration.name
    if registration.nameResolver then
      name = registration.nameResolver(...)
      if not name then return original(...) end
    end
    local source = registration.sourceIndex
      and select(registration.sourceIndex, ...)
      or registration.source
    return invokeMeasured(
      name,
      source,
      registration.callback,
      original,
      ...
    )
  end
  registration.target[registration.key] = registration.wrapper
end

local function uninstallRegistration(registration)
  if registration.wrapper
      and registration.target[registration.key] == registration.wrapper then
    registration.target[registration.key] = registration.original
  end
  registration.original = false
  registration.wrapper = false
end

function boop.perf.register(name, target, key, options)
  if type(target) ~= "table" or type(key) ~= "string" then return false end
  options = type(options) == "table" and options or {}
  local registration = {
    name = name,
    target = target,
    key = key,
    source = options.source,
    sourceIndex = options.sourceIndex,
    callback = options.callback,
    nameResolver = options.nameResolver,
    original = false,
    wrapper = false,
  }
  boop.perf._registrations[#boop.perf._registrations + 1] = registration
  if boop.perf.on == true then installRegistration(registration) end
  return true
end

function boop.perf.reset()
  allocateStorage()
  resetCorrelation()
  return true
end

function boop.perf.setEnabled(enabled)
  enabled = enabled == true
  if enabled == (boop.perf.on == true) then
    if enabled then ensureStorage() end
    return enabled
  end
  if enabled then
    ensureStorage()
    boop.perf.on = true
    for _, registration in ipairs(boop.perf._registrations) do
      installRegistration(registration)
    end
  else
    boop.perf.on = false
    for _, registration in ipairs(boop.perf._registrations) do
      uninstallRegistration(registration)
    end
    local records = boop.perf._records
    if records then
      for _, name in ipairs(PROBE_ORDER) do records[name].depth = 0 end
    end
    resetCorrelation()
  end
  return boop.perf.on
end

local function copyArray(values)
  local out = {}
  for index, value in ipairs(values or {}) do out[index] = value end
  return out
end

local function copyMap(values)
  local out = {}
  for key, value in pairs(values or {}) do out[key] = value end
  return out
end

function boop.perf.snapshot()
  local snapshot = {
    on = boop.perf.on == true,
    promptSeq = tonumber(boop.perf.promptSeq) or 0,
    completedPromptEpochs = tonumber(boop.perf.completedPromptEpochs) or 0,
    correlatedTicks = tonumber(boop.perf.correlatedTicks) or 0,
    correlationMode = boop.perf.correlationMode or false,
    pendingPromptEpoch = type(boop.perf.openPrompt) == "table",
    droppedSpans = tonumber(boop.perf.droppedSpans) or 0,
    records = {},
    counters = {},
    ticksPerPrompt = 0,
  }
  local records = boop.perf._records
  if records then
    for _, name in ipairs(PROBE_ORDER) do
      local record = records[name]
      snapshot.records[name] = {
        name = name,
        clock = record.clock,
        count = record.count,
        totalSeconds = record.totalSeconds,
        maxSeconds = record.maxSeconds,
        lastSeconds = record.lastSeconds,
        lastPromptSeq = record.lastPromptSeq,
        histogram = copyArray(record.histogram),
        sources = copyMap(record.sources),
        activeDepth = record.depth,
      }
    end
  end
  if boop.perf._counters then snapshot.counters = copyMap(boop.perf._counters) end
  if snapshot.completedPromptEpochs > 0 then
    snapshot.ticksPerPrompt = snapshot.correlatedTicks
      / snapshot.completedPromptEpochs
  end
  return snapshot
end

local function outputLine(value)
  local line = tostring(value or "") .. "\n"
  if type(cecho) == "function" then cecho(line)
  elseif type(echo) == "function" then echo(line) end
end

local function percentileLabel(record, percentile)
  if not record or record.count <= 0 then return "n/a" end
  local wanted = math.max(1, math.ceil(record.count * percentile))
  local seen = 0
  for index, count in ipairs(record.histogram) do
    seen = seen + count
    if seen >= wanted then return HISTOGRAM_LABELS[index] end
  end
  return HISTOGRAM_LABELS[8]
end

function boop.perf.show()
  local snapshot = boop.perf.snapshot()
  outputLine("<cyan>BOOP<white> > PERFORMANCE")
  outputLine("<dim_grey>------------------------------------------------------------")
  outputLine(string.format(
    "<cyan>status<white>  %s | prompts %d | completed %d | ticks/prompt %.2f",
    snapshot.on and "ON" or "OFF",
    snapshot.promptSeq,
    snapshot.completedPromptEpochs,
    snapshot.ticksPerPrompt
  ))
  if snapshot.pendingPromptEpoch then
    outputLine("<grey>one trailing-order prompt epoch is pending correlation")
  end

  local sampled = false
  for _, name in ipairs(PROBE_ORDER) do
    local record = snapshot.records[name]
    if record and record.count > 0 then
      if not sampled then outputLine("<cyan>TIMINGS<white>"); sampled = true end
      outputLine(string.format(
        "<white>%-31s <grey>%5d  mean %8.3fms  max %8.3fms",
        name,
        record.count,
        record.totalSeconds / record.count * 1000,
        record.maxSeconds * 1000
      ))
      outputLine(string.format(
        "<dim_grey>  total %8.3fms  last %8.3fms  p50 %s  p95 %s  p99 %s",
        record.totalSeconds * 1000,
        record.lastSeconds * 1000,
        percentileLabel(record, 0.50),
        percentileLabel(record, 0.95),
        percentileLabel(record, 0.99)
      ))
    end
  end
  if not sampled then outputLine("<grey>no timing samples recorded") end

  local tickRecord = snapshot.records.tick
  if tickRecord and tickRecord.count > 0 then
    local sources = tickRecord.sources or {}
    outputLine("<cyan>TICK SOURCES<white>")
    outputLine(string.format(
      "<white>vitals %d | prompt %d | target %d | room %d | walk %d | charstatus %d | other %d",
      tonumber(sources.vitals) or 0,
      tonumber(sources.prompt) or 0,
      tonumber(sources.target) or 0,
      tonumber(sources.room) or 0,
      tonumber(sources.walk) or 0,
      tonumber(sources.charstatus) or 0,
      tonumber(sources.other) or 0
    ))
  end

  outputLine("<cyan>COUNTERS<white>")
  for _, name in ipairs(COUNTER_NAMES) do
    outputLine(string.format(
      "<white>%-31s <grey>%d",
      name,
      tonumber(snapshot.counters[name]) or 0
    ))
  end
  if snapshot.droppedSpans > 0 then
    outputLine(string.format(
      "<yellow>[WARN] perf span depth overflow: %d",
      snapshot.droppedSpans
    ))
  end
  outputLine("<dim_grey>Totals and counts are the reliable evidence; wall-clock sub-millisecond values are resolution-limited.")
  return snapshot
end

function boop.perf.command(raw)
  local command = tostring(raw or ""):lower():match("^%s*(.-)%s*$")
  if command == "on" then
    boop.perf.setEnabled(true)
    outputLine("<green>[OK]<white> perf: on (session-local)")
    return true
  elseif command == "off" then
    boop.perf.setEnabled(false)
    outputLine("<green>[OK]<white> perf: off")
    return true
  elseif command == "reset" then
    boop.perf.reset()
    outputLine("<green>[OK]<white> perf: reset")
    return true
  elseif command == "" or command == "show" then
    boop.perf.show()
    return true
  end
  outputLine("<red>[ERR]<white> usage: boop perf on|off|show|reset")
  return false
end

boop.perf.on = false
boop.perf._registrations = {}
boop.perf._records = nil
boop.perf._recordsById = nil
boop.perf._counters = nil
boop.perf._nextToken = 0
boop.perf.droppedSpans = 0
resetCorrelation()
