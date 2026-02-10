boop.attacks.register("infernal", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
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
    },
    ["nrshieldbreak"] = {
      ["cmd"] = "",
      ["desc"] = "Raze",
      ["rage"] = 0
    }
  }
})
