-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "Paladin/Battlerage/Shock.lua",
  ability = "Shock",
  actor = { kind = "match", index = 3 },
  target = { kind = "match", index = 2 },
}, matches, line or "")
