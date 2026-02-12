boop.attacks.register("unnamable", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "kill &tar", skill = "", group = "" },
    shield = { cmd = "kill &tar", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["destroy"] = {
        ["cmd"] = "unnamable destroy &tar",
        ["desc"] = "Big Damage",
        ["name"] = "destroy",
        ["rage"] = 36
      },
      ["dread"] = {
        ["aff"] = "fear",
        ["cmd"] = "croon dread &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "dread",
        ["rage"] = 24
      },
      ["entropy"] = {
        ["aff"] = "aeon",
        ["cmd"] = "croon entropy &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "entropy",
        ["rage"] = 18
      },
      ["onslaught"] = {
        ["cmd"] = "unnamable onslaught &tar",
        ["desc"] = "Conditional",
        ["name"] = "onslaught",
        ["needs"] = { "stun", "sensitivity" },
        ["rage"] = 25
      },
      ["shriek"] = {
        ["cmd"] = "unnamable shriek &tar",
        ["desc"] = "Small Damage",
        ["name"] = "shriek",
        ["rage"] = 14
      },
      ["sunder"] = {
        ["cmd"] = "unnamable sunder &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "sunder",
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
