boop.attacks.register("bard", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "jab &tar", skill = "", group = "" },
    shield = { cmd = "sing cantata at &tar/jab &tar", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["charm"] = {
        ["aff"] = "charm",
        ["cmd"] = "play charm at &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "charm",
        ["rage"] = 32
      },
      ["cyclone"] = {
        ["cmd"] = "cyclone &tar",
        ["desc"] = "Conditional",
        ["name"] = "cyclone",
        ["needs"] = { "clumsiness", "stun" },
        ["rage"] = 25
      },
      ["howlslash"] = {
        ["cmd"] = "howlslash &tar",
        ["desc"] = "Big Damage",
        ["name"] = "howlslash",
        ["rage"] = 36
      },
      ["moulinet"] = {
        ["cmd"] = "moulinet &tar",
        ["desc"] = "Small Damage",
        ["name"] = "moulinet",
        ["rage"] = 14
      },
      ["resonance"] = {
        ["cmd"] = "play resonance &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "resonance",
        ["rage"] = 17
      },
      ["trill"] = {
        ["aff"] = "amnesia",
        ["cmd"] = "play trill at &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "trill",
        ["rage"] = 28
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
