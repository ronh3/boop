boop.util = boop.util or {}

function boop.util.trim(s)
  if not s then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function boop.util.starts(s, prefix)
  if not s or not prefix then return false end
  return s:sub(1, #prefix) == prefix
end

function boop.util.contains(list, value)
  if not list then return false end
  for _, v in ipairs(list) do
    if v == value then return true end
  end
  return false
end

function boop.util.split(s, sep)
  sep = sep or "/"
  local parts = {}
  if not s or s == "" then return parts end
  for part in string.gmatch(s, "[^" .. sep .. "]+") do
    parts[#parts + 1] = part
  end
  return parts
end

function boop.util.echo(msg)
  msg = msg or ""
  if cecho then
    cecho("\n<green>boop<reset>: " .. msg)
  else
    echo("\nboop: " .. msg)
  end
end

function boop.util.safeLower(s)
  if not s then return "" end
  return string.lower(s)
end

function boop.util.formatTarget(cmd, target)
  if not cmd then return "" end
  if not target then target = "" end
  local formatted = cmd:gsub("&tar", target)
  formatted = formatted:gsub("@tar", target)
  return formatted
end

function boop.executeAction(action, forceQueue)
  if not action or action == "" then return end

  if boop.config.useQueueing or forceQueue then
    send("setalias BOOP_ATTACK " .. action, false)
    send("queue addclearfull freestand BOOP_ATTACK", false)
  else
    local parts = boop.util.split(action, boop.lists.separator or "/")
    for _, part in ipairs(parts) do
      local trimmed = boop.util.trim(part)
      if trimmed ~= "" then
        send(trimmed, false)
      end
    end
  end
end

function boop.executeRageAction(action)
  if not action or action == "" then return end
  local parts = boop.util.split(action, boop.lists.separator or "/")
  for _, part in ipairs(parts) do
    local trimmed = boop.util.trim(part)
    if trimmed ~= "" then
      send(trimmed, false)
    end
  end
end
