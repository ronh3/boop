boop.attacks.register("infernal", {  standard = {
    -- TODO: Simplified Foxhunt standard (per-spec, no extra state); refine later.
    dam = {
      bySpec = {
        ["Dual Cutting"] = { cmd = "hyena maul &tar/dsl &tar", skill = "", group = "" },
        ["Dual Blunt"] = { cmd = "hyena maul &tar/doublewhirl &tar", skill = "", group = "" },
        ["Two Handed"] = { cmd = "hyena maul &tar/slaughter &tar", skill = "", group = "" },
        ["Sword and Shield"] = { cmd = "hyena maul &tar/combination &tar slice smash", skill = "", group = "" },
      },
      default = { cmd = "hyena maul &tar/slaughter &tar", skill = "", group = "" },
    },
    shield = {
      bySpec = {
        ["Dual Cutting"] = { cmd = "hyena maul &tar/rsl &tar", skill = "", group = "" },
        ["Dual Blunt"] = { cmd = "hyena maul &tar/fracture &tar", skill = "", group = "" },
        ["Two Handed"] = { cmd = "hyena maul &tar/carve &tar", skill = "", group = "" },
        ["Sword and Shield"] = { cmd = "hyena maul &tar/combination &tar raze smash", skill = "", group = "" },
      },
      default = { cmd = "hyena maul &tar/carve &tar", skill = "", group = "" },
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
