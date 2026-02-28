-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "Priest/Battlerage/Torment.lua",
  ability = "Torment",
  actor = { kind = "match", index = 2 },
  target = { kind = "match", index = 3 },
}, matches, line or "")
