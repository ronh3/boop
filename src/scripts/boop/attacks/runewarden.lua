boop.attacks.register("runewarden", {  standard = {
    -- TODO: Simplified Foxhunt standard (per-spec, no extra state); refine later.
    dam = {
      bySpec = {
        ["Dual Cutting"] = { cmd = "dsl &tar", skill = "", group = "" },
        ["Two Handed"] = { cmd = "battlefury focus speed/slaughter &tar", skill = "", group = "" },
        ["Sword and Shield"] = { cmd = "combination &tar slice smash", skill = "", group = "" },
      },
      default = { cmd = "battlefury focus speed/slaughter &tar", skill = "", group = "" },
    },
    shield = {
      bySpec = {
        ["Dual Cutting"] = { cmd = "rsl &tar", skill = "", group = "" },
        ["Two Handed"] = { cmd = "battlefury focus speed/carve &tar", skill = "", group = "" },
        ["Sword and Shield"] = { cmd = "combination &tar raze smash", skill = "", group = "" },
      },
      default = { cmd = "battlefury focus speed/carve &tar", skill = "", group = "" },
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
