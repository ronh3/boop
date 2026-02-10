boop.attacks.register("occultist", {
  standard = {
    dam = {
      { cmd = "command hound at &tar", skill = "Lycantha", group = "Domination" },
      { cmd = "warp &tar", skill = "Warp", group = "Occultism" },
    },
    shield = {
      { cmd = "command hound at &tar", skill = "Lycantha", group = "Domination" },
      { cmd = "touch hammer &tar" },
    },
  },
  rage = {
    ["abilities"] = {
      ["chaosgate"] = {
        ["cmd"] = "chaosgate &tar",
        ["desc"] = "Big Damage",
        ["name"] = "chaosgate",
        ["rage"] = 36
      },
      ["fluctuate"] = {
        ["cmd"] = "fluctuate &tar",
        ["desc"] = "Conditional",
        ["name"] = "fluctuate",
        ["needs"] = { "fear", "amnesia" },
        ["rage"] = 25
      },
      ["harry"] = {
        ["cmd"] = "harry &tar",
        ["desc"] = "Small Damage",
        ["name"] = "harry",
        ["rage"] = 14
      },
      ["ruin"] = {
        ["cmd"] = "ruin &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "ruin",
        ["rage"] = 17
      },
      ["stagnate"] = {
        ["aff"] = "aeon",
        ["cmd"] = "stagnate &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "stagnate",
        ["rage"] = 29
      },
      ["temper"] = {
        ["aff"] = "charm",
        ["cmd"] = "temper &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "temper",
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
