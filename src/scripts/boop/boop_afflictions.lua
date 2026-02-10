boop.afflictions = boop.afflictions or {}

function boop.afflictions.init()
  boop.afflictions.target = boop.afflictions.target or {}
end

local function affKey(aff)
  return boop.util.safeLower(aff or "")
end

function boop.afflictions.clearTarget()
  boop.afflictions.target = {}
end

function boop.afflictions.setTarget(list)
  local target = {}
  for _, aff in ipairs(list or {}) do
    local key = affKey(aff)
    if key ~= "" then
      target[key] = true
    end
  end
  boop.afflictions.target = target
end

function boop.afflictions.addTarget(aff)
  local key = affKey(aff)
  if key == "" then return end
  boop.afflictions.target = boop.afflictions.target or {}
  boop.afflictions.target[key] = true
end

function boop.afflictions.removeTarget(aff)
  local key = affKey(aff)
  if key == "" then return end
  boop.afflictions.target = boop.afflictions.target or {}
  boop.afflictions.target[key] = nil
end

function boop.afflictions.hasTarget(aff)
  local key = affKey(aff)
  if key == "" then return false end
  local target = boop.afflictions.target or {}
  return target[key] == true
end

function boop.afflictions.meetsNeeds(needs)
  if not needs or #needs == 0 then return true end
  for _, aff in ipairs(needs) do
    if not boop.afflictions.hasTarget(aff) then
      return false
    end
  end
  return true
end

function boop.afflictions.listTarget()
  local target = boop.afflictions.target or {}
  local names = {}
  for aff, _ in pairs(target) do
    names[#names + 1] = aff
  end
  table.sort(names)
  return names
end

function boop.afflictions.displayTarget()
  local names = boop.afflictions.listTarget()
  if #names == 0 then
    boop.util.echo("target afflictions: none")
    return
  end
  boop.util.echo("target afflictions: " .. table.concat(names, ", "))
end
