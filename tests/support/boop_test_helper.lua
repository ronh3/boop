local M = {}

local function root()
  return assert(os.getenv("TESTS_DIRECTORY"), "TESTS_DIRECTORY env var is required")
end

local function resetTableData(tbl)
  if type(tbl) ~= "table" then
    return
  end

  for key, value in pairs(tbl) do
    if type(value) ~= "function" then
      tbl[key] = nil
    end
  end
end

local function norm(value)
  value = tostring(value or "")
  return value:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function findCharstatIndex(name)
  local stats = gmcp.Char.Vitals.charstats or {}
  local prefix = tostring(name) .. ":"
  for i, stat in ipairs(stats) do
    if tostring(stat):find(prefix, 1, true) == 1 then
      return i
    end
  end
  return nil
end

function M.load()
  return M
end

function M.reset()
  assert(boop, "boop package is not loaded")
  local desiredGroups = boop.skills and boop.skills.desiredGroups or nil

  gmcp = {
    Char = {
      Name = { name = "TestCharacter" },
      Status = { class = "", name = "TestCharacter" },
      Vitals = {
        hp = 5000,
        maxhp = 5000,
        bal = "1",
        eq = "1",
        charstats = {},
      },
      Skills = {},
      Items = {},
    },
    Room = {
      Info = {
        area = "UNKNOWN",
        num = 1,
        exits = {},
      },
    },
    IRE = {
      Target = {
        Set = "",
        Info = {
          id = "",
          hpperc = "100%",
        },
      },
      Display = {
        ButtonActions = {},
      },
    },
  }

  boop.config = {}
  for key, value in pairs(boop.defaults or {}) do
    boop.config[key] = value
  end

  boop.lists = {
    whitelist = {},
    blacklist = {},
    globalBlacklist = {},
    whitelistTags = {},
    separator = "/",
  }

  resetTableData(boop.state)
  boop.state.init()

  resetTableData(boop.afflictions)
  boop.afflictions.init()
  resetTableData(boop.skills)
  boop.skills.desiredGroups = desiredGroups
  boop.rage.init()
  boop.skills.init()

  boop.handlers = {}

  return boop
end

function M.setArea(area)
  gmcp.Room.Info.area = area
end

function M.setClass(className)
  gmcp.Char.Status.class = className
  boop.state.class = className
end

function M.setSpec(spec)
  local idx = findCharstatIndex("Spec")
  local value = "Spec: " .. tostring(spec)
  if idx then
    gmcp.Char.Vitals.charstats[idx] = value
  else
    table.insert(gmcp.Char.Vitals.charstats, value)
  end
  boop.state.spec = spec
end

function M.setRage(rage)
  local idx = findCharstatIndex("Rage")
  local value = "Rage: " .. tostring(rage)
  if idx then
    gmcp.Char.Vitals.charstats[idx] = value
  else
    table.insert(gmcp.Char.Vitals.charstats, value)
  end
end

function M.setTarget(id, name, hpperc)
  local targetId = tostring(id or "")
  boop.state.currentTargetId = targetId
  boop.state.targetName = tostring(name or "")
  gmcp.IRE.Target.Set = targetId
  gmcp.IRE.Target.Info.id = targetId
  if hpperc ~= nil then
    gmcp.IRE.Target.Info.hpperc = tostring(hpperc)
  end
end

function M.setTargetHp(hpperc)
  gmcp.IRE.Target.Info.hpperc = tostring(hpperc)
end

function M.setDenizens(denizens)
  boop.state.denizens = {}
  for _, denizen in ipairs(denizens or {}) do
    boop.state.denizens[#boop.state.denizens + 1] = {
      id = tostring(denizen.id),
      name = denizen.name,
      attrib = denizen.attrib or "m",
    }
  end
end

function M.setWhitelist(area, names)
  boop.lists.whitelist[area] = {}
  for _, name in ipairs(names or {}) do
    table.insert(boop.lists.whitelist[area], name)
  end
end

function M.setBlacklist(area, names)
  boop.lists.blacklist[area] = {}
  for _, name in ipairs(names or {}) do
    table.insert(boop.lists.blacklist[area], name)
  end
end

function M.learnSkill(name, group)
  local key = norm(name)
  boop.skills.known[key] = true
  if group and group ~= "" then
    boop.skills.skillToGroup[key] = norm(group)
  end
  boop.skills.skillOriginal[key] = name
end

function M.setSkillKnown(name, known, group)
  local key = norm(name)
  boop.skills.known[key] = known and true or false
  if group and group ~= "" then
    boop.skills.skillToGroup[key] = norm(group)
  end
  boop.skills.skillOriginal[key] = name
end

function M.learnSkills(skills)
  for _, skill in ipairs(skills or {}) do
    if type(skill) == "table" then
      M.learnSkill(skill.name, skill.group)
    else
      M.learnSkill(skill)
    end
  end
end

function M.addTargetAfflictions(affs)
  for _, aff in ipairs(affs or {}) do
    boop.afflictions.addTarget(aff)
  end
end

function M.supportPath(path)
  return root() .. "/" .. path
end

return M
