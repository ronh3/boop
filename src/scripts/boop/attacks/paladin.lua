boop.attacks.register("paladin", {  standard = {
    dam = {
      bySpec = {
        ["Dual Cutting"] = { 
          {cmd = "dsl &tar", skill = "Duality", group = "Weaponmastery" },
          {cmd = "jab &tar", skill = "Swordplay", group = "Weaponmastery" },
        },
        ["Dual Blunt"] = { 
          {cmd = "doublewhirl &tar", skill = "Doublewhirl", group = "Weaponmastery" },
          {cmd = "whirl &tar", skill = "Whirl", group = "Weaponmastery" },
          {cmd = "jab &tar", skill = "Swordplay", group = "Weaponmastery" },
        },
        ["Two Handed"] = { 
          {cmd = "slaughter &tar", skill = "Slaughter", group = "Weaponmastery" },
          {cmd = "jab &tar", skill = "Swordplay", group = "Weaponmastery" },
        },
        ["Sword and Shield"] = { 
          {cmd = "combination &tar slice smash", skill = "Slice", group = "Weaponmastery" },
          {cmd = "combination &tar rend smash", skill = "Combination", group = "Weaponmastery" },
          {cmd = "smash &tar", skill = "Smash", group = "Weaponmastery" },
          {cmd = "rend &tar", skill = "Rend", group = "Weaponmastery" },
          {cmd = "jab &tar", skill = "Swordplay", group = "Weaponmastery" },
        },
      },
      default = { cmd = "kill &tar", skill = "", group = "" },
    },
    shield = {
      bySpec = {
        ["Dual Cutting"] = { 
          {cmd = "rsl &tar", skill = "Razeslash", group = "Weaponmastery" },
          {cmd = "raze &tar", skill = "Raze", group = "Weaponmastery" },
        },
        ["Dual Blunt"] = { 
          {cmd = "fracture &tar", skill = "Fracture", group = "Weaponmastery" },
        },
        ["Two Handed"] = { 
          {cmd = "carve &tar", skill = "Carve", group = "Weaponmastery" },
          {cmd = "splinter &tar", skill = "Splinter", group = "Weaponmastery" },
        },
        ["Sword and Shield"] = { 
          {cmd = "combination &tar raze smash", skill = "Combination", group = "Weaponmastery" },
          {cmd = "raze &tar", skill = "Raze", group = "Weaponmastery" },
        },
      }
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
