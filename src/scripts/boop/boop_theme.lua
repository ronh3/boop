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
    ashtan = {
      accent = "purple",
      border = "midnight_blue",
      text = "lavender_blush",
      muted = "thistle",
    },
    cyrene = {
      accent = "cornflower_blue",
      border = "dark_slate_blue",
      text = "alice_blue",
      muted = "light_steel_blue",
    },
    eleusis = {
      accent = "forest_green",
      border = "saddle_brown",
      text = "beige",
      muted = "tan",
    },
    hashan = {
      accent = "yellow",
      border = "sienna",
      text = "light_yellow",
      muted = "wheat",
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
    apostate = {
      accent = "dark_orchid",
      border = "firebrick",
      text = "lavender_blush",
      muted = "plum",
    },
    bard = {
      accent = "medium_aquamarine",
      border = "royal_blue",
      text = "alice_blue",
      muted = "light_steel_blue",
    },
    blademaster = {
      accent = "steel_blue",
      border = "dark_goldenrod",
      text = "white_smoke",
      muted = "light_grey",
    },
    depthswalker = {
      accent = "dark_slate_blue",
      border = "midnight_blue",
      text = "light_cyan",
      muted = "light_steel_blue",
    },
    druid = {
      accent = "sea_green",
      border = "dark_olive_green",
      text = "honeydew",
      muted = "pale_green",
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
    targossas = {
      accent = "ivory",
      border = "steel_blue",
      text = "white",
      muted = "gainsboro",
    },
    alchemist = {
      accent = "goldenrod",
      border = "dark_slate_grey",
      text = "antique_white",
      muted = "tan",
    },
    jester = {
      accent = "magenta",
      border = "dark_khaki",
      text = "light_yellow",
      muted = "light_grey",
    },
    magi = {
      accent = "orange_red",
      border = "saddle_brown",
      text = "light_cyan",
      muted = "light_sky_blue",
    },
    monk = {
      accent = "burlywood",
      border = "sienna",
      text = "ivory",
      muted = "wheat",
    },
    paladin = {
      accent = "gold",
      border = "slate_blue",
      text = "ivory",
      muted = "light_goldenrod_yellow",
    },
    pariah = {
      accent = "sandy_brown",
      border = "dark_slate_grey",
      text = "ivory",
      muted = "tan",
    },
    priest = {
      accent = "light_goldenrod",
      border = "slate_gray",
      text = "white",
      muted = "light_yellow",
    },
    psion = {
      accent = "deep_sky_blue",
      border = "dark_orchid",
      text = "light_cyan",
      muted = "powder_blue",
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
    serpent = {
      accent = "chartreuse",
      border = "dark_slate_grey",
      text = "honeydew",
      muted = "pale_green",
    },
    shaman = {
      accent = "sienna",
      border = "dark_slate_grey",
      text = "wheat",
      muted = "tan",
    },
    sylvan = {
      accent = "spring_green",
      border = "sea_green",
      text = "honeydew",
      muted = "pale_green",
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

local function builtin_theme_categories()
  return {
    { label = "Cities", names = { "ashtan", "cyrene", "eleusis", "hashan", "mhaldor", "targossas" } },
    { label = "Classes", names = { "alchemist", "apostate", "bard", "blademaster", "depthswalker", "druid", "infernal", "jester", "magi", "monk", "occultist", "paladin", "pariah", "priest", "psion", "runewarden", "sentinel", "serpent", "shaman", "sylvan", "unnamable" } },
    { label = "Boop", names = { "default", "ocean", "forest" } },
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

function boop.theme.tagsFor(name)
  local themes = builtin_themes()
  local key = tostring(name or ""):lower()
  local def = themes[key] or themes.default
  return theme_to_tags(def)
end

function boop.theme.definition(name)
  local themes = builtin_themes()
  return themes[tostring(name or ""):lower()]
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

function boop.theme.categories()
  local result = {}
  local seen = {}
  for _, category in ipairs(builtin_theme_categories()) do
    local names = {}
    for _, name in ipairs(category.names) do
      if builtin_themes()[name] then
        names[#names + 1] = name
        seen[name] = true
      end
    end
    if #names > 0 then
      result[#result + 1] = { label = category.label, names = names }
    end
  end

  local remaining = {}
  for name in pairs(builtin_themes()) do
    if not seen[name] then
      remaining[#remaining + 1] = name
    end
  end
  table.sort(remaining)
  if #remaining > 0 then
    result[#result + 1] = { label = "Other", names = remaining }
  end

  return result
end
