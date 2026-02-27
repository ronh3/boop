boop.attacks.register("infernal", {  standard = {
    -- TODO: Simplified Foxhunt standard (per-spec, no extra state); refine later.
    dam = {
      bySpec = {
        ["Dual Cutting"] = { cmd = "dsl &tar", skill = "Duality", group = "Weaponmastery" },
        ["Dual Blunt"] = { cmd = "doublewhirl &tar", skill = "Doublewhirl", group = "Weaponmastery" },
        ["Two Handed"] = { cmd = "slaughter &tar", skill = "Slaughter", group = "Weaponmastery" },
        ["Sword and Shield"] = { cmd = "combination &tar slice smash", skill = "Combination", group = "Weaponmastery" },
      },
      default = { cmd = "kill &tar", skill = "", group = "" },
    },
    shield = {
      bySpec = {
        ["Dual Cutting"] = { cmd = "rsl &tar", skill = "Razeslash", group = "Weaponmastery" },
        ["Dual Blunt"] = { cmd = "fracture &tar", skill = "Fracture", group = "Weaponmastery" },
        ["Two Handed"] = { cmd = "carve &tar", skill = "Carve", group = "Weaponmastery" },
        ["Sword and Shield"] = { cmd = "combination &tar raze smash", skill = "Combination", group = "Weaponmastery" },
      }
    },
  },
  rage = {
    ["abilities"] = {
      ["deathlink"] = {
        ["cmd"] = "deathlink ",
        ["desc"] = "Buff",
        ["name"] = "deathlink",
        ["rage"] = 30
      },
      ["hellstrike"] = {
        ["cmd"] = "hellstrike &tar",
        ["desc"] = "Conditional",
        ["name"] = "hellstrike",
        ["needs"] = { "recklessness", "fear" },
        ["rage"] = 25
      },
      ["ravage"] = {
        ["cmd"] = "ravage &tar",
        ["desc"] = "Small Damage",
        ["name"] = "ravage",
        ["rage"] = 14
      },
      ["shiver"] = {
        ["cmd"] = "shiver &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "shiver",
        ["rage"] = 17
      },
      ["soulshield"] = {
        ["cmd"] = "soulshield",
        ["desc"] = "Buff",
        ["name"] = "soulshield",
        ["rage"] = 22
      },
      ["spike"] = {
        ["cmd"] = "spike &tar",
        ["desc"] = "Big Damage",
        ["name"] = "spike",
        ["rage"] = 36
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
