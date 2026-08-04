local line = ""
if type(matches) == "table" then
  line = tostring(matches[2] or matches[1] or "")
end

if boop and boop.onStandardCommandOutcome then
  boop.onStandardCommandOutcome(line)
end
