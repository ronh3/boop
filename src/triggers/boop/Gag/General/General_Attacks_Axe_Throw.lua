-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "General/Attacks/Axe_Throw.lua",
  ability = "Axe Throw",
  actor = { kind = "match", index = 2 },
  target = { kind = "match", index = 3 },
}, matches, line or "")
