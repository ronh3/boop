boop.attacks.register("green dragon", {  standard = {
    dam = { 
      {cmd = "incantation &tar", skill = "Incantation", group = "Dragoncraft" },
      {cmd = "gut &tar", skill = "Gut", group = "Dragoncraft" },
      {cmd = "dragonroar &tar", skill = "Roaring", group = "Dragoncraft" },
      {cmd = "rend &tar", skill = "Rend", group = "Dragoncraft" },
    },
    shield = { cmd = "tailsmash &tar", skill = "Tailsmash", group = "Dragoncraft" },
  },
  rage = {
    ["abilities"] = {
      ["deteriorate"] = {
        ["cmd"] = "deteriorate &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "deteriorate",
        ["rage"] = 17
      },
      ["dragonsap"] = {
        ["aff"] = "weakness",
        ["cmd"] = "dragonsap &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "dragonsap",
        ["rage"] = 22
      },
      ["dragonspit"] = {
        ["cmd"] = "dragonspit &tar",
        ["desc"] = "Small Damage",
        ["name"] = "dragonspit",
        ["rage"] = 14
      },
      ["override"] = {
        ["cmd"] = "override &tar",
        ["desc"] = "Big Damage",
        ["name"] = "override",
        ["rage"] = 36
      },
      ["scour"] = {
        ["aff"] = "inhibit",
        ["cmd"] = "scour &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "scour",
        ["rage"] = 18
      },
      ["slaver"] = {
        ["cmd"] = "slaver &tar",
        ["desc"] = "Conditional",
        ["name"] = "slaver",
        ["needs"] = { "sensitivity", "clumsiness" },
        ["rage"] = 25
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
