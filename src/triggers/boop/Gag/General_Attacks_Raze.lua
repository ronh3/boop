-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "General/Attacks/Raze.lua",
  ability = "Raze",
  actor = { kind = "match", index = 2 },
  target = { kind = "match", index = 3 },
}, matches, line or "")
