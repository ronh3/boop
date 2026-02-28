-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "Bard/Battlerage/Charm.lua",
  ability = "Charm",
  actor = { kind = "match", index = 2 },
  target = { kind = "match", index = 3 },
}, matches, line or "")
