boop.attacks.register("infernal", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "hyena maul &tar/decay &tar", skill = "", group = "" },
    shield = { cmd = "hyena maul &tar/carve &tar", skill = "", group = "" },
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
