boop.attacks.register("druid", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "maul &tar", skill = "Maul", group = "Metamorphosis" },
    shield = { cmd = "touch hammer &tar", skill = "Hammer", group = "Tattoos" },
  },
  rage = {
    ["abilities"] = {
      ["glare"] = {
        ["aff"] = "clumsiness",
        ["cmd"] = "quarterstaff glare &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "glare",
        ["rage"] = 14
      },
      ["ravage"] = {
        ["cmd"] = "ravage &tar",
        ["desc"] = "Big Damage",
        ["name"] = "ravage",
        ["rage"] = 36
      },
      ["redeem"] = {
        ["aff"] = "weakness",
        ["cmd"] = "reclamation redeem &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "redeem",
        ["rage"] = 22
      },
      ["sear"] = {
        ["cmd"] = "sear &tar",
        ["desc"] = "Conditional",
        ["name"] = "sear",
        ["needs"] = { "recklessness", "stun" },
        ["rage"] = 25
      },
      ["strangle"] = {
        ["cmd"] = "strangle &tar",
        ["desc"] = "Small Damage",
        ["name"] = "strangle",
        ["rage"] = 14
      },
      ["vinecrack"] = {
        ["cmd"] = "vinecrack &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "vinecrack",
        ["rage"] = 17
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
