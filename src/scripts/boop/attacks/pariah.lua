boop.attacks.register("pariah", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "kill &tar", skill = "", group = "" },
    shield = { cmd = "kill &tar", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["ascour"] = {
        ["cmd"] = "accursed scour &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "ascour",
        ["rage"] = 17
      },
      ["boil"] = {
        ["cmd"] = "blood boil &tar",
        ["desc"] = "Small Damage",
        ["name"] = "boil",
        ["rage"] = 14
      },
      ["feast"] = {
        ["cmd"] = "swarm feast &tar",
        ["desc"] = "Big Damage",
        ["name"] = "feast",
        ["rage"] = 36
      },
      ["spider"] = {
        ["cmd"] = "trace spider &tar",
        ["desc"] = "Conditional",
        ["name"] = "spider",
        ["needs"] = { "inhibit", "sensitivity" },
        ["rage"] = 25
      },
      ["symphony"] = {
        ["aff"] = "fear",
        ["cmd"] = "swarm feast &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "symphony",
        ["rage"] = 18
      },
      ["wail"] = {
        ["aff"] = "clumsiness",
        ["cmd"] = "accursed wail &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "wail",
        ["rage"] = 32
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
