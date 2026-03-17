boop.theme = boop.theme or {}

local function theme_to_tags(def)
  local function tag(value, fallback)
    local raw = tostring(value or fallback or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if raw == "" then
      raw = tostring(fallback or "white")
    end
    if raw:sub(1, 1) == "<" then
      return raw
    end
    return "<" .. raw .. ">"
  end

  return {
    accent = tag(def.accent, "cyan"),
    border = tag(def.border, "grey"),
    text = tag(def.text, "white"),
    muted = tag(def.muted, "light_grey"),
    ok = tag(def.ok, "green"),
    warn = tag(def.warn, "yellow"),
    err = tag(def.err, "red"),
    info = tag(def.info, def.accent or "cyan"),
    dim = tag(def.dim, def.muted or "light_grey"),
    reset = "<reset>",
  }
end

local function builtin_themes()
  return {
    default = {
      accent = "cyan",
      border = "grey",
      text = "white",
      muted = "light_grey",
      ok = "green",
      warn = "yellow",
      err = "red",
      info = "cyan",
      dim = "dark_grey",
    },
    occultist = {
      accent = "dark_turquoise",
      border = "dark_orchid",
      text = "alice_blue",
      muted = "cadet_blue",
      ok = "spring_green",
      warn = "khaki",
      err = "tomato",
      info = "dark_turquoise",
      dim = "slate_gray",
    },
    infernal = {
      accent = "firebrick",
      border = "maroon",
      text = "misty_rose",
      muted = "rosy_brown",
      ok = "medium_spring_green",
      warn = "goldenrod",
      err = "red",
      info = "salmon",
      dim = "dark_slate_grey",
    },
    runewarden = {
      accent = "royal_blue",
      border = "peru",
      text = "alice_blue",
      muted = "light_slate_gray",
      ok = "spring_green",
      warn = "gold",
      err = "tomato",
      info = "cornflower_blue",
      dim = "dim_grey",
    },
    sentinel = {
      accent = "olive_drab",
      border = "dark_olive_green",
      text = "honeydew",
      muted = "dark_sea_green",
      ok = "spring_green",
      warn = "khaki",
      err = "tomato",
      info = "medium_sea_green",
      dim = "dim_grey",
    },
    unnamable = {
      accent = "orchid",
      border = "dark_slate_blue",
      text = "lavender",
      muted = "thistle",
      ok = "spring_green",
      warn = "khaki",
      err = "tomato",
      info = "plum",
      dim = "slate_gray",
    },
    mhaldor = {
      accent = "red",
      border = "dark_slate_grey",
      text = "misty_rose",
      muted = "rosy_brown",
      ok = "spring_green",
      warn = "goldenrod",
      err = "red",
      info = "salmon",
      dim = "dim_grey",
    },
    ocean = {
      accent = "deep_sky_blue",
      border = "steel_blue",
      text = "alice_blue",
      muted = "light_steel_blue",
      ok = "spring_green",
      warn = "khaki",
      err = "tomato",
      info = "cornflower_blue",
      dim = "slate_gray",
    },
    forest = {
      accent = "forest_green",
      border = "saddle_brown",
      text = "beige",
      muted = "tan",
      ok = "spring_green",
      warn = "khaki",
      err = "tomato",
      info = "sea_green",
      dim = "dim_grey",
    },
  }
end

local function current_class()
  local class = ""
  if boop and boop.state and boop.state.class then
    class = boop.state.class
  elseif gmcp and gmcp.Char and gmcp.Char.Status and gmcp.Char.Status.class then
    class = gmcp.Char.Status.class
  end
  return tostring(class or ""):lower()
end

function boop.theme.resolve_name()
  local configured = ""
  if boop and boop.config then
    configured = tostring(boop.config.uiTheme or ""):lower()
  end
  if configured ~= "" and configured ~= "auto" then
    return configured
  end

  local class = current_class()
  local themes = builtin_themes()
  if class ~= "" and themes[class] then
    return class
  end
  return "default"
end

function boop.theme.tags()
  local themes = builtin_themes()
  local name = boop.theme.resolve_name()
  local def = themes[name] or themes.default
  return theme_to_tags(def)
end

function boop.theme.names()
  local names = {}
  for name, _ in pairs(builtin_themes()) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

function boop.theme.exists(name)
  if not name or name == "" then
    return false
  end
  return builtin_themes()[tostring(name):lower()] ~= nil
end

