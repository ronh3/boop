boop.attacks.register("earth elemental lord", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "terran pulverise &tar", skill = "", group = "" },
    shield = { cmd = "terran crunch &tar", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["charge"] = {
        ["cmd"] = "terran charge &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "charge",
        ["rage"] = 17
      },
      ["flurry"] = {
        ["cmd"] = "terran flurry &tar",
        ["desc"] = "Big Damage",
        ["name"] = "flurry",
        ["rage"] = 36
      },
      ["magmaburst"] = {
        ["cmd"] = "manifest magmaburst &tar",
        ["desc"] = "Conditional",
        ["name"] = "magmaburst",
        ["needs"] = { "recklessness", "clumsiness" },
        ["rage"] = 25
      },
      ["rampart"] = {
        ["cmd"] = "terran rampart &tar",
        ["desc"] = "Buff",
        ["name"] = "rampart",
        ["rage"] = 22
      },
      ["rockfall"] = {
        ["aff"] = "stun",
        ["cmd"] = "manifest rockfall &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "rockfall",
        ["rage"] = 18
      },
      ["smash"] = {
        ["cmd"] = "terran smash &tar",
        ["desc"] = "Small Damage",
        ["name"] = "smash",
        ["rage"] = 14
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
