local M = {}

local function root()
  return assert(os.getenv("TESTS_DIRECTORY"), "TESTS_DIRECTORY env var is required")
end

function M.repoRoot()
  return os.getenv("BOOP_REPO_ROOT") or (root() .. "/..")
end

local function resetTableData(tbl)
  if type(tbl) ~= "table" then
    return
  end

  for key, value in pairs(tbl) do
    if type(value) ~= "function" then
      tbl[key] = nil
    end
  end
end

local function deepCopy(value, seen)
  if type(value) ~= "table" then
    return value
  end
  seen = seen or {}
  if seen[value] then
    return seen[value]
  end
  local out = {}
  seen[value] = out
  for key, entry in pairs(value) do
    out[key] = deepCopy(entry, seen)
  end
  return out
end

local function norm(value)
  value = tostring(value or "")
  return value:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function resetDb()
  if not boop or not boop.db or not db or not db.get_database then
    return
  end

  local ok, handle = pcall(function()
    return db:get_database("boop")
  end)
  if not ok or not handle then
    local initOk = pcall(function()
      boop.db.init()
    end)
    if not initOk then
      boop.db.handle = nil
      return
    end
    ok, handle = pcall(function()
      return db:get_database("boop")
    end)
    if not ok or not handle then
      boop.db.handle = nil
      return
    end
  end

  boop.db.handle = handle

  for _, sheetName in ipairs({
    "config",
    "whitelist",
    "blacklist",
    "whitelist_tags",
    "mob_xp",
    "mob_xp_v2",
    "stats",
  }) do
    local sheet = handle[sheetName]
    if sheet then
      local fetched, rows = pcall(function()
        return db:fetch(sheet, nil)
      end)
      if fetched and rows then
        for _, row in ipairs(rows) do
          if row and row._row_id then
            pcall(function()
              db:delete(sheet, row._row_id)
            end)
          end
        end
      end
    end
  end
end

local function findCharstatIndex(name)
  local stats = gmcp.Char.Vitals.charstats or {}
  local prefix = tostring(name) .. ":"
  for i, stat in ipairs(stats) do
    if tostring(stat):find(prefix, 1, true) == 1 then
      return i
    end
  end
  return nil
end

function M.load()
  return M
end

function M.reset()
  assert(boop, "boop package is not loaded")
  local desiredGroups = boop.skills and boop.skills.desiredGroups or nil

  resetDb()

  gmcp = {
    Char = {
      Name = { name = "TestCharacter" },
      Status = { class = "", name = "TestCharacter" },
      Vitals = {
        hp = 5000,
        maxhp = 5000,
        bal = "1",
        eq = "1",
        charstats = {},
      },
      Skills = {},
      Items = {},
    },
    Room = {
      Info = {
        area = "UNKNOWN",
        num = 1,
        exits = {},
      },
    },
    IRE = {
      Target = {
        Set = "",
        Info = {
          id = "",
          hpperc = "100%",
        },
      },
      Display = {
        ButtonActions = {},
      },
    },
  }

  boop.config = {}
  for key, value in pairs(boop.defaults or {}) do
    boop.config[key] = value
  end

  boop.lists = {
    whitelist = {},
    blacklist = {},
    globalBlacklist = {},
    whitelistTags = {},
    separator = "/",
  }

  if boop.perf then
    boop.perf.setEnabled(false)
    boop.perf.reset()
  end

  resetTableData(boop.state)
  boop.state.init()
  boop.state.lifecycle.promptSeen = true
  boop.state.lifecycle.ireSeen = true
  boop.state.lifecycle.ready = true
  boop.state.lifecycle.source = "test fixture"
  if boop.runtime and boop.runtime.startRoomObservation then
    local observation = boop.runtime.startRoomObservation(
      gmcp.Room.Info.num,
      {
      boundary = "fresh_start",
      }
    )
    local roomId = tostring(observation.roomId or gmcp.Room.Info.num)
    boop.state.targeting.roomObservation.itemsSeen = true
    boop.state.targeting.roomObservation.acceptedItems = {}
    boop.state.targeting.roomObservation.acceptedSourceAuthority = {
      applicationId = 1,
      roomId = roomId,
      observationGeneration = observation.generation,
    }
    boop.state.targeting.roomObservation.nextApplicationId = 2
  end

  resetTableData(boop.afflictions)
  boop.afflictions.init()
  resetTableData(boop.stats)
  boop.stats.init()
  resetTableData(boop.ui)
  resetTableData(boop.skills)
  boop.skills.desiredGroups = desiredGroups
  boop.rage.init()
  boop.skills.init()
  if boop.registry and boop.registry.attachUiConfigRegistries then
    boop.registry.attachUiConfigRegistries()
  end

  boop.handlers = {}
  resetDb()

  return boop
