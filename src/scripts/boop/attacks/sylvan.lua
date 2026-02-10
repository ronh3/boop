boop.attacks.register("sylvan", {
  standard = {
    dam = { cmd = "", skill = "" },
    shield = { cmd = "", skill = "" },
  },
  rage = {
    ["abilities"] = {
      ["leechroot"] = {
        ["cmd"] = "leechroot &tar",
        ["desc"] = "Conditional",
        ["name"] = "leechroot",
        ["needs"] = { "inhibit", "weakness" },
        ["rage"] = 25
      },
      ["rockshot"] = {
        ["aff"] = "amnesia",
        ["cmd"] = "cast rockshot at &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "rockshot",
        ["rage"] = 18
      },
      ["sandstorm"] = {
        ["aff"] = "fear",
        ["cmd"] = "cast sandstorm at &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "sandstorm",
        ["rage"] = 29
      },
      ["stonevine"] = {
        ["cmd"] = "stonevine &tar",
        ["desc"] = "Big Damage",
        ["name"] = "stonevine",
        ["rage"] = 36
      },
      ["thornpierce"] = {
        ["cmd"] = "thornpiece &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "thornpierce",
        ["rage"] = 17
      },
      ["torrent"] = {
        ["cmd"] = "cast torrent at &tar",
        ["desc"] = "Small Damage",
        ["name"] = "torrent",
        ["rage"] = 14
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
