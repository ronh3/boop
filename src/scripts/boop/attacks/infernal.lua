boop.attacks.register("infernal", {  standard = {
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
      ["deathlink"] = {
        ["cmd"] = "deathlink ",
        ["desc"] = "Buff",
        ["name"] = "deathlink",
        ["rage"] = 30
      },
      ["hellstrike"] = {
        ["cmd"] = "hellstrike &tar",
        ["desc"] = "Conditional",
        ["name"] = "hellstrike",
        ["needs"] = { "recklessness", "fear" },
        ["rage"] = 25
      },
      ["ravage"] = {
        ["cmd"] = "ravage &tar",
        ["desc"] = "Small Damage",
        ["name"] = "ravage",
        ["rage"] = 14
      },
      ["shiver"] = {
        ["cmd"] = "shiver &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "shiver",
        ["rage"] = 17
      },
      ["soulshield"] = {
        ["cmd"] = "soulshield",
        ["desc"] = "Buff",
        ["name"] = "soulshield",
        ["rage"] = 22
      },
      ["spike"] = {
        ["cmd"] = "spike &tar",
        ["desc"] = "Big Damage",
        ["name"] = "spike",
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
