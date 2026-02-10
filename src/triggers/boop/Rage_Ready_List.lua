local str = matches[2] or ""
local list = boop.util.split(str, ",")
for i, name in ipairs(list) do
  list[i] = boop.util.trim(name)
end
boop.rage.onReadyList(list)
