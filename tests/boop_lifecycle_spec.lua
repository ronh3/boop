local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, entry in pairs(value) do
    out[copy(key, seen)] = copy(entry, seen)
  end
  return out
end

describe("boop lifecycle recovery", function()
  local savedGlobals
  local savedFunctions
  local savedPackageFields

  local function restorePackageFields()
    if type(savedPackageFields) ~= "table" then
      return
    end
    boop.state = savedPackageFields.state
    boop.config = savedPackageFields.config
    boop.handlers = savedPackageFields.handlers
    boop.gmcp = savedPackageFields.gmcp
    savedPackageFields = nil
  end

  local function replaceGlobal(name, value)
    if savedGlobals[name] == nil then
      savedGlobals[name] = {
        existed = rawget(_G, name) ~= nil,
        value = rawget(_G, name),
      }
    end
    rawset(_G, name, value)
  end

  local function replaceFunction(owner, name, value)
    savedFunctions[#savedFunctions + 1] = {
      owner = owner,
      name = name,
      value = owner[name],
    }
    owner[name] = value
  end

  local function blocker(owner)
    return boop.runtime.state().combat.blockersByOwner[owner]
  end

  local function seedUnrelatedOperation()
    return boop.locks.setOperationLock(
      "interrupt:test-unrelated",
      "interrupt_pending",
      "unrelated test operation",
      {
        combat = true,
      },
      {
        timeout = true,
      },
      {
        source = "test",
      }
    )
  end

  before_each(function()
    savedPackageFields = {
      state = boop.state,
      config = boop.config,
      handlers = boop.handlers,
      gmcp = boop.gmcp,
    }
    savedGlobals = {}
    savedFunctions = {}
    boop.state = {}
    boop.runtime.ensureState()
    boop.config = {
      enabled = false,
      autoGrabGold = false,
      goldPack = "",
      targetingMode = "auto",
      targetCall = false,
      useQueueing = false,
      prequeueEnabled = false,
      attackLeadSeconds = 0,
    }
    boop.handlers = {}
    boop.gmcp = {
      lastSupportAnnounceAt = 0,
    }
    replaceGlobal("gmcp", {
      Char = {
        Items = {},
        Status = {
          class = "Occultist",
        },
        Vitals = {
          bal = "1",
          eq = "1",
          charstats = {},
        },
      },
      IRE = {
        Target = {
          Set = "",
          Info = {},
        },
        Display = {
          FixedFont = "stop",
        },
      },
      Room = {
        Info = {
          num = "1",
          area = "Lifecycle Test",
          exits = {},
        },
      },
    })
    replaceGlobal("getEpoch", function()
      return 0
    end)
    replaceGlobal("killTimer", function(_)
      return false
    end)
    replaceGlobal("send", function(_, _) end)
    replaceGlobal("sendGMCP", function(_) end)
    replaceGlobal("raiseEvent", function(_, ...) end)
    replaceGlobal("tempTimer", function(_, _)
      return 0
    end)
  end)

  after_each(function()
    for index = #(savedFunctions or {}), 1, -1 do
      local entry = savedFunctions[index]
      entry.owner[entry.name] = entry.value
    end
    for name, entry in pairs(savedGlobals or {}) do
      if entry.existed then
        rawset(_G, name, entry.value)
      else
        rawset(_G, name, nil)
      end
    end
    restorePackageFields()
  end)

  it("gap-03-3 keeps only lifecycle evidence active while disabled", function()
    local marker = "GAP_03_3_LIFECYCLE_BOUNDARY_BROKEN"
    local triggerCalls = {}
    local registrations = {}

    replaceGlobal("enableTrigger", function(name)
      triggerCalls[#triggerCalls + 1] = {
        action = "enable",
        name = name,
      }
    end)
    replaceGlobal("disableTrigger", function(name)
      triggerCalls[#triggerCalls + 1] = {
        action = "disable",
        name = name,
      }
    end)
    replaceGlobal("registerAnonymousEventHandler", function(event, callback)
      registrations[#registrations + 1] = {
        event = event,
        callback = callback,
      }
      return #registrations
    end)
    replaceGlobal("killAnonymousEventHandler", function(_) end)

    boop.config.enabled = false
    assert.is_true(boop.triggers.syncEnabled())
    assert.are.same({
      {
        action = "enable",
        name = "boop lifecycle",
      },
      {
        action = "disable",
        name = "boop",
      },
    }, triggerCalls, marker)

    boop.events.beginConnectionLifecycle("enable ordering")
    gmcp.IRE = {
      Display = {
        FixedFont = "stop",
      },
    }
    boop.config.enabled = true
    assert.is_true(boop.triggers.syncEnabled())
    assert.are.same({
      {
        action = "enable",
        name = "boop lifecycle",
      },
      {
        action = "disable",
        name = "boop",
      },
      {
        action = "enable",
        name = "boop lifecycle",
      },
      {
        action = "enable",
        name = "boop",
      },
    }, triggerCalls)
    local lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_true(lifecycle.ireSeen)
    assert.is_false(lifecycle.promptSeen)
    assert.is_false(lifecycle.ready)
    assert.is_nil(blocker("gmcp:ire"))

    boop.events.register()
    local expected = {
      ["gmcp.IRE.Display.ButtonActions"] = "boop.onIreSupportObserved",
      ["gmcp.IRE.Display.FixedFont"] = "boop.onIreSupportObserved",
      ["gmcp.IRE.Display.Ohmap"] = "boop.onIreSupportObserved",
      ["gmcp.IRE.Target.Set"] = "boop.onTargetSet",
      ["gmcp.IRE.Target.Info"] = "boop.onTargetInfo",
      ["gmcp.Char.Afflictions.List"] = "boop.onDiagAfflictionsList",
      ["sysDataSendRequest"] = "boop.onDataSendRequest",
    }
    local counts = {}
    for _, entry in ipairs(registrations) do
      if expected[entry.event] then
        assert.are.equal(expected[entry.event], entry.callback)
        counts[entry.event] = (counts[entry.event] or 0) + 1
      end
    end
    for event in pairs(expected) do
      assert.are.equal(1, counts[event] or 0)
    end
  end)

  it("tracks IRE readiness without installing a runtime operation owner", function()
    replaceFunction(boop, "requestCoreSupports", function(_)
      return true
    end)

    boop.config.enabled = false
    gmcp.IRE = nil
    boop.onConnectionEvent()

    local lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_false(lifecycle.ireSeen)
    assert.is_false(lifecycle.promptSeen)
    assert.is_false(lifecycle.ready)
    assert.is_nil(blocker("gmcp:ire"))

    boop.onPrompt()
    lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_false(lifecycle.ireSeen)
    assert.is_true(lifecycle.promptSeen)
    assert.is_false(lifecycle.ready)
    assert.is_nil(blocker("gmcp:ire"))

    gmcp.IRE = {
      Display = {
        FixedFont = "stop",
      },
    }
    boop.onIreSupportObserved("gmcp.IRE.Display.FixedFont")

    lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_true(lifecycle.ireSeen)
    assert.is_true(lifecycle.promptSeen)
    assert.is_true(lifecycle.ready)
    assert.is_nil(blocker("gmcp:ire"))
    assert.are.equal(0, #boop.locks.operationLocksSnapshot())
  end)

  it("updates canonical Rage and Spec while disabled without running a tick", function()
    local tickCalls = 0
    replaceFunction(boop, "tick", function()
      tickCalls = tickCalls + 1
      return true
    end)
    gmcp.Char.Vitals.charstats = {
      "Rage: 42",
      "Spec: Two Handed",
      "Other: ignored",
    }
    boop.config.enabled = false

    assert.is_false(boop.onVitals())
    assert.are.equal(0, tickCalls)
    assert.are.equal(42, boop.state.rage.amount)
    assert.are.equal("Two Handed", boop.state.combat.spec)
    assert.are.equal(42, boop.attacks.getRage())
    assert.are.equal(42, boop.runtime.context().rage.amount)
    assert.are.equal(
      42,
      boop.state.rage.samples[#boop.state.rage.samples].r
    )

    gmcp.Char.Vitals.charstats = {
      "Spec: Sword and Shield",
      "Rage: 27",
    }
    boop.config.enabled = true
    boop.onVitals()
    assert.are.equal(1, tickCalls)
    assert.are.equal(27, boop.state.rage.amount)
    assert.are.equal("Sword and Shield", boop.state.combat.spec)
  end)

  it("throttles Core.Supports in seconds while preserving forced announcements", function()
    local now = 100
    local sent = {}
    replaceGlobal("getEpoch", function() return now end)
    replaceGlobal("sendGMCP", function(payload)
      sent[#sent + 1] = payload
    end)
    boop.gmcp.lastSupportAnnounceAt = 0

    assert.is_true(boop.requestCoreSupports({ force = true }))
    assert.are.equal(4, #sent)

    now = 100.5
    assert.is_false(boop.requestCoreSupports({ minInterval = 1 }))
    assert.are.equal(4, #sent)

    assert.is_true(boop.requestCoreSupports({
      force = true,
      minInterval = 1,
    }))
    assert.are.equal(8, #sent)

    now = 101.6
    assert.is_true(boop.requestCoreSupports({ minInterval = 1 }))
    assert.are.equal(12, #sent)
  end)

  it("gap-03-3 accepts lifecycle evidence in either order", function()
    local marker = "GAP_03_3_LIFECYCLE_BOUNDARY_BROKEN"
    assert.is_function(boop.onIreSupportObserved, marker)
    replaceFunction(boop, "requestCoreSupports", function(_)
      return true
    end)
    replaceGlobal("enableTrigger", function(_) end)
    replaceGlobal("disableTrigger", function(_) end)

    boop.config.enabled = false
    gmcp.IRE = nil
    boop.onConnectionEvent()
    seedUnrelatedOperation()
    gmcp.IRE = {
      Display = {
        FixedFont = "stop",
      },
    }
    boop.onIreSupportObserved("gmcp.IRE.Display.FixedFont")
    local lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_true(lifecycle.ireSeen)
    assert.is_false(lifecycle.promptSeen)
    assert.is_false(lifecycle.ready)
    boop.onPrompt()
    lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_true(lifecycle.ready)
    assert.is_nil(blocker("gmcp:ire"))
    assert.is_table(blocker("interrupt:test-unrelated"))
    boop.onIreSupportObserved("gmcp.IRE.Display.FixedFont")
    boop.onPrompt()
    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
    assert.is_table(blocker("interrupt:test-unrelated"))

    boop.state = {}
    boop.runtime.ensureState()
    seedUnrelatedOperation()
    gmcp.IRE = nil
    boop.onConnectionEvent()
    boop.onPrompt()
    lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_false(lifecycle.ireSeen)
    assert.is_true(lifecycle.promptSeen)
    assert.is_false(lifecycle.ready)
    gmcp.IRE = {
      Target = {
        Set = "42",
        Info = {
          id = "42",
        },
      },
    }
    boop.onIreSupportObserved("gmcp.IRE.Target.Set")
    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
    assert.is_table(blocker("interrupt:test-unrelated"))
    boop.onPrompt()
    boop.onIreSupportObserved("gmcp.IRE.Target.Set")
    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
    assert.is_table(blocker("interrupt:test-unrelated"))

    boop.state = {}
    boop.runtime.ensureState()
    seedUnrelatedOperation()
    gmcp.IRE = nil
    boop.onConnectionEvent()
    gmcp.IRE = {
      Display = {
        ButtonActions = {},
      },
    }
    boop.config.enabled = true
    boop.triggers.syncEnabled()
    lifecycle = boop.runtime.lifecycleSnapshot()
    assert.is_true(lifecycle.ireSeen)
    assert.is_false(lifecycle.promptSeen)
    assert.is_false(lifecycle.ready)
    boop.onPrompt()
    assert.is_true(boop.runtime.lifecycleSnapshot().ready)
    assert.is_table(blocker("interrupt:test-unrelated"))
  end)

  it("gap-03-3 prompt evidence has zero disabled automation", function()
    local marker = "GAP_03_3_LIFECYCLE_BOUNDARY_BROKEN"
    assert.is_function(boop.onIreSupportObserved, marker)
    local effects = {
      steps = 0,
      applies = 0,
      ticks = 0,
      gags = 0,
      sends = 0,
      gmcp = 0,
      events = 0,
      targets = 0,
      gold = 0,
      walks = 0,
    }
    local registrations = {}

    replaceGlobal("send", function(_, _)
      effects.sends = effects.sends + 1
    end)
    replaceGlobal("sendGMCP", function(_)
      effects.gmcp = effects.gmcp + 1
    end)
    replaceGlobal("raiseEvent", function(_, ...)
      effects.events = effects.events + 1
    end)
    replaceGlobal("registerAnonymousEventHandler", function(event, callback)
      registrations[event] = callback
      return event
    end)
    replaceGlobal("killAnonymousEventHandler", function(_) end)
    replaceGlobal("demonwalker", {
      move = function()
        effects.walks = effects.walks + 1
      end,
    })
    replaceFunction(boop.runtime, "step", function(_)
      effects.steps = effects.steps + 1
      return {
        effects = {},
        didAction = false,
        runTick = false,
      }
    end)
    replaceFunction(boop.runtime, "applyEffects", function(_, _)
      effects.applies = effects.applies + 1
      return false
    end)
    replaceFunction(boop, "tick", function()
      effects.ticks = effects.ticks + 1
    end)
    replaceFunction(boop.gag, "onPrompt", function()
      effects.gags = effects.gags + 1
    end)
    replaceFunction(boop.targets, "applyTarget", function(_, _)
      effects.targets = effects.targets + 1
      return true
    end)
    replaceFunction(boop, "flushPendingGold", function(_)
      effects.gold = effects.gold + 1
      return true
    end)
    replaceFunction(boop.walk, "maybeAdvance", function(_)
      effects.walks = effects.walks + 1
      return true
    end)

    boop.events.register()
    assert.are.equal(
      "boop.onIreSupportObserved",
      registrations["gmcp.IRE.Display.FixedFont"],
      marker
    )

    boop.config.enabled = false
    gmcp.IRE = nil
    boop.events.beginConnectionLifecycle("disabled effects")
    local beforeTargeting = copy(boop.state.targeting)
    local beforeGold = copy(boop.state.gold)
    local beforeWalk = copy(boop.state.walk)

    gmcp.IRE = {
      Display = {
        FixedFont = "stop",
      },
      Target = {
        Set = "42",
        Info = {
          id = "42",
          name = "a disabled target",
        },
      },
    }
    local displayCallback = registrations["gmcp.IRE.Display.FixedFont"]
    assert.are.equal("boop.onIreSupportObserved", displayCallback)
    boop.onIreSupportObserved("gmcp.IRE.Display.FixedFont")
    boop.onPrompt()
    boop.onTargetSet()
    boop.onTargetInfo()
    gmcp.IRE = {}
    boop.onIreSupportObserved("duplicate not ready")

    assert.are.same({
      steps = 0,
      applies = 0,
      ticks = 0,
      gags = 0,
      sends = 0,
      gmcp = 0,
      events = 0,
      targets = 0,
      gold = 0,
      walks = 0,
    }, effects)
    assert.are.same(beforeTargeting, boop.state.targeting)
    assert.are.same(beforeGold, boop.state.gold)
    assert.are.same(beforeWalk, boop.state.walk)

    boop.config.enabled = true
    gmcp.IRE = {
      Target = {
        Set = "43",
        Info = {
          id = "44",
          name = "an enabled target",
        },
      },
    }
    boop.onTargetSet()
    assert.are.equal(1, effects.targets)
    boop.onTargetInfo()
    assert.are.equal(2, effects.targets)
  end)

  it("gap-03-3 room warning honors measured latency and remains fail closed", function()
    local marker = "GAP_03_3_ROOM_WARNING_WINDOW_BROKEN"
    local timers = {}
    local killed = {}
    local warnings = {}
    local traces = {}
    local sent = {}
    local fakeEpoch = 0

    replaceGlobal("getEpoch", function()
      return fakeEpoch
    end)
    replaceGlobal("tempTimer", function(delay, callback)
      local id = 700 + #timers
      timers[#timers + 1] = {
        id = id,
        delay = delay,
        callback = callback,
      }
      return id
    end)
    replaceGlobal("killTimer", function(id)
      killed[#killed + 1] = id
      return true
    end)
    replaceGlobal("send", function(command, _)
      if not tostring(command or ""):match("^%s*$") then
        sent[#sent + 1] = command
      end
    end)
    replaceGlobal("sendGMCP", function(_) end)
    replaceFunction(boop.util, "warn", function(message)
      warnings[#warnings + 1] = tostring(message)
    end)
    replaceFunction(boop.trace, "log", function(message)
      traces[#traces + 1] = tostring(message)
    end)

    boop.config.enabled = false
    boop.state.targeting.room = ""
    gmcp.Room.Info = {
      num = "1",
      area = "Accepted Room",
      exits = {},
    }
    boop.state.targeting.room = "1"
    boop.room.startRoomObservation("1", {
      freshStart = true,
      boundary = "fresh_start",
      reason = "accepted response test",
    })
    assert.is_true(boop.room.requestRoomItemsOnce("accepted response test"))
    local acceptedTimeout = timers[#timers]
    assert.are.equal(8.0, acceptedTimeout.delay, marker)

    fakeEpoch = 4500
    gmcp.Char.Items.List = {
      location = "inv",
      items = {},
    }
    boop.onRoomItemsList()
    gmcp.Char.Items.List = {
      location = "room",
      items = {},
    }
    boop.onRoomItemsList()
    acceptedTimeout.callback()
    assert.are.equal(0, #warnings)
    assert.are.equal(1, #killed)

    boop.state = {}
    boop.runtime.ensureState()
    boop.state.targeting.room = "1"
    gmcp.Room.Info = {
      num = "2",
      area = "Missing Room",
      exits = {
        south = "1",
      },
    }
    boop.state.targeting.room = "2"
    boop.room.startRoomObservation("2", {
      movedRooms = true,
      boundary = "room_change",
      reason = "missing response test",
    })
    assert.is_true(boop.room.requestRoomItemsOnce("missing response test"))
    local missingTimeout = timers[#timers]
    assert.are.equal(8.0, missingTimeout.delay)
    fakeEpoch = 8000
    missingTimeout.callback()
    missingTimeout.callback()

    local timeoutTraceCount = 0
    for _, line in ipairs(traces) do
      if line:find("room response fence timeout", 1, true) then
        timeoutTraceCount = timeoutTraceCount + 1
      end
    end
    assert.are.equal(1, #warnings)
    assert.are.equal(
      "room_partial -- room response fence incomplete",
      warnings[1]
    )
    assert.are.equal(1, timeoutTraceCount)
    local readiness = boop.runtime.readinessSnapshot()
    assert.is_false(readiness.room.ready)
    assert.are.equal("room_partial", readiness.room.code)
    assert.is_nil(blocker("room:observation"))
    assert.are.equal(0, #sent)
  end)
end)
