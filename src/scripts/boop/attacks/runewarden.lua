boop.attacks.register("runewarden", {  standard = {
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
      ["bulwark"] = {
        ["cmd"] = "bulwark",
        ["desc"] = "Buff",
        ["name"] = "bulwark",
        ["rage"] = 28
      },
      ["collide"] = {
        ["cmd"] = "collide &tar",
        ["desc"] = "Small Damage",
        ["name"] = "collide",
        ["rage"] = 14
      },
      ["etch"] = {
        ["cmd"] = "etch rune at &tar",
        ["desc"] = "Conditional",
        ["name"] = "etch",
        ["needs"] = { "aeon", "stun" },
        ["rage"] = 25
      },
      ["fragment"] = {
        ["cmd"] = "fragment &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "fragment",
        ["rage"] = 17
      },
      ["onslaught"] = {
        ["cmd"] = "onslaught &tar",
        ["desc"] = "Big Damage",
        ["name"] = "onslaught",
        ["rage"] = 36
      },
      ["safeguard"] = {
        ["cmd"] = "safeguard ",
        ["desc"] = "Buff",
        ["name"] = "safeguard",
        ["rage"] = 28
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
