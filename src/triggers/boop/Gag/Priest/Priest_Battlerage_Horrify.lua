-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "Priest/Battlerage/Horrify.lua",
  ability = "Horrify",
  actor = { kind = "match", index = 3 },
  target = { kind = "match", index = 2 },
}, matches, line or "")
