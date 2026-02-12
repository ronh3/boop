boop.attacks.register("priest", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["crack"] = {
        ["cmd"] = "crack &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "crack",
        ["rage"] = 17
      },
      ["desolation"] = {
        ["cmd"] = "perform rite of desolation &tar",
        ["desc"] = "Big Damage",
        ["name"] = "desolation",
        ["rage"] = 36
      },
      ["hammer"] = {
        ["cmd"] = "hammer &tar",
        ["desc"] = "Conditional",
        ["name"] = "hammer",
        ["needs"] = { "clumsiness", "amnesia" },
        ["rage"] = 25
      },
      ["horrify"] = {
        ["aff"] = "fear",
        ["cmd"] = "perform rite of horrify &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "horrify",
        ["rage"] = 29
      },
      ["incense"] = {
        ["aff"] = "recklessness",
        ["cmd"] = "angel incense",
        ["desc"] = "Gives Affliction",
        ["name"] = "incense",
        ["rage"] = 19
      },
      ["torment"] = {
        ["cmd"] = "angel torment",
        ["desc"] = "Small Damage",
        ["name"] = "torment",
        ["rage"] = 14
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
