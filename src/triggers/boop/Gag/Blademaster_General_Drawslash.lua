-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "Blademaster/General/Drawslash.lua",
  ability = "Drawslash",
  actor = { kind = "match", index = 2 },
  target = { kind = "match", index = 3 },
}, matches, line or "")
