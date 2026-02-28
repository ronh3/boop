-- Generated from Foxhunt class attack/battlerage triggers.
boop.gag.onAttackLine({
  source = "Infernal/Battlerage/Hellstrike.lua",
  ability = "Hellstrike",
  actor = { kind = "match", index = 3 },
  target = { kind = "match", index = 4 },
}, matches, line or "")
