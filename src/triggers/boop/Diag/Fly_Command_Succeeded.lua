local line = ""
if type(matches) == "table" then
  line = tostring(matches[2] or matches[1] or "")
end

if boop
    and boop.runtime
    and boop.runtime.onFlyCommandSucceeded then
  boop.runtime.onFlyCommandSucceeded(line)
end
