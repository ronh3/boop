boop.attacks.register("paladin", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["faithrend"] = {
        ["cmd"] = "faithrend &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "faithrend",
        ["rage"] = 17
      },
      ["harrow"] = {
        ["cmd"] = "harrow &tar",
        ["desc"] = "Small Damage",
        ["name"] = "harrow",
        ["rage"] = 14
      },
      ["punishment"] = {
        ["cmd"] = "perform rite of punishment at &tar",
        ["desc"] = "Conditional",
        ["name"] = "punishment",
        ["needs"] = { "weakness", "clumsiness" },
        ["rage"] = 25
      },
      ["recovery"] = {
        ["cmd"] = "perform rite of recovery at &tar",
        ["desc"] = "Buff",
        ["name"] = "recovery",
        ["rage"] = 31
      },
      ["regeneration"] = {
        ["cmd"] = "perform rite of regeneration",
        ["desc"] = "Buff",
        ["name"] = "regeneration",
        ["rage"] = 18
      },
      ["shock"] = {
        ["cmd"] = "perform rite of shock at &tar",
        ["desc"] = "Big Damage",
        ["name"] = "shock",
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
