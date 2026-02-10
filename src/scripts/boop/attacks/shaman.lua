boop.attacks.register("shaman", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["cesaret"] = {
        ["aff"] = "recklessness",
        ["cmd"] = "invoke cesaret &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "cesaret",
        ["rage"] = 18
      },
      ["corruption"] = {
        ["cmd"] = "curse &tar corruption",
        ["desc"] = "Small Damage",
        ["name"] = "corruption",
        ["rage"] = 14
      },
      ["haemorrhage"] = {
        ["cmd"] = "curse &tar haemorrhage",
        ["desc"] = "Big Damage",
        ["name"] = "haemorrhage",
        ["rage"] = 36
      },
      ["korkma"] = {
        ["aff"] = "fear",
        ["cmd"] = "invoke korkma &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "korkma",
        ["rage"] = 29
      },
      ["vulnerability"] = {
        ["cmd"] = "curse &tar vulnerability",
        ["desc"] = "Shieldbreak",
        ["name"] = "vulnerability",
        ["rage"] = 17
      },
      ["vurus"] = {
        ["cmd"] = "invoke vurus &tar",
        ["desc"] = "Conditional",
        ["name"] = "vurus",
        ["needs"] = { "sensitivity", "amnesia" },
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
