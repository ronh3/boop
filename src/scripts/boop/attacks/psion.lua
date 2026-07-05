boop.attacks.register("psion", {  standard = {
    dam = {
      { cmd = "weave charge &tar", skill = "Charge", group = "Weaving" },
      { cmd = "weave flurry &tar", skill = "Flurry", group = "Weaving" },
    },
    shield = { cmd = "weave cleave &tar", skill = "Cleave", group = "Weaving" },
  },
  rage = {
    ["abilities"] = {
      ["barbedblade"] = {
        ["cmd"] = "weave barbedblade &tar",
        ["desc"] = "Small Damage",
        ["name"] = "barbedblade",
        ["rage"] = 14
      },
      ["devastate"] = {
        ["cmd"] = "psi devastate &tar",
        ["desc"] = "Big Damage",
        ["name"] = "devastate",
        ["rage"] = 36
      },
      ["pulverise"] = {
        ["cmd"] = "weave pulverise &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "pulverise",
        ["rage"] = 17
      },
      ["regrowth"] = {
        ["aff"] = "inhibit",
        ["cmd"] = "enact regrowth &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "regrowth",
        ["rage"] = 24
      },
      ["terror"] = {
        ["aff"] = "fear",
        ["cmd"] = "psi terror &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "terror",
        ["rage"] = 32
      },
      ["whirlwind"] = {
        ["cmd"] = "weave whirlwind &tar",
        ["desc"] = "Conditional",
        ["name"] = "whirlwind",
        ["needs"] = { "inhibit", "stun" },
        ["rage"] = 25
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    },
    ["hybridHoldForSelfPrimer"] = true
  }
})
