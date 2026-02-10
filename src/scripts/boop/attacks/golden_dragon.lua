boop.attacks.register("golden dragon", {
  standard = {
    dam = { cmd = "", skill = "" },
    shield = { cmd = "", skill = "" },
  },
  rage = {
    ["abilities"] = {
      ["deaden"] = {
        ["aff"] = "aeon",
        ["cmd"] = "deaden &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "deaden",
        ["rage"] = 24
      },
      ["overwhelm"] = {
        ["cmd"] = "overwhelm &tar",
        ["desc"] = "Small Damage",
        ["name"] = "overwhelm",
        ["rage"] = 14
      },
      ["psiblast"] = {
        ["cmd"] = "psiblast &tar",
        ["desc"] = "Big Damage",
        ["name"] = "psiblast",
        ["rage"] = 36
      },
      ["psidaze"] = {
        ["aff"] = "amnesia",
        ["cmd"] = "psidaze &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "psidaze",
        ["rage"] = 28
      },
      ["psishatter"] = {
        ["cmd"] = "psishatter &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "psishatter",
        ["rage"] = 17
      },
      ["psistorm"] = {
        ["cmd"] = "psistorm &tar",
        ["desc"] = "Conditional",
        ["name"] = "psistorm",
        ["needs"] = { "stun", "weakness" },
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
