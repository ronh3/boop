boop.attacks.register("silver dragon", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["dragonspark"] = {
        ["cmd"] = "dragonspark &tar",
        ["desc"] = "Big Damage",
        ["name"] = "dragonspark",
        ["rage"] = 36
      },
      ["galvanize"] = {
        ["aff"] = "recklessness",
        ["cmd"] = "galvanize &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "galvanize",
        ["rage"] = 18
      },
      ["overwhelm"] = {
        ["cmd"] = "overwhelm &tar",
        ["desc"] = "Small Damage",
        ["name"] = "overwhelm",
        ["rage"] = 14
      },
      ["sizzle"] = {
        ["aff"] = "sensitivity",
        ["cmd"] = "sizzle &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "sizzle",
        ["rage"] = 25
      },
      ["splinter"] = {
        ["cmd"] = "splinter &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "splinter",
        ["rage"] = 17
      },
      ["stormflare"] = {
        ["cmd"] = "stormflare &tar",
        ["desc"] = "Conditional",
        ["name"] = "stormflare",
        ["needs"] = { "amnesia", "fear" },
        ["rage"] = 25
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    },
    ["nrshieldbreak"] = {
      ["cmd"] = "tailsmash &tar",
      ["desc"] = "Raze",
      ["rage"] = 0
    }
  }
})
