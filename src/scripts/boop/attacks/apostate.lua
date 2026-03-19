boop.attacks.register("apostate", {  standard = {
    dam = { 
      {cmd = "deadeyes &tar bleed bleed", skill = "Deadeyes", group = "Evileye" },
      {cmd = "decay &tar", skill = "Decay", group = "Necromancy" },
    },
    shield = { 
      {cmd = "deadeyes &tar bleed bleed", skill = "Deadeyes", group = "Evileye" },
      {cmd = "taint &tar", skill = "Taint", group = "Necromancy" },
    },
  },
  rage = {
    ["abilities"] = {
      ["bloodlet"] = {
        ["cmd"] = "bloodlet &tar",
        ["desc"] = "Conditional",
        ["name"] = "bloodlet",
        ["needs"] = { "sensitivity", "stun" },
        ["rage"] = 25
      },
      ["burrow"] = {
        ["cmd"] = "daegger burrow &tar",
        ["desc"] = "Big Damage",
        ["name"] = "burrow",
        ["rage"] = 36
      },
      ["convulsions"] = {
        ["cmd"] = "stare &tar convulsions",
        ["desc"] = "Small Damage",
        ["name"] = "convulsions",
        ["rage"] = 14
      },
      ["daeggerpierce"] = {
        ["cmd"] = "daegger pierce &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "daeggerpierce",
        ["rage"] = 17
      },
      ["horrify"] = {
        ["aff"] = "fear",
        ["cmd"] = "stare &tar horrify",
        ["desc"] = "Gives Affliction",
        ["name"] = "horrify",
        ["rage"] = 29
      },
      ["possess"] = {
        ["aff"] = "charm",
        ["cmd"] = "possess &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "possess",
        ["rage"] = 32
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