end

function M.setArea(area)
  gmcp.Room.Info.area = area
end

function M.setClass(className)
  gmcp.Char.Status.class = className
  boop.state.combat.class = className
end

function M.setSpec(spec)
  local idx = findCharstatIndex("Spec")
  local value = "Spec: " .. tostring(spec)
  if idx then
    gmcp.Char.Vitals.charstats[idx] = value
  else
    table.insert(gmcp.Char.Vitals.charstats, value)
  end
  boop.state.combat.spec = spec
end

function M.setRage(rage)
  local idx = findCharstatIndex("Rage")
  local value = "Rage: " .. tostring(rage)
  if idx then
    gmcp.Char.Vitals.charstats[idx] = value
  else
    table.insert(gmcp.Char.Vitals.charstats, value)
  end
end

function M.setTarget(id, name, hpperc)
  local targetId = tostring(id or "")
  boop.state.targeting.currentTargetId = targetId
  boop.state.targeting.targetName = tostring(name or "")
  gmcp.IRE.Target.Set = targetId
  gmcp.IRE.Target.Info.id = targetId
  if hpperc ~= nil then
    gmcp.IRE.Target.Info.hpperc = tostring(hpperc)
  end
end

function M.setTargetHp(hpperc)
  gmcp.IRE.Target.Info.hpperc = tostring(hpperc)
end

