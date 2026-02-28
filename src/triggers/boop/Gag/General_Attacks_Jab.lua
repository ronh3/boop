-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "General/Attacks/Jab.lua",
  ability = "Jab",
  actor = { kind = "match", index = 2 },
  target = { kind = "match", index = 3 },
}, matches, line or "")
