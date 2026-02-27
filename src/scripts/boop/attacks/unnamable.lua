boop.attacks.register("unnamable", {  standard = {
    -- TODO: Simplified Foxhunt standard (per-spec, no extra state); refine later.
    dam = {
      bySpec = {
        ["Dual Cutting"] = { cmd = "dsl &tar", skill = "Duality", group = "Weaponmastery" },
        ["Dual Blunt"] = { cmd = "doublewhirl &tar", skill = "Doublewhirl", group = "Weaponmastery" },
        ["Two Handed"] = { cmd = "slaughter &tar", skill = "Slaughter", group = "Weaponmastery" },
        ["Sword and Shield"] = { cmd = "combination &tar slice smash", skill = "Combination", group = "Weaponmastery" },
      },
      default = { cmd = "kill &tar", skill = "", group = "" },
    },
    shield = {
      bySpec = {
        ["Dual Cutting"] = { cmd = "rsl &tar", skill = "Razeslash", group = "Weaponmastery" },
        ["Dual Blunt"] = { cmd = "fracture &tar", skill = "Fracture", group = "Weaponmastery" },
        ["Two Handed"] = { cmd = "carve &tar", skill = "Carve", group = "Weaponmastery" },
        ["Sword and Shield"] = { cmd = "combination &tar raze smash", skill = "Combination", group = "Weaponmastery" },
      },
    },
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
        ["needs"] = { "charm", "sensitivity" },
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
