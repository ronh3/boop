boop.attacks.register("blue dragon", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["ague"] = {
        ["aff"] = "clumsiness",
        ["cmd"] = "auge &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "ague",
        ["rage"] = 28
      },
      ["dragonchill"] = {
        ["cmd"] = "dragonchill &tar",
        ["desc"] = "Small Damage",
        ["name"] = "dragonchill",
        ["rage"] = 14
      },
      ["frostrive"] = {
        ["cmd"] = "frostrive &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "frostrive",
        ["rage"] = 17
      },
      ["frostwave"] = {
        ["cmd"] = "frostwave &tar",
        ["desc"] = "Conditional",
        ["name"] = "frostwave",
        ["needs"] = { "recklessness", "amnesia" },
        ["rage"] = 25
      },
      ["glaciate"] = {
        ["aff"] = "stun",
        ["cmd"] = "glaciate &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "glaciate",
        ["rage"] = 26
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
