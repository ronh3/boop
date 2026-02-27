boop.attacks.register("depthswalker", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "shadow reap &tar", skill = "Reap", group = "Shadowmancy" },
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
        ["desc"] = "Mid Damage",
        ["name"] = "erasure",
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
