boop.attacks.register("fire elemental lord", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["bonds"] = {
        ["cmd"] = "manifest bonds &tar",
        ["desc"] = "Small Damage",
        ["name"] = "bonds",
        ["rage"] = 30
      },
      ["cataclysm"] = {
        ["cmd"] = "manifest cataclysm &tar",
        ["desc"] = "Conditional",
        ["name"] = "cataclysm",
        ["needs"] = { "stunned", "recklessness" },
        ["rage"] = 25
      },
      ["devastation"] = {
        ["cmd"] = "manifest devastation &tar",
        ["desc"] = "Big Damage",
        ["name"] = "devastation",
        ["rage"] = 36
      },
      ["engulf"] = {
        ["cmd"] = "manifest engulf &tar",
        ["desc"] = "Small Damage",
        ["name"] = "engulf",
        ["rage"] = 14
      },
      ["scourge"] = {
        ["aff"] = "sensitivity",
        ["cmd"] = "manifest scourge &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "scourge",
        ["rage"] = 25
      },
      ["wires"] = {
        ["cmd"] = "manifest wires &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "wires",
        ["rage"] = 17
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    },
    ["nrshieldbreak"] = {
      ["cmd"] = "manifest superheat &tar",
      ["desc"] = "Raze",
      ["rage"] = 0
    }
  }
})
