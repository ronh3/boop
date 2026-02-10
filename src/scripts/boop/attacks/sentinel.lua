boop.attacks.register("sentinel", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["bore"] = {
        ["cmd"] = "bore &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "bore",
        ["rage"] = 17
      },
      ["pester"] = {
        ["cmd"] = "pester &tar",
        ["desc"] = "Small Damage",
        ["name"] = "pester",
        ["rage"] = 14
      },
      ["skewer"] = {
        ["cmd"] = "skewer &tar",
        ["desc"] = "Big Damage",
        ["name"] = "skewer",
        ["rage"] = 36
      },
      ["swarm"] = {
        ["cmd"] = "swarm &tar",
        ["desc"] = "Conditional",
        ["name"] = "swarm",
        ["needs"] = { "aeon", "clumsiness" },
        ["rage"] = 25
      },
      ["tame"] = {
        ["aff"] = "recklessness",
        ["cmd"] = "goad &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "tame",
        ["rage"] = 32
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
