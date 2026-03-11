boop.ih = boop.ih or {}

function boop.ih.init()
  boop.state.ihActive = boop.state.ihActive or false
  boop.state.ihTimer = boop.state.ihTimer or nil
end

function boop.ih.start()
  boop.state.ihActive = true
  if boop.state.ihTimer then
    killTimer(boop.state.ihTimer)
  end
  boop.state.ihTimer = tempTimer(2.5, function()
    boop.state.ihActive = false
    boop.state.ihTimer = nil
  end)
end

function boop.ih.stop()
  boop.state.ihActive = false
  if boop.state.ihTimer then
    killTimer(boop.state.ihTimer)
    boop.state.ihTimer = nil
  end
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
  if not boop.state.ihActive then return end
  if fullLine and boop.util.starts(fullLine, "Number of objects:") then
    boop.ih.stop()
    return
  end
  if not name or name == "" then return end
  local isDenizen = false
  if boop.targets and boop.targets.isDenizenName then
    isDenizen = boop.targets.isDenizenName(name)
  end
  boop.ih.printLine(id, name, isDenizen, fullLine)
end
