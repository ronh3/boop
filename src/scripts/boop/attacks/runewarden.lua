boop.attacks.register("runewarden", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "slaughter &tar", skill = "", group = "" },
    shield = { cmd = "carve &tar", skill = "", group = "" },
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
