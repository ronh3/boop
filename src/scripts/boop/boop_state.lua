boop.state = boop.state or {}

function boop.state.init()
  boop.state.hunting = boop.state.hunting or false
  boop.state.attacking = boop.state.attacking or false
  boop.state.currentTargetId = boop.state.currentTargetId or ""
  boop.state.targetName = boop.state.targetName or ""
  boop.state.targetShield = boop.state.targetShield or false

  boop.state.denizens = boop.state.denizens or {}
  boop.state.players = boop.state.players or {}

  boop.state.room = boop.state.room or ""
  boop.state.lastRoom = boop.state.lastRoom or ""
  boop.state.lastRoomDir = boop.state.lastRoomDir or ""
  boop.state.movedRooms = boop.state.movedRooms or false
  boop.state.newPeopleInRoom = boop.state.newPeopleInRoom or false

  boop.state.fleeing = boop.state.fleeing or false

  boop.state.limiters = boop.state.limiters or {
    hunting = false,
    targeting = false,
    setting = false,
    rage = false,
  }

  boop.state.rageReady = boop.state.rageReady or {}
  boop.state.rageTimers = boop.state.rageTimers or {}

  boop.state.goldDropped = boop.state.goldDropped or false
  boop.state.shardsDropped = boop.state.shardsDropped or false
  boop.state.autoGrabGoldPending = boop.state.autoGrabGoldPending or false
  boop.state.autoGrabGoldTimer = boop.state.autoGrabGoldTimer or nil
  boop.state.diagHold = boop.state.diagHold or false
  boop.state.diagAwaitPrompt = boop.state.diagAwaitPrompt or false

  boop.state.class = boop.state.class or ""
  boop.state.spec = boop.state.spec or ""

  boop.state.balanceReadyAt = boop.state.balanceReadyAt or nil
  boop.state.equilibriumReadyAt = boop.state.equilibriumReadyAt or nil
  boop.state.prequeueTimer = boop.state.prequeueTimer or nil
  boop.state.prequeuedStandard = boop.state.prequeuedStandard or false

  boop.state.queueAliasAction = boop.state.queueAliasAction or ""
  if boop.state.queueAliasDirty == nil then
    boop.state.queueAliasDirty = true
  end
end
