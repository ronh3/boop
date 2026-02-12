boop.attacks.register("air elemental lord", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "manifest buffet &tar", skill = "", group = "" },
    shield = { cmd = "manifest gale &tar", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["bolt"] = {
        ["cmd"] = "manifest bolt &tar",
        ["desc"] = "Small Damage",
        ["name"] = "bolt",
        ["rage"] = 14
      },
      ["compress"] = {
        ["cmd"] = "aero compress &tar",
        ["desc"] = "Conditional",
        ["name"] = "compress",
        ["needs"] = { "stunned", "sensitivity" },
        ["rage"] = 25
      },
      ["drill"] = {
        ["cmd"] = "manifest drill &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "drill",
        ["rage"] = 17
      },
      ["pressurewave"] = {
        ["cmd"] = "manifest pressurewave &tar",
        ["desc"] = "Big Damage",
        ["name"] = "pressurewave",
        ["rage"] = 36
      },
      ["suffocate"] = {
        ["aff"] = "inhibit",
        ["cmd"] = "aero suffocate &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "suffocate",
        ["rage"] = 22
      },
      ["vacuum"] = {
        ["aff"] = "inhibit",
        ["cmd"] = "manifest vacuum &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "vacuum",
        ["rage"] = 18
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
