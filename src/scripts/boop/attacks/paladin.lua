boop.attacks.register("paladin", {  standard = {
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
      ["faithrend"] = {
        ["cmd"] = "faithrend &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "faithrend",
        ["rage"] = 17
      },
      ["harrow"] = {
        ["cmd"] = "harrow &tar",
        ["desc"] = "Small Damage",
        ["name"] = "harrow",
        ["rage"] = 14
      },
      ["punishment"] = {
        ["cmd"] = "perform rite of punishment at &tar",
        ["desc"] = "Conditional",
        ["name"] = "punishment",
        ["needs"] = { "recklessness", "clumsiness" },
        ["rage"] = 25
      },
      ["recovery"] = {
        ["cmd"] = "perform rite of recovery at &tar",
        ["desc"] = "Buff",
        ["name"] = "recovery",
        ["rage"] = 31
      },
      ["regeneration"] = {
        ["cmd"] = "perform rite of regeneration",
        ["desc"] = "Buff",
        ["name"] = "regeneration",
        ["rage"] = 18
      },
      ["shock"] = {
        ["cmd"] = "perform rite of shock at &tar",
        ["desc"] = "Big Damage",
        ["name"] = "shock",
        ["rage"] = 36
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
