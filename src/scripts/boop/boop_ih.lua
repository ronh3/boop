boop.ih = boop.ih or {}

local IH_TRIGGER_NAMES = {
  "IH End",
  "IH Line",
}

local function setCaptureTriggersEnabled(enabled)
  local fn = enabled and enableTrigger or disableTrigger
  if not fn then
    return
  end

  for _, triggerName in ipairs(IH_TRIGGER_NAMES) do
    pcall(fn, triggerName)
  end
end

local function clearTimer()
  if boop.state.ihTimer then
    killTimer(boop.state.ihTimer)
    boop.state.ihTimer = nil
  end
end

local function armTimeout()
  clearTimer()
  boop.state.ihTimer = tempTimer(2.5, function()
    boop.ih.stop()
  end)
end

function boop.ih.init()
  boop.state.ihActive = boop.state.ihActive or false
  boop.state.ihRequested = boop.state.ihRequested or false
  boop.state.ihTimer = boop.state.ihTimer or nil
  setCaptureTriggersEnabled(false)
end

function boop.ih.start()
  boop.state.ihRequested = true
  boop.state.ihActive = false
  setCaptureTriggersEnabled(true)
  armTimeout()
end

function boop.ih.stop()
  boop.state.ihRequested = false
  boop.state.ihActive = false
  clearTimer()
  setCaptureTriggersEnabled(false)
end

function boop.ih.isObjectId(id)
  if not id or id == "" then
    return false
  end

  return tostring(id):match("^[A-Za-z][A-Za-z0-9_'-]*%d+$") ~= nil
end

function boop.ih.printLine(id, name, isDenizen, fullLine)
  local lineText = fullLine or (tostring(id) .. "  " .. tostring(name))
  local whitelisted = false
  local globallyBlacklisted = false
  if isDenizen then
    local area = boop.targets and boop.targets.getArea and boop.targets.getArea() or "UNKNOWN"
    if boop.targets and boop.targets.isWhitelisted then
      whitelisted = boop.targets.isWhitelisted(area, name)
    end
    if boop.targets and boop.targets.isGloballyBlacklisted then
      globallyBlacklisted = boop.targets.isGloballyBlacklisted(name)
    end
  end
  if cechoLink and cecho then
    cecho("\n" .. lineText .. " ")
    if isDenizen and not globallyBlacklisted then
      if whitelisted then
        cechoLink("<yellow>[-whitelist]<reset>", function()
          boop.targets.removeWhitelist(nil, name)
          boop.targets.displayWhitelist()
        end, "Remove from whitelist", true)
      else
        cechoLink("<green>[+whitelist]<reset>", function()
          boop.targets.addWhitelist(nil, name)
          boop.targets.displayWhitelist()
        end, "Add to whitelist", true)
      end
      cecho(" ")
      cechoLink("<red>[+blacklist]<reset>", function()
        boop.targets.addBlacklist(nil, name)
        boop.targets.displayBlacklist()
      end, "Add to blacklist", true)
    end
  elseif echoLink and echo then
    echo("\n" .. lineText .. " ")
    if isDenizen and not globallyBlacklisted then
      if whitelisted then
        echoLink("[-whitelist]", function()
          boop.targets.removeWhitelist(nil, name)
          boop.targets.displayWhitelist()
        end, "Remove from whitelist", true)
      else
        echoLink("[+whitelist]", function()
          boop.targets.addWhitelist(nil, name)
          boop.targets.displayWhitelist()
        end, "Add to whitelist", true)
      end
      echo(" ")
      echoLink("[+blacklist]", function()
        boop.targets.addBlacklist(nil, name)
        boop.targets.displayBlacklist()
      end, "Add to blacklist", true)
    end
  else
    if isDenizen and not globallyBlacklisted then
      boop.util.echo(lineText .. " [+whitelist] [+blacklist]")
    else
      boop.util.echo(lineText)
    end
  end
end

function boop.ih.handleLine(id, name, fullLine)
  if not boop.state.ihRequested and not boop.state.ihActive then return end
  if fullLine and boop.util.starts(fullLine, "Number of objects:") then
    boop.ih.stop()
    return
  end
  if not boop.ih.isObjectId(id) then return end
  if not name or name == "" then return end
  if not boop.state.ihActive then
    boop.state.ihActive = true
  end
  armTimeout()
  local isDenizen = false
  if boop.targets and boop.targets.isDenizenName then
    isDenizen = boop.targets.isDenizenName(name)
  end
  boop.ih.printLine(id, name, isDenizen, fullLine)
end
