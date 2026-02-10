boop.attacks.register("jester", {
  standard = {
    dam = { cmd = "", skill = "" },
    shield = { cmd = "", skill = "" },
  },
  rage = {
    ["abilities"] = {
      ["befuddle"] = {
        ["cmd"] = "befuddle &tar",
        ["desc"] = "Conditional",
        ["name"] = "befuddle",
        ["needs"] = { "aeon", "amnesia" },
        ["rage"] = 25
      },
      ["dustthrow"] = {
        ["aff"] = "inhibit",
        ["cmd"] = "dustthrow &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "dustthrow",
        ["rage"] = 18
      },
      ["ensconce"] = {
        ["cmd"] = "ensconce firecracker on &tar",
        ["desc"] = "Big Damage",
        ["name"] = "ensconce",
        ["rage"] = 36
      },
      ["jacks"] = {
        ["cmd"] = "throw jacks at &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "jacks",
        ["rage"] = 17
      },
      ["noogie"] = {
        ["cmd"] = "noogie &tar",
        ["desc"] = "Small Damage",
        ["name"] = "noogie",
        ["rage"] = 14
      },
      ["rap"] = {
        ["aff"] = "stun",
        ["cmd"] = "rap &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "rap",
        ["rage"] = 26
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    },
    ["nrshieldbreak"] = {
      ["cmd"] = "",
      ["desc"] = "Raze",
      ["rage"] = 0
    }
  }
})
