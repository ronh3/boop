boop.attacks.register("black dragon", {  standard = {
    dam = { cmd = "incantation &tar", skill = "incantation ", group = "Dragoncraft" },
    shield = { cmd = "tailsmash &tar", skill = "Tailsmash", group = "Dragoncraft" },
  },
  rage = {
    ["abilities"] = {
      ["corrode"] = {
        ["cmd"] = "corrode &tar",
        ["desc"] = "Conditional",
        ["name"] = "corrode",
        ["needs"] = { "clumsiness", "aeon" },
        ["rage"] = 25
      },
      ["dissolve"] = {
        ["cmd"] = "dissolve &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "dissolve",
        ["rage"] = 17
      },
      ["dragonfear"] = {
        ["aff"] = "fear",
        ["cmd"] = "psidaze &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "dragonfear",
        ["rage"] = 28
      },
      ["dragonspit"] = {
        ["cmd"] = "dragonspit &tar",
        ["desc"] = "Small Damage",
        ["name"] = "dragonspit",
        ["rage"] = 14
      },
      ["dragonsting"] = {
        ["aff"] = "sensitivity",
        ["cmd"] = "deaden &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "dragonsting",
        ["rage"] = 25
      },
      ["override"] = {
        ["cmd"] = "override &tar",
        ["desc"] = "Big Damage",
        ["name"] = "override",
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
