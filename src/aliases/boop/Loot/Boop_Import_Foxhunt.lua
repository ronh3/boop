local ok, err = pcall(function()
  if not boop or not boop.ui or not boop.ui.importFoxhunt then
    if boop and boop.util and boop.util.echo then
      boop.util.echo("foxhunt import unavailable: command handler not loaded")
    else
      echo("\nboop: foxhunt import unavailable: command handler not loaded")
    end
    return
  end
  boop.ui.importFoxhunt((matches and matches[2]) or "")
end)

if not ok then
  if boop and boop.util and boop.util.echo then
    boop.util.echo("foxhunt import failed: " .. tostring(err))
  else
    echo("\nboop: foxhunt import failed: " .. tostring(err))
  end
end
