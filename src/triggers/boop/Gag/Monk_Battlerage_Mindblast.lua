-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "Monk/Battlerage/Mindblast.lua",
  ability = "Mindblast",
  actor = { kind = "match", index = 2 },
  target = { kind = "match", index = 3 },
}, matches, line or "")
