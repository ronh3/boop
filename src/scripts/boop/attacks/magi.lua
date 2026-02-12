boop.attacks.register("magi", {
  standard = {
    dam = { cmd = "staffcast horripilation at &tar", skill = "Horripilation", group = "Artificing" },
    shield = { cmd = "cast erode at &tar", skill = "Erode", group = "Elementalism" },
  },
  rage = {
    ["abilities"] = {
      ["dilation"] = {
        ["aff"] = "aeon",
        ["cmd"] = "cast dilation at &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "dilation",
        ["rage"] = 24
      },
      ["disintegrate"] = {
        ["cmd"] = "cast disintegrate at &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "disintegrate",
        ["rage"] = 17
      },
      ["firefall"] = {
        ["cmd"] = "cast firefall at &tar",
        ["desc"] = "Conditional",
        ["name"] = "firefall",
        ["needs"] = { "clumsiness", "recklessness" },
        ["rage"] = 25
      },
      ["squeeze"] = {
        ["cmd"] = "cast squeeze &tar",
        ["desc"] = "Big Damage",
        ["name"] = "squeeze",
        ["rage"] = 36
      },
      ["stormbolt"] = {
        ["aff"] = "sensitivity",
        ["cmd"] = "cast stormbolt at &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "stormbolt",
        ["rage"] = 26
      },
      ["windslash"] = {
        ["cmd"] = "cast windlash at &tar",
        ["desc"] = "Small Damage",
        ["name"] = "windslash",
        ["rage"] = 14
      }
    },
    ["configRage"] = {
      ["affAttack"] = 100,
      ["bigDamage"] = 20,
      ["smallDamage"] = 0
    }
  }
})
