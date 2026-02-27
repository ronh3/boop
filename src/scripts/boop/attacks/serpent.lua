boop.attacks.register("serpent", {  standard = {
    -- TODO: Simplified Foxhunt standard (single default, no extra state); refine later.
    dam = { cmd = "garrote &tar", skill = "Garrote", group = "Subterfuge" },
    shield = { cmd = "flay &tar shield", skill = "Flay", group = "Subterfuge" },
  },
  rage = {
    ["abilities"] = {
      ["excoriate"] = {
        ["cmd"] = "excoriate &tar",
        ["desc"] = "Shieldbreak",
        ["name"] = "excoriate",
        ["rage"] = 17
      },
      ["flagellate"] = {
        ["aff"] = "aeon",
        ["cmd"] = "flagellate &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "flagellate",
        ["rage"] = 25
      },
      ["obliviate"] = {
        ["aff"] = "amnesia",
        ["cmd"] = "obliviate &tar",
        ["desc"] = "Gives Affliction",
        ["name"] = "obliviate",
        ["rage"] = 28
      },
      ["snare"] = {
        ["cmd"] = "snare &tar",
        ["desc"] = "Conditional",
        ["name"] = "snare",
        ["needs"] = { "inhibit", "weakness" },
        ["rage"] = 25
      },
      ["thrash"] = {
        ["cmd"] = "thrash &tar",
        ["desc"] = "Small Damage",
        ["name"] = "thrash",
        ["rage"] = 14
      },
      ["throatrip"] = {
        ["cmd"] = "throatrip &tar",
        ["desc"] = "Big Damage",
        ["name"] = "throatrip",
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