function M.setDenizens(denizens)
  boop.state.targeting.denizens = {}
  local acceptedItems = {}
  for _, denizen in ipairs(denizens or {}) do
    local item = {
      id = tostring(denizen.id),
      name = denizen.name,
      attrib = denizen.attrib or "m",
    }
    boop.state.targeting.denizens[#boop.state.targeting.denizens + 1] = item
    acceptedItems[#acceptedItems + 1] = deepCopy(item)
  end
  if boop.runtime and boop.runtime.roomObservationSnapshot then
    local observation = boop.runtime.roomObservationSnapshot()
    local roomId = tostring(
      gmcp
        and gmcp.Room
        and gmcp.Room.Info
        and gmcp.Room.Info.num
        or observation.roomId
        or ""
    )
    local generation = math.max(
      1,
      tonumber(observation.generation) or 0
    )
    boop.state.targeting.roomObservation = {
      generation = generation,
      roomId = roomId,
      infoSeen = roomId ~= "",
      itemsSeen = roomId ~= "",
      acceptedItems = acceptedItems,
      fenceQueue = {},
      activeFenceId = false,
      nextFenceId = 1,
      lastCompletedFence = false,
      nextApplicationId = 2,
      activeApplication = false,
      acceptedSourceAuthority = roomId ~= "" and {
        applicationId = 1,
        roomId = roomId,
        observationGeneration = generation,
      } or false,
      refreshAttempted = false,
      refreshReason = "",
      refreshTimeoutTimer = false,
      warned = false,
    }
  end
end

function M.setRuntimeBlocker(blocker)
  blocker = blocker or {}
  return boop.runtime.setBlocker(
    tostring(blocker.owner or blocker.code or ""),
    tostring(blocker.code or ""),
    tostring(blocker.label or ""),
    blocker.systems or {},
    blocker.waitsFor or {},
    {
      observed = blocker.observed or {},
      source = blocker.source,
      since = blocker.since,
      promptSeen = blocker.promptSeen,
      gmcpSeen = blocker.gmcpSeen,
      warningThrottleSeconds = blocker.warningThrottleSeconds,
    }
  )
end

function M.seedRoomObservation(roomId, opts)
  opts = opts or {}
  local state = boop.runtime.state()
  local generation = tonumber(opts.generation) or 1
  local normalizedRoomId = tostring(roomId or "")
  local fenceQueue = deepCopy(opts.fenceQueue or opts.fences or {})
  if opts.fenced == true and #fenceQueue == 0 then
    fenceQueue[1] = {
      fenceId = tonumber(opts.fenceId) or 1,
      generation = generation,
      roomId = normalizedRoomId,
      phase = tostring(opts.fencePhase or "await_inv"),
      valid = opts.fenceValid ~= false,
    }
  end

  local highestFenceId = 0
  for _, fence in ipairs(fenceQueue) do
    highestFenceId = math.max(
      highestFenceId,
      tonumber(fence and fence.fenceId) or 0
    )
  end

  local activeFenceId = opts.activeFenceId
  if activeFenceId == nil then
    for i = #fenceQueue, 1, -1 do
      local fence = fenceQueue[i]
      if type(fence) == "table"
          and fence.valid ~= false
          and tonumber(fence.generation) == generation then
        activeFenceId = tonumber(fence.fenceId) or false
        break
      end
    end
  end

  local observation = {
    generation = generation,
    roomId = normalizedRoomId,
    infoSeen = opts.infoSeen ~= false,
    itemsSeen = opts.itemsSeen == true,
    acceptedItems = deepCopy(opts.acceptedItems or opts.items or {}),
    fenceQueue = fenceQueue,
    activeFenceId = activeFenceId or false,
    nextFenceId = tonumber(opts.nextFenceId)
      or math.max(highestFenceId + 1, 1),
    refreshAttempted = opts.refreshAttempted == true
      or #fenceQueue > 0,
    refreshReason = tostring(opts.refreshReason or ""),
    refreshTimeoutTimer = opts.refreshTimeoutTimer or false,
    warned = opts.warned == true,
    nextApplicationId = tonumber(opts.nextApplicationId) or 2,
    activeApplication = false,
    acceptedSourceAuthority = opts.itemsSeen == true
      and opts.authoritative ~= false
      and normalizedRoomId ~= ""
      and {
        applicationId = tonumber(opts.applicationId) or 1,
        roomId = normalizedRoomId,
        observationGeneration = generation,
      }
      or false,
  }
  state.targeting.roomObservation = observation
  gmcp.Room.Info.num = roomId
  return observation
end

function M.newTimerQueue()
  local queue = {
    callbacks = {},
    cancelled = {},
    delays = {},
    nextId = 0,
  }

  function queue.tempTimer(delay, callback)
    queue.nextId = queue.nextId + 1
    local id = queue.nextId
    queue.delays[id] = delay
    queue.callbacks[id] = callback
    return id
  end

  function queue.killTimer(id)
    local exists = queue.callbacks[id] ~= nil
    queue.cancelled[id] = true
    return exists
  end

  function queue.callback(id)
    return queue.callbacks[id]
  end

  function queue.run(id)
    local callback = queue.callbacks[id]
    assert(type(callback) == "function", "timer callback not found: " .. tostring(id))
    return callback()
  end

  return queue
end

function M.newNativeQueue()
  local native = {
    queues = {},
    commands = {},
    validationErrors = {},
  }

  local function queueEntries(name)
    name = norm(name)
    native.queues[name] = native.queues[name] or {}
    return native.queues[name]
  end

  local function clearAll()
    native.queues = {}
  end

  local function validationError(command, message)
    native.validationErrors[#native.validationErrors + 1] = {
      command = command,
      message = message,
    }
    return false
  end

  function native.apply(command)
    command = tostring(command or "")
    native.commands[#native.commands + 1] = command

    local queueName, queuedCommand = command:match(
      "^queue%s+add%s+(%S+)%s+(.+)$"
    )
    if queueName and queuedCommand then
      local entries = queueEntries(queueName)
      entries[#entries + 1] = queuedCommand
      return true
    end

    queueName, queuedCommand = command:match(
      "^queue%s+addclearfull%s+(%S+)%s+(.+)$"
    )
    if queueName and queuedCommand then
      clearAll()
      local entries = queueEntries(queueName)
      entries[#entries + 1] = queuedCommand
      return true
    end

    local clearQueue = command:match("^clearqueue%s+(%S+)%s*$")
      or command:match("^queue%s+clear%s+(%S+)%s*$")
    if clearQueue then
      if norm(clearQueue) == "all" then
        clearAll()
      else
        native.queues[norm(clearQueue)] = nil
      end
      return true
    end

    if command:match("^clearqueue%s*$")
        or command:match("^queue%s+clear%s*$") then
      return validationError(command, "queue name is required")
    end

    return true
  end

  function native.send(command, _)
    return native.apply(command)
  end

  function native.snapshot()
    return deepCopy(native.queues)
  end

  function native.errorsSnapshot()
    return deepCopy(native.validationErrors)
  end

  return native
end

function M.setWalker(opts)
  opts = opts or {}
  local previous = {
    demonwalker = _G.demonwalker,
    installPackage = _G.installPackage,
    raiseEvent = _G.raiseEvent,
    updatePackage = _G.updatePackage,
  }
  local fixture = {
    initCalls = {},
    installCalls = {},
    raisedEvents = {},
    updateCalls = {},
  }
  local walker = {
    enabled = opts.attached == true,
  }

  function walker:init(options)
    fixture.initCalls[#fixture.initCalls + 1] = options
    if opts.initMode == "throw" then
      error(opts.initError or "walker init failed")
    end
    self.enabled = true
    return true
  end

  function walker:update(...)
    fixture.updateCalls[#fixture.updateCalls + 1] = { ... }
    return true
  end

  if opts.available == false then
    _G.demonwalker = nil
  else
    _G.demonwalker = walker
  end
  _G.installPackage = function(url)
    fixture.installCalls[#fixture.installCalls + 1] = url
    local mode = opts.installMode or "success"
    if mode == "throw" then
      error(opts.installError or "install threw")
    elseif mode == "false_error" then
      return false, opts.installError or "install returned false"
    elseif mode == "nil_error" then
      return nil, opts.installError or "install returned nil"
    end
    return true
  end
  _G.updatePackage = function(...)
    fixture.updateCalls[#fixture.updateCalls + 1] = { ... }
    return true
  end
  _G.raiseEvent = function(name, ...)
    fixture.raisedEvents[#fixture.raisedEvents + 1] = {
      name = name,
      args = { ... },
    }
  end

  fixture.walker = walker

  function fixture.setAvailable(value)
    _G.demonwalker = value and walker or nil
  end

  function fixture.setAttached(value)
    walker.enabled = value and true or false
  end

  function fixture.restore()
    _G.demonwalker = previous.demonwalker
    _G.installPackage = previous.installPackage
    _G.raiseEvent = previous.raiseEvent
    _G.updatePackage = previous.updatePackage
  end

  return fixture
end

function M.seedAutomationIntent()
  local state = boop.runtime.state()

  state.combat.attacking = true
  state.combat.pendingStandard = "command hound at 42"
  state.combat.pendingRage = "harry 42"
  state.combat.attackPlan = {
    standard = "command hound at 42",
    rage = "harry 42",
  }

  state.targeting.calledTargetId = "42"
  state.targeting.calledTargetRoom = tostring((gmcp.Room.Info and gmcp.Room.Info.num) or "")
  state.targeting.calledTargetBy = "boop"

  state.queue.prequeuedStandard = true
  state.queue.aliasAction = "command hound at 42"
  state.queue.aliasDirty = false

  state.walk.active = true
  state.walk.moveQueued = true
  state.walk.roomSettled = true

  state.gold.autoGrabPending = true
  state.gold.autoGrabPendingAt = 1
  state.gold.getPending = true
  state.gold.putPending = true
  state.gold.packTarget = "pack"

  return state
end

function M.setWhitelist(area, names)
  boop.lists.whitelist[area] = {}
  for _, name in ipairs(names or {}) do
    table.insert(boop.lists.whitelist[area], name)
  end
end

function M.setBlacklist(area, names)
  boop.lists.blacklist[area] = {}
  for _, name in ipairs(names or {}) do
    table.insert(boop.lists.blacklist[area], name)
  end
end

function M.setGlobalBlacklist(names)
  boop.lists.globalBlacklist = {}
  for _, name in ipairs(names or {}) do
    table.insert(boop.lists.globalBlacklist, name)
  end
end

function M.learnSkill(name, group)
  local key = norm(name)
  boop.skills.known[key] = true
  if group and group ~= "" then
    boop.skills.skillToGroup[key] = norm(group)
  end
  boop.skills.skillOriginal[key] = name
end

function M.setSkillKnown(name, known, group)
  local key = norm(name)
  boop.skills.known[key] = known and true or false
  if group and group ~= "" then
    boop.skills.skillToGroup[key] = norm(group)
  end
  boop.skills.skillOriginal[key] = name
end

function M.learnSkills(skills)
  for _, skill in ipairs(skills or {}) do
    if type(skill) == "table" then
      M.learnSkill(skill.name, skill.group)
    else
      M.learnSkill(skill)
    end
  end
end

function M.addTargetAfflictions(affs)
  for _, aff in ipairs(affs or {}) do
    boop.afflictions.addTarget(aff)
  end
end

function M.supportPath(path)
  return root() .. "/" .. path
end

return M
