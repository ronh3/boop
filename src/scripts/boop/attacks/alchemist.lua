boop.attacks.register("alchemist", {  standard = {
    dam = { cmd = "educe iron &tar", skill = "Iron", group = "Alchemy" },
    shield = { cmd = "educe copper &tar", skill = "Copper", group = "Alchemy" },
  },
  rage = {
    ["abilities"] = {
      ["cadmium"] = {
        ["aff"] = "weakness",
        ["cmd"] = "educe cadmium",
        ["desc"] = "Gives Affliction",
        ["name"] = "cadmium",
        ["rage"] = 22
      },
      ["caustic"] = {
        ["cmd"] = "throw caustic at ",
        ["desc"] = "Shieldbreak",
        ["name"] = "caustic",
        ["rage"] = 17
      },
      ["hypnotic"] = {
        ["aff"] = "amnesia",
        ["cmd"] = "throw hypotic",
        ["desc"] = "Gives Affliction",
        ["name"] = "hypnotic",
        ["rage"] = 28
      },
      ["magnesium"] = {
        ["cmd"] = "educe magnesium",
        ["desc"] = "Big Damage",
        ["name"] = "magnesium",
        ["rage"] = 36
      },
      ["miasma"] = {
        ["cmd"] = "throw miasma",
        ["desc"] = "Small Damage",
        ["name"] = "miasma",
        ["rage"] = 14
      },
      ["pathogen"] = {
        ["cmd"] = "throw pathogen",
        ["desc"] = "Conditional",
        ["name"] = "pathogen",
        ["needs"] = { "inhibit", "fear" },
        ["rage"] = 25
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
