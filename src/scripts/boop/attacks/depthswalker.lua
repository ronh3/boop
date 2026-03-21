boop.attacks.register("depthswalker", {  standard = {
    dam = {
      {cmd = "chrono deteriorate &tar", skill = "Deteriorate", group = "Aeonics", needs = { "recklessness", "charm", "fear", "aeon", "amnesia" } },
      {cmd = "chrono degenerate &tar", skill = "Degenerate", group = "Aeonics", needs = { "inhibit", "weakness", "sensitivity", "clumsiness" } },
      {cmd = "shadow reap &tar", skill = "Reap", group = "Shadowmancy" },
      {cmd = "shadow cull &tar", skill = "Cull", group = "Shadowmancy" },
    },
    shield = { cmd = "shadow strike &tar", skill = "Strike", group = "Shadowmancy" },
  },
  rage = {
    ["abilities"] = {
      ["boinad"] = {
        ["aff"] = "charm",
        ["cmd"] = "intone boinad &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "boinad",
        ["rage"] = 32
      },
      ["curse"] = {
        ["aff"] = "aeon",
        ["cmd"] = "chrono curse &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "curse",
        ["rage"] = 24
      },
      ["drain"] = {
        ["cmd"] = "shadow drain &tar",
        ["desc"] = "Small Damage",
        ["name"] = "drain",
        ["rage"] = 14
      },
      ["erasure"] = {
        ["cmd"] = "chrono erasure &tar",
        ["desc"] = "Conditional",
        ["name"] = "erasure",
        ["needs"] = { "weakness", "amnesia" },
        ["rage"] = 25
      },
      ["lash"] = {
        ["cmd"] = "shadow lash &tar",
        ["desc"] = "Big Damage",
        ["name"] = "lash",
        ["rage"] = 36
      },
      ["nakail"] = {
        ["cmd"] = "intone nakail &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "nakail",
        ["rage"] = 17
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
