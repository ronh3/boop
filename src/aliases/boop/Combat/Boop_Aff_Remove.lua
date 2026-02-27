local list = boop.util.split(matches[2] or "", "/")
for _, aff in ipairs(list) do
  local trimmed = boop.util.trim(aff)
  if trimmed ~= "" then
    boop.afflictions.removeTarget(trimmed)
  end
end
boop.afflictions.displayTarget()
