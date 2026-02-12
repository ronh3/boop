boop.attacks.register("blademaster", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["daze"] = {
        ["aff"] = "stun",
        ["cmd"] = "shin daze &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "daze",
        ["rage"] = 26
      },
      ["headstrike"] = {
        ["cmd"] = "strike &tar head",
        ["desc"] = "Conditional",
        ["name"] = "headstrike",
        ["needs"] = { "recklessness", "fear" },
        ["rage"] = 25
      },
      ["leapstrike"] = {
        ["cmd"] = "leapstrike &tar",
        ["desc"] = "Small Damage",
        ["name"] = "leapstrike",
        ["rage"] = 14
      },
      ["nerveslash"] = {
        ["aff"] = "weakness",
        ["cmd"] = "nerveslash &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "nerveslash",
        ["rage"] = 22
      },
      ["shatter"] = {
        ["cmd"] = "shin shatter &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "shatter",
        ["rage"] = 17
      },
      ["spinslash"] = {
        ["cmd"] = "spinslash &tar",
        ["desc"] = "Big Damage",
        ["name"] = "spinslash",
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
