boop.attacks.register("sentinel", {  standard = {
    dam = { cmd = "claw &tar", skill = "Claw", group = "Metamorphosis" },
    shield = { cmd = "claw &tar", skill = "Claw", group = "Metamorphosis" },
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
        ["needs"] = { "inhibit", "aeon" },
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
    }
  }
})
