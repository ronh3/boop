boop.attacks.register("red dragon", {  standard = {
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
      ["dragonblaze"] = {
        ["cmd"] = "dragonblaze &tar",
        ["desc"] = "Big Damage",
        ["name"] = "dragonblaze",
        ["rage"] = 36
      },
      ["dragontaunt"] = {
        ["aff"] = "recklessness",
        ["cmd"] = "glaciate &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "dragontaunt",
        ["rage"] = 26
      },
      ["flamebath"] = {
        ["cmd"] = "flamebath &tar",
        ["desc"] = "Conditional",
        ["name"] = "flamebath",
        ["needs"] = { "sensitivity", "clumsiness" },
        ["rage"] = 25
      },
      ["melt"] = {
        ["cmd"] = "melt &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "melt",
        ["rage"] = 17
      },
      ["overwhelm"] = {
        ["cmd"] = "overwhelm &tar",
        ["desc"] = "Small Damage",
        ["name"] = "overwhelm",
        ["rage"] = 14
      },
      ["scorch"] = {
        ["aff"] = "inhibit",
        ["cmd"] = "auge &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "scorch",
        ["rage"] = 18
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
