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
    local theme = boop.theme and boop.theme.tags and boop.theme.tags() or nil
    local accent = theme and theme.accent or "<green>"
    local text = theme and theme.text or "<white>"
    local border = theme and theme.border or "<grey>"
    local reset = theme and theme.reset or "<reset>"
    cecho("\n" .. accent .. "boop" .. reset .. " " .. border .. "::" .. reset .. " " .. text .. msg .. reset)
  else
    echo("\nboop: " .. msg)
  end
end

local FEEDBACK_STYLE = {
  INFO = { themeKey = "info", textKey = "text", fallbackTag = "cyan", fallbackText = "white" },
  OK = { themeKey = "ok", textKey = "text", fallbackTag = "green", fallbackText = "white" },
  WARN = { themeKey = "warn", textKey = "text", fallbackTag = "yellow", fallbackText = "white" },
  ERR = { themeKey = "err", textKey = "text", fallbackTag = "red", fallbackText = "white" },
}

function boop.util.feedback(kind, msg)
  local k = boop.util.safeUpper and boop.util.safeUpper(kind) or tostring(kind or "INFO"):upper()
  local style = FEEDBACK_STYLE[k] or FEEDBACK_STYLE.INFO
  msg = tostring(msg or "")
  if cecho then
    local theme = boop.theme and boop.theme.tags and boop.theme.tags() or nil
    local accent = theme and theme.accent or "<green>"
    local border = theme and theme.border or "<grey>"
    local tagColor = theme and theme[style.themeKey] or ("<" .. style.fallbackTag .. ">")
    local textColor = theme and theme[style.textKey] or ("<" .. style.fallbackText .. ">")
    local reset = theme and theme.reset or "<reset>"
    cecho(string.format("\n%sboop%s %s[%s%s%s]%s %s%s%s",
      accent, reset,
      border, tagColor, k, border, reset,
      textColor, msg, reset))
  else
    echo(string.format("\nboop [%s]: %s", k, msg))
  end
end

function boop.util.info(msg)
  boop.util.feedback("INFO", msg)
end

function boop.util.ok(msg)
  boop.util.feedback("OK", msg)
end

function boop.util.warn(msg)
  boop.util.feedback("WARN", msg)
end

function boop.util.err(msg)
  boop.util.feedback("ERR", msg)
end

function boop.util.safeLower(s)
  if not s then return "" end
  return string.lower(s)
end

function boop.util.safeUpper(s)
  if not s then return "" end
  return string.upper(s)
end

function boop.util.formatTarget(cmd, target)
  if not cmd then return "" end
  if not target then target = "" end
  local formatted = cmd:gsub("&tar", target)
  formatted = formatted:gsub("@tar", target)
  return formatted
end

boop.trace = boop.trace or {}

local function routineLiveFingerprint(message)
  local text = tostring(message or "")
  if text == "tick: no target" then
    return "tick_no_target", text
  end
  if text:find("room_partial", 1, true) then
    return "room_partial", text
  end
  if boop.util.starts(text, "target lost:")
      or text:find("target_lost", 1, true) then
    return "target_removal", text
  end
  return nil, nil
end

local function shouldRenderLiveTrace(message)
  local text = tostring(message or "")
  if boop.util.starts(text, "operation enter:")
      or boop.util.starts(text, "operation exit:")
      or boop.util.starts(text, "interrupt terminal:") then
    return true
  end

  local category, fingerprint = routineLiveFingerprint(text)
  if not category then
    return true
  end

  boop.state.trace.liveRoutine = boop.state.trace.liveRoutine or {}
  if boop.state.trace.liveRoutine[category] == fingerprint then
    return false
  end
  boop.state.trace.liveRoutine[category] = fingerprint
  return true
end

function boop.trace.log(msg)
  if not msg or msg == "" then return end
  if not boop.config or not boop.config.traceEnabled then return end

  boop.state = boop.state or {}
  boop.state.trace.buffer = boop.state.trace.buffer or {}

  local ts = os.date("%H:%M:%S")
  local line = string.format("%s | %s", ts, tostring(msg))
  local buf = boop.state.trace.buffer
  buf[#buf + 1] = line

  local limit = 100
  while #buf > limit do
    table.remove(buf, 1)
  end

  if boop.state.trace.live and shouldRenderLiveTrace(msg) then
    boop.util.info("trace live: " .. line)
  end
end

function boop.trace.show(count)
  boop.state = boop.state or {}
  boop.state.trace.buffer = boop.state.trace.buffer or {}
  local buf = boop.state.trace.buffer
  local total = #buf
  if total == 0 then
    boop.util.info("trace: (empty)")
    return
  end

  local n = tonumber(count) or 20
  if n < 1 then n = 1 end
  if n > total then n = total end
  boop.util.info(string.format("trace: showing %d/%d", n, total))
  for i = total - n + 1, total do
    boop.util.info("  " .. tostring(buf[i]))
  end
end

function boop.trace.clear()
  boop.state = boop.state or {}
  boop.state.trace.buffer = {}
  boop.state.trace.liveRoutine = {}
  boop.util.ok("trace: cleared")
end
