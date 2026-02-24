local key = boop.util.trim(matches[2] or "")
if key == "" then
  boop.ui.listConfigValues()
else
  boop.ui.getConfigValue(key)
end
