boop.attacks.register("monk", {
  standard = {
    dam = { cmd = "", skill = "", group = "" },
    shield = { cmd = "", skill = "", group = "" },
  },
  rage = {
    ["abilities"] = {
      ["mindblast"] = {
        ["cmd"] = "mind blast",
        ["desc"] = "Conditional",
        ["name"] = "mindblast",
        ["needs"] = { "weakness", "sensitivity" },
        ["rage"] = 25
      },
      ["ripplestrike"] = {
        ["aff"] = "inhibit",
        ["cmd"] = "rpst",
        ["desc"] = "Gives Affliction",
        ["name"] = "ripplestrike",
        ["rage"] = 25
      },
      ["scramble"] = {
        ["aff"] = "clumsiness",
        ["cmd"] = "mind scramble",
        ["desc"] = "Gives Affliction",
        ["name"] = "scramble",
        ["rage"] = 22
      },
      ["spinningbackfist"] = {
        ["cmd"] = "sbp",
        ["desc"] = "Small Damage",
        ["name"] = "spinningbackfist",
        ["rage"] = 14
      },
      ["splinterkick"] = {
        ["cmd"] = "spk ",
        ["desc"] = "Shieldbreak",
        ["name"] = "splinterkick",
        ["rage"] = 17
      },
      ["tornadokick"] = {
        ["cmd"] = "tnk",
        ["desc"] = "Big Damage",
        ["name"] = "tornadokick",
        ["rage"] = 36
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
