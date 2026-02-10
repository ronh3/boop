boop.attacks.register("water elemental lord", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["aquahammer"] = {
        ["cmd"] = "manifest aquahammer &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "aquahammer",
        ["rage"] = 17
      },
      ["dehydrate"] = {
        ["aff"] = "clumsiness",
        ["cmd"] = "manifest dehydrate &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "dehydrate",
        ["rage"] = 14
      },
      ["icicles"] = {
        ["cmd"] = "manifest icicles &tar",
        ["desc"] = "Small Damage",
        ["name"] = "icicles",
        ["rage"] = 14
      },
      ["needlerain"] = {
        ["cmd"] = "manifest needlerain &tar",
        ["desc"] = "Big Damage",
        ["name"] = "needlerain",
        ["rage"] = 36
      },
      ["swell"] = {
        ["cmd"] = "manifest swell &tar",
        ["desc"] = "Buff",
        ["name"] = "swell",
        ["rage"] = 30
      },
      ["waterfall"] = {
        ["cmd"] = "manifest waterfall &tar",
        ["desc"] = "Conditional",
        ["name"] = "waterfall",
        ["needs"] = { "weakness", "aeon" },
        ["rage"] = 25
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
